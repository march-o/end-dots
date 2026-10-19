"""Exercise the remote playback policy without SSH or credentials."""
import ast
import copy
import contextlib
import io
import importlib.util
import json
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import Mock, patch

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

class FastVolume(unittest.TestCase):
    def test_cli_uses_volume_only_backend_and_clamps_value(self):
        reply = subprocess.CompletedProcess([], 0, '{"ok":true,"volume":1}', '')
        with patch.object(sys, 'argv', ['spotify-connect.py', 'room-volume', '1.5']), \
             patch.object(module.subprocess, 'run', return_value=reply) as run, \
             contextlib.redirect_stdout(io.StringIO()):
            module.main()
        code = run.call_args.kwargs['input']
        self.assertIn("'value': 1", code)
        self.assertNotIn('HA_TOKEN', code)
        self.assertNotIn('flock', code)
        self.assertEqual(run.call_args.kwargs['timeout'], 10)

    def test_volume_reply_is_read_from_speaker_without_status_poll(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = Path(tmp) / '.cache/quickshell/spotify-connect.json'
            cache.parent.mkdir(parents=True)
            cache.write_text(json.dumps({'speaker_ip': '192.0.2.1'}))
            reply = subprocess.CompletedProcess([], 0, '{"ok":true,"volume":0.39}', '')
            output = io.StringIO()
            with patch.object(Path, 'home', return_value=Path(tmp)), \
                 patch.object(subprocess, 'run', return_value=reply) as run, \
                 contextlib.redirect_stdout(output):
                exec(module.VOLUME_REMOTE.replace('REQUEST', repr({'value': .4}), 1), {})
            self.assertEqual(json.loads(output.getvalue()), {'ok': True, 'volume': .39})
            self.assertEqual(run.call_count, 1)
            self.assertIn('speaker.volume/100', run.call_args.kwargs['input'])

    def test_missing_speaker_address_returns_failure(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(Path, 'home', return_value=Path(tmp)), \
             patch.object(subprocess, 'run') as run, contextlib.redirect_stdout(io.StringIO()) as output:
            exec(module.VOLUME_REMOTE.replace('REQUEST', repr({'value': .4}), 1), {})
        self.assertFalse(json.loads(output.getvalue())['ok'])
        run.assert_not_called()

if __name__ == '__main__': unittest.main()
