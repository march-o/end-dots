#!/usr/bin/env python3
"""Discovery and one-shot dispatch contract; all HTTP and SSH are mocked."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('lighting', ROOT / 'dots/.config/quickshell/ii/scripts/home-lighting.py')
lighting = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lighting)


class LightingTests(unittest.TestCase):
    def remote(self, action, preset=None, names=None, accepted=True, failure=False):
        self.calls = []
        names = ['unwind', 'chill', 'building', 'cooking', 'morning', 'new preset'] if names is None else names
        def open_request(req, **kwargs):
            self.calls.append((req.full_url.rsplit('/', 1)[-1], json.loads(req.data)))
            if failure:
                raise TimeoutError('secret details must not be returned')
            return io.StringIO(json.dumps(names if len(self.calls) == 1 else {'accepted': accepted}))
        out = io.StringIO()
        code = lighting.REMOTE.replace('REQUEST', repr({'action': action, 'preset': preset}), 1)
        with patch('pathlib.Path.read_text', return_value='test-secret'), patch('urllib.request.urlopen', side_effect=open_request), contextlib.redirect_stdout(out):
            exec(code, {})
        self.assertNotIn('test-secret', out.getvalue())
        return json.loads(out.getvalue())

    def test_discovers_every_preset_without_mutation(self):
        result = self.remote('scenes')
        self.assertEqual(len(result['presets']), 6)
        self.assertIn('new preset', result['presets'])
        self.assertEqual(self.calls, [('scenes', {})])

    def test_all_discovered_scenes_dispatch_once(self):
        for name in ['unwind', 'chill', 'building', 'cooking', 'morning', 'new preset']:
            with self.subTest(name=name):
                self.assertTrue(self.remote('select', name)['ok'])
                self.assertEqual(self.calls, [('scenes', {}), ('scene', {'scene': name})])

    def test_off_is_canonical_all_lights_off(self):
        self.assertTrue(self.remote('select', '__off__')['ok'])
        self.assertEqual(self.calls, [('scenes', {}), ('off', {})])

    def test_removed_preset_never_dispatches(self):
        self.assertFalse(self.remote('select', 'removed')['ok'])
        self.assertEqual(self.calls, [('scenes', {})])

    def test_failed_acceptance_is_not_success(self):
        self.assertFalse(self.remote('select', 'chill', accepted=False)['ok'])
        self.assertEqual(len(self.calls), 2)

    def test_timeout_not_retried_or_leaked(self):
        self.assertFalse(self.remote('select', 'chill', failure=True)['ok'])
        self.assertEqual(len(self.calls), 1)

    def test_malformed_discovery_never_dispatches(self):
        self.assertFalse(self.remote('select', 'chill', names={'invalid': True})['ok'])
        self.assertEqual(len(self.calls), 1)

    def test_empty_discovery_still_allows_off(self):
        self.assertTrue(self.remote('select', '__off__', names=[])['ok'])

    def test_ssh_is_existing_alias_and_no_retry(self):
        with patch.object(subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '{"ok": true}')) as run:
            self.assertTrue(lighting.run('select', 'chill')['ok'])
        self.assertEqual(run.call_count, 1)
        argv = run.call_args.args[0]
        self.assertEqual(argv[-3:], ['ash', 'python3', '-'])
        self.assertIn("'preset': 'chill'", run.call_args.kwargs['input'])

    def test_invalid_input_never_uses_ssh(self):
        with patch.object(subprocess, 'run') as run:
            for args in [('invalid', None), ('select', ''), ('select', 'x' * 201)]:
                with self.assertRaises(ValueError):
                    lighting.run(*args)
            run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
