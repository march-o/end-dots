"""Exercise the remote playback policy without SSH or credentials."""
import ast
import copy
import importlib.util
import time
import unittest
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import Mock

SCRIPT = Path(__file__).resolve().parents[3] / 'dots/.config/quickshell/ii/scripts/media/spotify-connect.py'
spec = importlib.util.spec_from_file_location('spotify_connect', SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class PlaybackPolicy(unittest.TestCase):
    def setUp(self):
        self.speaker = {'state': 'paused', 'attributes': {'media_content_id': 'x-sonos-spotify:spotify%3atrack%3aROOM', 'transport_actions': ['Next','Previous','SeekTime'], 'media_title': 'Speaker song', 'media_artist': 'Speaker artist', 'media_position': 20, 'media_duration': 100, 'volume_level': .3}}
        self.desktop = {'state': 'paused', 'attributes': {'media_content_id': 'spotify:track:DESKTOP', 'source': 'PC', 'source_list': ['PC']}}
        self.calls = []
        def service(name, target='room', **data):
            self.calls.append((name, target, data))
            if target == 'room': self.speaker['state'] = 'paused' if name == 'media_pause' else 'playing'
        self.ns = {'urllib': urllib, 'time': time, 'datetime': datetime, 'timezone': timezone,
                   'cache': {'room_mode': True}, 'state': lambda: copy.deepcopy(self.desktop),
                   'room': lambda: copy.deepcopy(self.speaker), 'service': service,
                   'room_name': 'Living Room', 'room_entity': 'room', 'entity': 'desktop',
                   'save': Mock(), 'activate_connect': Mock(), 'spotify_get': Mock(return_value={'queue': [{'uri': 'spotify:track:NEXT'}]})}
        selected = {'DeviceError', 'uri_from', 'remember', 'remember_art', 'wait_room', 'play_room', 'room_control', 'output'}
        tree = ast.parse(module.REMOTE)
        tree.body = [n for n in tree.body if isinstance(n, (ast.FunctionDef, ast.ClassDef)) and n.name in selected]
        exec(compile(tree, '<remote playback policy>', 'exec'), self.ns)

    def test_connect_activation_precedes_resume_and_spotify_confirms_it(self):
        self.ns['spotify_get'].return_value = {'device': {'name': 'Living Room'}, 'is_playing': True}
        self.ns['play_room']()
        self.ns['activate_connect'].assert_called_once()
        self.assertEqual(self.calls, [('media_play', 'room', {})])
        self.assertTrue(self.ns['cache']['room_mode'])

    def test_existing_connect_session_resumes_without_new_authorization(self):
        self.speaker['attributes']['source'] = 'Spotify Connect'
        self.ns['spotify_get'].return_value = {'device': {'name': 'Living Room'}, 'is_playing': True}
        self.ns['play_room'](resume=True)
        self.ns['activate_connect'].assert_not_called()
        self.assertEqual(self.calls, [('media_play', 'room', {})])

    def test_missing_authorization_never_silently_starts_a_local_queue(self):
        self.ns['activate_connect'].side_effect = self.ns['DeviceError']('one-time authorization required')
        with self.assertRaisesRegex(self.ns['DeviceError'], 'authorization'): self.ns['play_room']()
        self.assertEqual(self.calls, [])

    def test_speaker_playing_alone_is_not_confirmed_connect_success(self):
        self.ns['spotify_get'].return_value = {'device': {'name': 'PC'}, 'is_playing': False}
        self.ns['time'] = Mock(monotonic=Mock(side_effect=[0, 0, 20]))
        with self.assertRaisesRegex(self.ns['DeviceError'], 'Spotify did not confirm'): self.ns['play_room']()

    def test_widget_state_comes_from_speaker(self):
        self.ns['cache']['art'] = {'spotify:track:ROOM': 'speaker-art'}
        output = self.ns['output']()
        self.assertEqual(output['source'], 'Living Room')
        self.assertEqual(output['room']['title'], 'Speaker song')
        self.assertEqual(output['room']['art'], 'speaker-art')
        self.assertEqual(output['room']['position'], 20)
        self.assertTrue(output['room']['can_next'])
        self.assertTrue(output['room']['can_previous'])

if __name__ == '__main__': unittest.main()
