#!/usr/bin/env python3
"""Use the existing Home lighting owner on Ash; no credentials leave Ash."""
import json
import subprocess
import sys

REMOTE = r"""
import json, urllib.request
from pathlib import Path
request = REQUEST
try:
    token = (Path.home()/'.config/home-assistant/home-tool.token').read_text().strip()
    def call(operation, args):
        req = urllib.request.Request('http://127.0.0.1:18794/api/lights/' + operation,
            data=json.dumps(args).encode(), headers={'Authorization': 'Bearer ' + token,
            'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.load(response)
    names = call('scenes', {})
    if not isinstance(names, list) or not all(isinstance(n, str) and n for n in names):
        raise ValueError('Invalid discovery')
    if request['action'] == 'scenes':
        result = {'ok': True, 'presets': names}
    else:
        name = request['preset']
        if name != '__off__' and name not in names:
            raise ValueError('Preset no longer available')
        result = call('off' if name == '__off__' else 'scene', {} if name == '__off__' else {'scene': name})
        if not isinstance(result, dict) or result.get('accepted') is not True:
            raise ValueError('Dispatch unconfirmed')
        result = {'ok': True, 'result': result}
    print(json.dumps(result))
except Exception:
    print(json.dumps({'ok': False, 'error': 'Home lighting unavailable. A command may have been sent; no automatic retry.'}))
"""


def run(action, preset=None):
    if action not in ('scenes', 'select'):
        raise ValueError('Invalid action')
    if action == 'select' and (not isinstance(preset, str) or not preset or len(preset) > 200):
        raise ValueError('Invalid preset')
    code = REMOTE.replace('REQUEST', repr({'action': action, 'preset': preset}), 1)
    result = subprocess.run(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=3',
        'ash', 'python3', '-'], input=code, text=True, capture_output=True, timeout=40)
    if result.returncode:
        raise RuntimeError('Home connection unavailable')
    return json.loads(result.stdout)


if __name__ == '__main__':
    try:
        print(json.dumps(run(sys.argv[1] if len(sys.argv) > 1 else 'scenes',
            sys.argv[2] if len(sys.argv) > 2 else None)))
    except Exception:
        print(json.dumps({'ok': False, 'error': 'Could not reach Home on Ash. No automatic retry; command outcome may be unknown.'}))
