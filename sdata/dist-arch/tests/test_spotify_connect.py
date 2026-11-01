'''Exercise fast widget transport and canonical state without credentials/network.'''
import ast
import copy
import importlib.util
import math
from pathlib import Path
import subprocess
import sys
import time
import unittest
from unittest.mock import Mock, patch

SCRIPT=Path(__file__).resolve().parents[3]/'dots/.config/quickshell/ii/scripts/media/spotify-connect.py'
spec=importlib.util.spec_from_file_location('spotify_connect',SCRIPT)
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class PlaybackPolicy(unittest.TestCase):
    def setUp(self):
        tree=ast.parse(module.REMOTE)
        tree.body=[n for n in tree.body if isinstance(n,(ast.FunctionDef,ast.ClassDef))]
        self.ns={'time':time,'room_entity':'media_player.room','room_name':'Living Room',
                 'music':{'account_entity':'media_player.spotifyplus','preparation_device':'ash-music'},
                 'params':{},'cache':{'room_mode':True}}
        exec(compile(tree,'remote-policy','exec'),self.ns)
        self.speaker={'state':'playing','source':'Spotify Connect','uri':'spotify:track:ROOM',
                      'title':'Truncated title','artist':'Artist','art':'cover','position':0,
                      'duration':100,'volume':.4,'actions':['Next','Previous','SeekTime']}
        self.playback={'spotify':{'playing':True,'device':'Living Room','track_uri':'spotify:track:ROOM',
                                 'title':'Complete title','progress_ms':21000},
                       'sonos':{'source':'Spotify Connect','track_uri':'spotify:track:ROOM'}}
        self.call=Mock(return_value=[])
        self.ns.update(call=self.call,room=Mock(side_effect=lambda:copy.deepcopy(self.speaker)),
                       save=Mock(),devices=Mock(return_value=['Living Room','PC']))

    def test_next_is_one_local_command_without_cloud_or_metadata_precheck(self):
        result=self.ns['control']('next')
        self.assertEqual(self.call.call_count,1)
        self.call.assert_called_once_with('services/media_player/media_next_track',{'entity_id':'media_player.room'})
        self.ns['room'].assert_not_called()
        self.assertTrue(result['ok'])

    def test_pause_is_immediate_even_without_a_spotify_session(self):
        self.ns['control']('pause')
        self.call.assert_called_once_with('services/media_player/media_pause',{'entity_id':'media_player.room'})

    def test_seek_and_previous_do_not_reconnect_or_restart_a_playlist(self):
        self.ns['control']('seek',12.5)
        self.ns['control']('previous')
        self.assertEqual([x.args[0] for x in self.call.call_args_list],
                         ['services/media_player/media_seek','services/media_player/media_previous_track'])
        self.assertEqual(self.call.call_args_list[0].args[1]['seek_position'],12.5)

    def test_uncertain_skip_is_not_retried(self):
        self.call.side_effect=self.ns['DeviceError']('Delivery uncertain')
        with self.assertRaises(self.ns['DeviceError']):self.ns['control']('next')
        self.assertEqual(self.call.call_count,1)

    def test_play_uses_canonical_resume_and_selection_uses_transfer(self):
        self.call.return_value={'service_response':{'verified':True}}
        self.ns['control']('play');self.ns['select']('Living Room')
        self.assertEqual([x.args[0] for x in self.call.call_args_list],
            ['services/home_music/resume?return_response','services/home_music/transfer?return_response'])

    def test_unconfirmed_resume_does_not_claim_success(self):
        self.call.return_value={'service_response':{'verified':False,'reason':'Session unconfirmed'}}
        with self.assertRaisesRegex(self.ns['DeviceError'],'unconfirmed'):self.ns['control']('play')
        self.assertEqual(self.call.call_count,1)

    def test_other_devices_use_modern_authorization_owner(self):
        self.ns['select']('PC')
        self.assertEqual(self.call.call_args.args[1]['entity_id'],'media_player.spotifyplus')
        self.ns['save'].assert_called_once_with({'room_mode':False})

    def test_status_uses_canonical_identity_and_real_speaker_volume(self):
        self.call.return_value={'service_response':{'ready':True,'playback':self.playback}}
        result=self.ns['output']()
        self.assertTrue(result['room']['connected'])
        self.assertEqual(result['room']['title'],'Complete title')
        self.assertEqual(result['room']['uri'],'spotify:track:ROOM')
        self.assertEqual(result['room']['position'],21)
        self.assertEqual(result['room']['volume'],.4)
        self.assertEqual(result['room']['artist'],'Artist')

    def test_unknown_confirmation_does_not_mean_disconnected_or_paused(self):
        self.call.side_effect=self.ns['DeviceError']('Cloud unavailable')
        result=self.ns['output']()
        self.assertIsNone(result['room']['connected'])
        self.assertTrue(result['room']['playing'])
        self.assertEqual(result['room']['uri'],'spotify:track:ROOM')
        self.assertIn('unavailable',result['warning'])

    def test_stale_selected_room_does_not_hide_native_player_when_speaker_is_empty(self):
        self.speaker.update(state='paused',uri='',title='')
        self.call.side_effect=self.ns['DeviceError']('Cloud unavailable')
        result=self.ns['output']()
        self.assertFalse(result['room']['active'])

    def test_partial_cloud_state_is_useful_when_speaker_readiness_is_false(self):
        self.playback['spotify']['device']='PC'
        self.call.return_value={'service_response':{'ready':False,'playback':self.playback}}
        self.assertFalse(self.ns['output']()['room']['active'])

    def test_an_orphaned_local_queue_is_not_claimed_as_connect(self):
        self.playback['sonos']['source']='Spotify'
        self.call.return_value={'service_response':{'ready':True,'playback':self.playback}}
        result=self.ns['output']()
        self.assertFalse(result['room']['connected'])
        self.assertIn('reconnect',result['warning'])

    def test_device_listing_hides_the_silent_preparer_and_caches_cloud_reads(self):
        self.ns['cache']={}
        self.call.return_value={'service_response':{'result':[{'name':'ash-music'},{'name':'PC'}]}}
        # Restore the actual function, whose global save/call dependencies stay mocked.
        self.ns.pop('devices')
        tree=ast.parse(module.REMOTE)
        node=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='devices')
        exec(compile(ast.Module(body=[node],type_ignores=[]),'devices','exec'),self.ns)
        self.assertEqual(self.ns['devices'](),['Living Room','PC'])
        self.ns['cache']={'devices':['Living Room','PC'],'devices_at':time.time()}
        self.call.reset_mock()
        self.assertEqual(self.ns['devices'](),['Living Room','PC'])
        self.call.assert_not_called()

    def test_transport_has_no_widget_specific_spotify_credential_lifecycle(self):
        for retired in ['core.config_entries','application_credentials','spotify-desktop-auth.json','refresh_token','activate_connect']:
            self.assertNotIn(retired,module.REMOTE)

    def test_cli_rejects_nonfinite_seek_without_ssh(self):
        with patch.object(sys,'argv',['spotify-connect.py','room-control','seek','nan']),patch.object(module.subprocess,'run') as run:
            with self.assertRaises(ValueError):module.main()
            run.assert_not_called()

if __name__=='__main__':unittest.main()
