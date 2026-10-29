"""Deployment failure regressions. Never connects to the user's desktop."""
import argparse
import hashlib
from importlib.machinery import SourceFileLoader
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

BIN = Path(__file__).resolve().parents[1] / 'bin'
loader = SourceFileLoader('quickshell_apply_test', str(BIN / 'quickshell-apply'))
spec = importlib.util.spec_from_loader(loader.name, loader)
deploy = importlib.util.module_from_spec(spec)
loader.exec_module(deploy)
ci = deploy.ci


class LogReading(unittest.TestCase):
    def test_current_instance_text_log_is_tailed_without_binary_decoder(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'quickshell/by-pid/123/log.log'
            path.parent.mkdir(parents=True)
            path.write_text(''.join(f'line {i}\n' for i in range(1300)))
            with patch.dict(os.environ, {'XDG_RUNTIME_DIR': tmp}), \
                 patch.object(deploy, 'process_id', return_value=123), \
                 patch.object(deploy, 'run') as run:
                text = deploy.logs()
            self.assertEqual(text.splitlines()[0], 'line 100')
            self.assertEqual(text.splitlines()[-1], 'line 1299')
            run.assert_not_called()

    def test_log_from_replaced_instance_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'quickshell/by-pid/123/log.log'
            path.parent.mkdir(parents=True)
            path.write_text('Configuration Loaded\n')
            with patch.dict(os.environ, {'XDG_RUNTIME_DIR': tmp}), \
                 patch.object(deploy, 'process_id', side_effect=[123, 456]), \
                 self.assertRaises(deploy.DeployFailure):
                deploy.logs()

    def test_older_instance_without_text_log_uses_cli(self):
        with tempfile.TemporaryDirectory() as tmp, \
             patch.dict(os.environ, {'XDG_RUNTIME_DIR': tmp}), \
             patch.object(deploy, 'process_id', return_value=123), \
             patch.object(deploy, 'run', return_value='CLI log') as run:
            self.assertEqual(deploy.logs(), 'CLI log')
            self.assertIn('--log-times', run.call_args.args[0])


class CertificateTests(unittest.TestCase):
    def setUp(self):
        self.state = {'ref': 'known-good', 'invariants': {}}
        self.report = {
            'schema': 1, 'passed': True, 'base': 'known-good',
            'checkedAt': time.time(), 'sourcePath': str(deploy.ROOT / ci.SHELL),
            'sourceHash': ci.fingerprint(deploy.ROOT / ci.SHELL),
            'producerHash': hashlib.sha256((BIN / 'quickshell-ci').read_bytes()).hexdigest(),
            'applyHash': hashlib.sha256((BIN / 'quickshell-apply').read_bytes()).hexdigest(),
            'regressionHash': ci.fingerprint(deploy.ROOT / 'sdata/dist-arch/tests'),
            'scenarioHash': ci.fingerprint(deploy.ROOT / 'sdata/dist-arch/tests/quickshell'),
            'version': 'fixture', 'invariantHashes': {},
        }

    def test_matching_certificate(self):
        with patch.object(deploy, 'run', return_value='fixture'):
            deploy.certificate(self.report, self.state)

    def test_malformed_certificate_rejected(self):
        for report in [None, [], {}, {'checkedAt': None}, {'checkedAt': 'yesterday'}]:
            with self.subTest(report=report), self.assertRaises(deploy.DeployFailure):
                deploy.certificate(report, self.state)

    def test_stale_failed_changed_or_wrong_baseline_rejected(self):
        for key, value in [('checkedAt', time.time() - 1801), ('passed', False),
                           ('base', 'other'), ('sourceHash', 'changed'),
                           ('producerHash', 'changed'), ('applyHash', 'changed'),
                           ('regressionHash', 'changed'), ('scenarioHash', 'changed'),
                           ('sourcePath', '/temporary/source'), ('version', 'other'),
                           ('invariantHashes', {'unrelated.qml': 'changed'})]:
            with self.subTest(key=key), patch.object(deploy, 'run', return_value='fixture'):
                with self.assertRaises(deploy.DeployFailure):
                    deploy.certificate(dict(self.report, **{key: value}), self.state)


class DesktopChecks(unittest.TestCase):
    def test_fullscreen_suppression_matches_visible_workspace_and_monitor(self):
        monitors = [{'id': 0, 'name': 'laptop', 'activeWorkspace': {'id': 3}},
                    {'id': 1, 'name': 'external', 'activeWorkspace': {'id': 4}}]
        client = {'monitor': 0, 'mapped': True, 'hidden': False, 'workspace': {'id': 3}, 'fullscreen': 2}
        self.assertEqual(deploy.expected_bars(monitors, [client]), (['external'], ['laptop']))
        for changes in [{'fullscreen': 1}, {'mapped': False}, {'hidden': True}, {'workspace': {'id': 9}}]:
            with self.subTest(changes=changes):
                self.assertEqual(deploy.expected_bars(monitors, [dict(client, **changes)]), (['external', 'laptop'], []))
        pinned = dict(client, workspace={'id': 9}, pinned=True)
        self.assertEqual(deploy.expected_bars(monitors, [pinned]), (['external'], ['laptop']))

    def test_fullscreen_allows_hidden_bar_but_unexpected_absence_still_fails(self):
        monitor = {'id': 0, 'name': 'laptop', 'dpmsStatus': True, 'activeWorkspace': {'id': 3}}
        client = {'monitor': 0, 'workspace': {'id': 3}, 'fullscreen': 2}
        def fixture(argv, **kwargs):
            if 'isActive' in argv: return 'false'
            if 'monitors' in argv: return json.dumps([monitor])
            if 'clients' in argv: return json.dumps([client])
            return '{}'
        with patch.object(deploy, 'run', side_effect=fixture), \
             patch.object(deploy, 'process_id', return_value=123), \
             patch.object(deploy, 'optional_control', return_value=None):
            self.assertEqual(deploy.snapshot()['fullscreen'], ['laptop'])
            client['fullscreen'] = 0
            with self.assertRaises(deploy.DeployFailure):
                deploy.snapshot()

    def test_native_bar_presence_and_duplicates(self):
        bar = {'namespace': 'quickshell:bar', 'w': 1600, 'h': 40}
        self.assertEqual(deploy.bar_outputs({'screen': {'levels': {'2': [bar]}}}), ['screen'])
        self.assertEqual(deploy.bar_outputs({'screen': {'levels': {'2': []}}}), [])
        with self.assertRaises(deploy.DeployFailure):
            deploy.bar_outputs({'screen': [bar, bar]})

    def test_locked_unknown_asleep_and_missing_bar_rejected(self):
        for lock, monitors, layers in [('true', [], {}), ('unknown', [], {}),
                ('false', [{'dpmsStatus': False}], {}),
                ('false', [{'dpmsStatus': True}], {})]:
            def fixture(argv, **kwargs):
                if 'isActive' in argv:
                    return lock
                return json.dumps(monitors if 'monitors' in argv else layers)
            with self.subTest(lock=lock, monitors=monitors), patch.object(deploy, 'run', side_effect=fixture):
                with self.assertRaises(deploy.DeployFailure):
                    deploy.snapshot()

    def test_live_drift_and_symlinks_rejected(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(deploy, 'LIVE', Path(directory)):
            path = Path(directory) / 'file.qml'
            path.write_bytes(b'local customization')
            state = {'hashes': {'file.qml': deploy.sha(path.read_bytes())}}
            deploy.verify_state(state)
            path.write_bytes(b'concurrent edit')
            with self.assertRaises(deploy.DeployFailure):
                deploy.verify_state(state)
            path.unlink()
            path.symlink_to('/nonexistent')
            with self.assertRaises(deploy.DeployFailure):
                deploy.file_bytes(path)


class RuntimeChecks(unittest.TestCase):
    def test_baseline_reload_warning_requires_exact_unchanged_source(self):
        warning = 'WARN scene: @services/Notifications.qml[line]: Unable to assign [undefined] to QString'
        report = {'baselineReloadDiagnostics': [warning]}
        with patch.object(deploy, 'blob', return_value=b'unchanged'):
            self.assertEqual(deploy.unchanged_reload_diagnostics(report, 'old', 'new'), {warning})
        with patch.object(deploy, 'blob', side_effect=[b'old', b'new']):
            self.assertFalse(deploy.unchanged_reload_diagnostics(report, 'old', 'new'))
        with patch.object(deploy, 'blob', return_value=None):
            self.assertFalse(deploy.unchanged_reload_diagnostics(report, 'old', 'new'))
        report['baselineReloadDiagnostics'] = [warning.replace('WARN', 'ERROR')]
        self.assertFalse(deploy.unchanged_reload_diagnostics(report, 'old', 'new'))

    def test_diagnostic_normalization_preserves_real_errors(self):
        first = 'WARN qml: Object_QMLTYPE_123(0xab12) [12:4] No session for pid 10'
        second = 'WARN qml: Object_QMLTYPE_456(0xcd34) [90:4] No session for pid 20'
        self.assertEqual(ci.diagnostic_lines(first), ci.diagnostic_lines(second))
        self.assertNotEqual(ci.diagnostic_lines(first), ci.diagnostic_lines('WARN qml: ReferenceError: missingFunction'))

    def test_log_offset_uses_bytes_and_rejects_failed_load(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'log'
            old = 'unicode → previous Configuration Loaded\n'.encode()
            log.write_bytes(old + b'Failed to load configuration\n')
            with self.assertRaises(ci.CheckFailure):
                ci.wait_loaded(None, log, len(old), .1)

    def test_fingerprint_detects_content_and_mode_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            file = root / 'sample'
            file.write_text('one')
            first = ci.fingerprint(root)
            file.write_text('two')
            self.assertNotEqual(first, ci.fingerprint(root))
            second = ci.fingerprint(root)
            file.chmod(0o755)
            self.assertNotEqual(second, ci.fingerprint(root))

    def test_watchdog_resumes_only_its_dummy_process_on_parent_pipe_close(self):
        child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(15)'])
        watchdog = None
        try:
            watchdog = deploy.pause_with_watchdog(child.pid)
            watchdog.stdin.close()
            watchdog.wait(timeout=5)
            self.assertNotEqual(Path(f'/proc/{child.pid}/stat').read_text().split()[2], 'T')
        finally:
            # The test owns this dummy process; the real shell is never queried.
            child.send_signal(signal.SIGCONT)
            child.terminate()
            child.wait(timeout=5)
            if watchdog:
                watchdog.stdout.close()

    def test_partial_write_restores_git_release_without_killing_shell(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            live = root / 'live'
            live.mkdir()
            (live / 'a.qml').write_bytes(b'old')
            (root / 'last-good.json').write_text(json.dumps({'ref': 'old', 'hashes': {'a.qml': deploy.sha(b'old')}, 'invariants': {}}))
            report = root / 'report.json'
            report.write_text('{}')
            before = {'pid': 123, 'outputs': ['screen'], 'control': {'generation': 1}}
            calls = []
            def fixture_git(*args):
                if args[0] == 'rev-parse': return 'new'
                if args[0] == 'diff': return deploy.PREFIX + 'a.qml'
                return ''
            def fixture_update(ref, names, snapshot):
                calls.append(ref)
                (live / 'a.qml').write_bytes(b'partial' if ref == 'new' else b'old')
                if ref == 'new': raise OSError('injected mid-write failure')
            stamp = time.strftime('%Y-%m-%d %H:%M:%S') + '.999'
            with patch.object(deploy, 'STATE', root), patch.object(deploy, 'LIVE', live), \
                 patch.object(deploy, 'git', side_effect=fixture_git), \
                 patch.object(deploy, 'managed', return_value=['a.qml']), \
                 patch.object(deploy, 'blob', return_value=b'old'), \
                 patch.object(deploy, 'snapshot', return_value=before), \
                 patch.object(deploy, 'certificate'), \
                 patch.object(deploy, 'update', side_effect=fixture_update), \
                 patch.object(deploy, 'logs', return_value=stamp + ' INFO Configuration Loaded'), \
                 patch.object(deploy, 'run', return_value='{}'), \
                 patch.object(deploy, 'bar_outputs', return_value=['screen']), \
                 patch.object(deploy.os, 'kill') as kill:
                with self.assertRaisesRegex(deploy.DeployFailure, 'injected mid-write'):
                    deploy.apply(argparse.Namespace(report=str(report)))
                self.assertEqual(calls, ['new', 'old'])
                self.assertEqual((live / 'a.qml').read_bytes(), b'old')
                kill.assert_not_called()


if __name__ == '__main__':
    unittest.main()
