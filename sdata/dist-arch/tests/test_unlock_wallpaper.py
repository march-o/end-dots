"""Exercise the real unlock action with a compositor-style PATH."""
import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path


class UnlockWallpaper(unittest.TestCase):
    def test_unlock_resolves_helper_without_local_bin_in_path(self):
        repo = Path(__file__).resolve().parents[3]
        source = (repo / 'dots/.config/quickshell/ii/modules/common/panels/lock/LockScreen.qml').read_text()
        body = re.search(r'function finishUnlock\(\) \{(.*?)\n    \}', source, re.S).group(1)
        with tempfile.TemporaryDirectory(prefix='unlock wallpaper ') as tmp:
            home = Path(tmp)
            helper = home / '.local/bin/wallpaper-next'
            helper.parent.mkdir(parents=True)
            helper.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$UNLOCK_TEST_MARKER"\n')
            helper.chmod(0o755)
            marker = home / 'called'
            env = dict(os.environ, PATH='/usr/bin:/bin', UNLOCK_TEST_MARKER=str(marker))
            program = r'''
const vm = require('node:vm');
const {spawnSync} = require('node:child_process');
const input = JSON.parse(require('node:fs').readFileSync(0, 'utf8'));
let calls = 0;
const globals = {screenLocked: true};
const context = vm.createContext({
  GlobalStates: globals,
  Directories: {home: 'file://' + input.home},
  FileUtils: {trimFileProtocol: path => path.replace(/^file:\/\//, '')},
  Quickshell: {execDetached(command) {
    calls++;
    const result = spawnSync(command[0], command.slice(1), {env: process.env});
    if (result.error || result.status !== 0) throw new Error('Wallpaper helper failed');
  }}
});
const unlock = vm.runInContext('(function() {' + input.body + '})', context);
unlock(); unlock();
if (globals.screenLocked || calls !== 1) throw new Error('Unlock ran more than once');
'''
            subprocess.run(['node', '-e', program], input=json.dumps({'body': body, 'home': str(home)}),
                           env=env, text=True, capture_output=True, check=True)
            self.assertEqual(marker.read_text(), '--random\n')


if __name__ == '__main__':
    unittest.main()
