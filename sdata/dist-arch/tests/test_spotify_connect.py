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
import urllib.error
import urllib.parse
import urllib.request
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
        selected = {'DeviceError', 'uri_from', 'remember', 'remember_art', 'is_room_playback', 'wait_room', 'play_room', 'room_control', 'output'}
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
        self.speaker['attributes']['source'] = 'Spotify Connect'
        self.ns['spotify_get'].return_value = {'device': {'name': 'Living Room'}, 'is_playing': False}
        self.ns['cache']['art'] = {'spotify:track:ROOM': 'speaker-art'}
        output = self.ns['output']()
        self.assertEqual(output['source'], 'Living Room')
        self.assertEqual(output['room']['title'], 'Speaker song')
        self.assertEqual(output['room']['uri'], 'spotify:track:ROOM')
        self.assertEqual(output['room']['art'], 'speaker-art')
        self.assertEqual(output['room']['position'], 20)
        self.assertTrue(output['room']['can_next'])
        self.assertTrue(output['room']['can_previous'])

    def test_stale_connect_uri_without_cloud_session_is_reactivated(self):
        self.speaker['attributes']['source'] = 'Spotify Connect'
        self.ns['spotify_get'].side_effect = [None, {'device': {'name': 'Living Room'}, 'is_playing': True}]
        self.ns['play_room'](resume=True)
        self.ns['activate_connect'].assert_called_once()

    def test_local_sonos_queue_is_not_reported_as_connected(self):
        self.speaker['state'] = 'playing'
        output = self.ns['output']()
        self.assertTrue(output['room']['playing'])
        self.assertFalse(output['room']['connected'])
        self.assertEqual(output['source'], '')
        self.assertIn('reconnect', output['warning'])
        self.assertEqual(output['room']['title'], 'Speaker song')

    def test_cloud_disconnect_is_reported_even_with_connect_uri(self):
        self.speaker['attributes']['source'] = 'Spotify Connect'
        self.ns['spotify_get'].return_value = None
        output = self.ns['output']()
        self.assertFalse(output['room']['connected'])
        self.assertEqual(output['source'], '')

    def test_transport_reconnects_before_advancing_local_queue(self):
        self.ns['params'] = {'control': 'next'}
        events = []
        self.ns['play_room'] = Mock(side_effect=lambda **kw: events.append('reconnect'))
        self.ns['service'] = Mock(side_effect=lambda *a, **kw: events.append(a[0]))
        self.ns['time'] = Mock()
        self.ns['room_control']()
        self.assertEqual(events, ['reconnect', 'media_next_track'])

    def test_pause_still_stops_disconnected_speaker_without_reconnecting(self):
        self.ns['params'] = {'control': 'pause'}
        self.ns['play_room'] = Mock()
        self.ns['time'] = Mock()
        self.ns['room_control']()
        self.ns['play_room'].assert_not_called()
        self.assertEqual(self.calls, [('media_pause', 'room', {})])

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

class DeploymentConfiguration(unittest.TestCase):
    def run_status(self, home, urlopen):
        speaker = {'ip': '192.0.2.1', 'state': 'paused', 'attributes': {}}
        reply = subprocess.CompletedProcess([], 0, json.dumps(speaker), '')
        output = io.StringIO()
        with patch.object(Path, 'home', return_value=home), \
             patch.object(urllib.request, 'urlopen', side_effect=urlopen), \
             patch.object(subprocess, 'run', return_value=reply), \
             contextlib.redirect_stdout(output):
            namespace = {}
            try:
                exec(module.REMOTE.replace('REQUEST', repr({'action': 'status'}), 1), namespace)
            finally:
                namespace['lock'].close()
        return json.loads(output.getvalue())

    def test_current_deployment_gets_ha_credential_from_piper_per_request(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            secrets = home / 'projects/home-assistant/deploy/secrets'
            secrets.mkdir(parents=True)
            (secrets / 'piper-legacy.env').write_text('PIPER_URL=http://host.docker.internal:4319\nPIPER_LEGACY_TOKEN="test-caller"\n')
            requests = []
            def urlopen(request, **kwargs):
                requests.append(request)
                if len(requests) == 1:
                    self.assertEqual(request.full_url, 'http://127.0.0.1:4318/v1/call')
                    self.assertEqual(json.loads(request.data), {'operation': 'secrets.get', 'args': {'name': 'homeassistant.token'}})
                    self.assertEqual(request.get_header('Authorization'), 'Bearer test-caller')
                    return io.BytesIO(b'{"result":{"value":"test-ha-token"}}')
                self.assertEqual(request.get_header('Authorization'), 'Bearer test-ha-token')
                return io.BytesIO(b'{"state":"paused","attributes":{"source":"PC","source_list":["PC"]}}')
            data = self.run_status(home, urlopen)
            self.assertTrue(data['ok'])
            self.assertEqual(data['source'], 'PC')
            self.assertEqual(len(requests), 2)
            self.assertNotIn('test-ha-token', json.dumps(data))

    def test_missing_deployment_returns_configuration_error_as_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            data = self.run_status(Path(tmp), Mock())
        self.assertFalse(data['ok'])
        self.assertIn('credential provider is not configured', data['error'])

    def test_provider_outage_does_not_fall_back_to_a_deployment_ha_token(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            deploy = home / 'projects/home-assistant/deploy'
            (deploy / 'secrets').mkdir(parents=True)
            (deploy / 'secrets/piper-legacy.env').write_text('PIPER_LEGACY_TOKEN=test-caller\n')
            (deploy / '.env').write_text('HA_TOKEN=retired-token\n')
            urlopen = Mock(side_effect=urllib.error.URLError('offline'))
            data = self.run_status(home, urlopen)
        self.assertFalse(data['ok'])
        self.assertIn('credential provider is unavailable', data['error'])
        self.assertEqual(urlopen.call_count, 1)

    def test_spotify_authorization_uses_current_ha_state_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            deploy = Path(tmp)
            storage = deploy / 'state/homeassistant/.storage'
            storage.mkdir(parents=True)
            (storage / 'core.config_entries').write_text(json.dumps({'data': {'entries': [
                {'domain': 'spotify', 'data': {'token': {'access_token': 'test-spotify', 'expires_at': time.time() + 3600}}}
            ]}}))
            ns = {'deploy': deploy, 'Path': Path, 'json': json, 'time': time, 'urllib': urllib}
            tree = ast.parse(module.REMOTE)
            tree.body = [n for n in tree.body if isinstance(n, (ast.FunctionDef, ast.ClassDef)) and n.name in {'DeviceError', 'spotify_get'}]
            exec(compile(tree, '<deployment policy>', 'exec'), ns)
            with patch.object(urllib.request, 'urlopen', return_value=io.BytesIO(b'{"device":{"name":"Living Room"}}')) as request:
                self.assertEqual(ns['spotify_get']('me/player')['device']['name'], 'Living Room')
            self.assertEqual(request.call_args.args[0].get_header('Authorization'), 'Bearer test-spotify')

if __name__ == '__main__': unittest.main()
