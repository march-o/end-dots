"""Connection policy must not confuse an orphaned output with a live stream."""
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

SOURCE = Path(__file__).resolve().parents[1] / 'bin/laptop-monitor'


class LaptopMonitorTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        loader = importlib.machinery.SourceFileLoader('laptop_monitor_test', str(SOURCE))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        self.helper = importlib.util.module_from_spec(spec)
        with patch.dict(os.environ, HOME=self.temporary.name):
            loader.exec_module(self.helper)
        self.config = {'output': 'sunshine', 'desktopIp': '192.168.8.33'}

    def server(self, state):
        return io.BytesIO(f'<root><state>{state}</state></root>'.encode())

    def test_native_resolution_preserves_logical_size_and_monitor_placement(self):
        c = json.loads((SOURCE.parents[0].parent / 'config/laptop-monitor.json').read_text())
        self.assertEqual(c['resolution']['width'] / c['scale'], 1920)
        self.assertEqual(c['resolution']['height'] / c['scale'], 1200)
        physical = {'name': 'DP-1', 'width': 2560, 'height': 1440, 'refreshRate': 165,
                    'x': 0, 'y': 0, 'scale': 1}
        with patch.object(self.helper, 'guard'), patch.object(self.helper, 'monitors', return_value=[physical]), \
                patch.object(self.helper, 'active', return_value=False), \
                patch.object(self.helper, 'command', return_value='{"int":0}'), \
                patch.object(self.helper, 'lua_monitor') as apply:
            self.helper.prepare(c)
        self.assertEqual(apply.call_args_list[0].args[0]['position'], '0x0')
        virtual = apply.call_args_list[1].args[0]
        self.assertEqual(virtual['mode'], '2880x1800@60')
        self.assertEqual(virtual['position'], '-1920x0')
        self.assertEqual(virtual['scale'], 1.5)

    def test_scale_validation_and_legacy_config(self):
        c = {'position': 'left', 'resolution': {'width': 1920, 'height': 1200}}
        for scale in [None, 1, 1.5, 0, -1, True, '1.5', float('nan'), float('inf'), 1.7]:
            candidate = dict(c)
            if scale is not None:
                candidate['scale'] = scale
            with self.subTest(scale=scale), \
                    patch.object(self.helper.sys, 'argv', ['laptop-monitor', 'status', json.dumps(candidate)]):
                if scale is None or type(scale) in (int, float) and scale in (1, 1.5):
                    self.assertEqual(self.helper.config(), candidate)
                else:
                    with self.assertRaises(ValueError):
                        self.helper.config()

    def test_output_without_session_is_disconnected(self):
        with patch.object(self.helper, 'active', return_value=True), \
                patch.object(self.helper.urllib.request, 'urlopen', return_value=self.server('SUNSHINE_SERVER_FREE')), \
                patch.object(self.helper, 'remote') as remote:
            status = self.helper.connection_status(self.config)
        self.assertFalse(status['active'])
        self.assertTrue(status['outputPresent'])
        self.assertIn('reconnect', status['error'])
        remote.assert_not_called()

    def test_busy_host_requires_video_confirmed_by_laptop(self):
        for streaming in [False, True]:
            with self.subTest(streaming=streaming), patch.object(self.helper, 'active', return_value=True), \
                    patch.object(self.helper.urllib.request, 'urlopen', return_value=self.server('SUNSHINE_SERVER_BUSY')), \
                    patch.object(self.helper, 'remote', return_value=json.dumps({'streaming': streaming})):
                self.assertEqual(self.helper.connection_status(self.config)['active'], streaming)

    def test_unreachable_laptop_never_keeps_connected_state(self):
        with patch.object(self.helper, 'active', return_value=True), \
                patch.object(self.helper.urllib.request, 'urlopen', return_value=self.server('SUNSHINE_SERVER_BUSY')), \
                patch.object(self.helper, 'remote', side_effect=TimeoutError):
            self.assertFalse(self.helper.connection_status(self.config)['active'])

    def test_no_output_does_not_probe_laptop(self):
        with patch.object(self.helper, 'active', return_value=False), patch.object(self.helper, 'remote') as remote:
            self.assertFalse(self.helper.connection_status(self.config)['active'])
            remote.assert_not_called()

    def test_client_requires_matching_process_fullscreen_and_decoded_video(self):
        (self.helper.CACHE / 'client.pid').write_text('1234')
        argv = b'/usr/bin/moonlight\x00stream\x00192.168.8.33\x00Desktop\x00'
        with patch.object(Path, 'read_bytes', return_value=argv), \
                patch.object(self.helper, 'client_windows', return_value=[{'pid': 1234, 'mapped': True, 'fullscreen': 2}]):
            for log, expected in [('Starting video stream', False), ('Decoded frame with POC 0', True),
                                  ('Decoded frame with POC 0\nStopping video stream...', False)]:
                (self.helper.CACHE / 'client.log').write_text(log)
                self.assertEqual(self.helper.client_status(self.config)['streaming'], expected)
        with patch.object(Path, 'read_bytes', return_value=b'/usr/bin/other\x00'):
            self.assertFalse(self.helper.client_status(self.config)['streaming'])

    def test_stale_output_click_reconnects_instead_of_disconnecting(self):
        with patch.object(self.helper, 'config', return_value=self.config), \
                patch.object(self.helper, 'session_environment'), patch.object(self.helper, 'connection_status', return_value={'active': False}), \
                patch.object(self.helper, 'start_stream') as start, patch.object(self.helper, 'start_watch') as watch, \
                patch.object(self.helper, 'cleanup') as cleanup, patch.object(self.helper.sys, 'argv', ['laptop-monitor', 'toggle']):
            self.helper.main()
            start.assert_called_once_with(self.config)
            watch.assert_called_once()
            cleanup.assert_not_called()

    def test_disconnect_always_removes_output_even_if_laptop_unreachable(self):
        with patch.object(self.helper, 'config', return_value=self.config), \
                patch.object(self.helper, 'session_environment'), patch.object(self.helper, 'connection_status', return_value={'active': True}), \
                patch.object(self.helper, 'remote', side_effect=TimeoutError), patch.object(self.helper, 'cleanup') as cleanup, \
                patch.object(self.helper.sys, 'argv', ['laptop-monitor', 'toggle']):
            with self.assertRaises(TimeoutError):
                self.helper.main()
            cleanup.assert_called_once_with(self.config)

    def test_watch_removes_orphan_after_repeated_loss(self):
        with patch.object(self.helper, 'active', return_value=True), \
                patch.object(self.helper, 'connection_status', return_value={'active': False}), \
                patch.object(self.helper.time, 'sleep') as sleep, patch.object(self.helper, 'remote'), \
                patch.object(self.helper, 'cleanup') as cleanup:
            self.helper.watch(self.config)
            self.assertEqual(sleep.call_count, 3)
            cleanup.assert_called_once_with(self.config)
        self.assertIn('disconnected', json.loads(self.helper.STATE.read_text())['error'])

    def test_capture_crash_retries_only_after_process_changes(self):
        for changed in [False, True]:
            calls = []
            def remote(config, action):
                calls.append(action)
                if action == 'client-start' and calls.count(action) == 1:
                    raise RuntimeError('capture failed')
            def command(args, **kwargs):
                if 'show' in args:
                    return '200' if changed and 'client-start' in calls else '100'
                return ''
            with self.subTest(changed=changed), patch.object(self.helper, 'remote', side_effect=remote), \
                    patch.object(self.helper, 'command', side_effect=command), patch.object(self.helper, 'prepare'):
                if changed:
                    self.helper.start_stream(self.config)
                    self.assertEqual(calls, ['check', 'client-start', 'client-stop', 'client-start'])
                else:
                    with self.assertRaises(RuntimeError):
                        self.helper.start_stream(self.config)
                    self.assertEqual(calls, ['check', 'client-start'])


if __name__ == '__main__':
    unittest.main()
