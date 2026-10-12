#!/usr/bin/env python3
"""One-time Spotify Connect authorization; secrets are stored only on ash.

The Desktop PKCE flow is the documented SpotifyPlus Sonos activation method:
https://github.com/thlucas1/homeassistantcomponent_spotifyplus/wiki/Device-Configuration-Options#spotify-desktop-player-authentication-configuration
Run locally; SSH forwards only the loopback callback to ash.
"""
import base64
import hashlib
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import time
import urllib.parse
import urllib.request

CLIENT_ID = '65b708073fc0480ea92a077233ca87bd'
REDIRECT = 'http://127.0.0.1:4381/login'

def authorize():
    verifier = secrets.token_urlsafe(48)
    state = secrets.token_urlsafe(32)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip('=')
    completed = False
    class Callback(BaseHTTPRequestHandler):
        def log_message(self, *_): pass  # Callback URLs contain authorization codes.
        def do_GET(self):
            nonlocal completed
            parts = urllib.parse.urlsplit(self.path)
            query = urllib.parse.parse_qs(parts.query)
            message = 'Invalid authorization response.'
            status = 400
            if parts.path == '/login' and secrets.compare_digest(query.get('state', [''])[0], state):
                if query.get('code'):
                    try:
                        body = urllib.parse.urlencode({'grant_type': 'authorization_code', 'client_id': CLIENT_ID, 'redirect_uri': REDIRECT, 'code_verifier': verifier, 'code': query['code'][0]}).encode()
                        request = urllib.request.Request('https://accounts.spotify.com/api/token', data=body, headers={'Content-Type': 'application/x-www-form-urlencoded'})
                        with urllib.request.urlopen(request, timeout=10) as response: token = json.load(response)
                        if not token.get('refresh_token') or 'streaming' not in token.get('scope', '').split(): raise ValueError('Missing Connect authorization')
                        token['expires_at'] = time.time() + token['expires_in']
                        target = Path.home() / '.local/state/quickshell/spotify-desktop-auth.json'
                        target.parent.mkdir(parents=True, exist_ok=True)
                        temporary = target.with_suffix('.tmp')
                        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
                        with os.fdopen(fd, 'w') as file: json.dump(token, file)
                        temporary.chmod(0o600); temporary.replace(target)
                        message = 'Spotify Connect authorized. You can close this tab.'
                        status = 200; completed = True
                        print('Authorization saved securely on ash.', flush=True)
                    except Exception:
                        message = 'Authorization could not be saved. Please restart the setup and retry.'
                else:
                    message = 'Spotify authorization was declined.'
                    completed = True
            self.send_response(status)
            self.send_header('Content-Type', 'text/plain; charset=utf-8')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Referrer-Policy', 'no-referrer')
            self.end_headers(); self.wfile.write(message.encode())
    with HTTPServer(('127.0.0.1', 4381), Callback) as server:
        server.timeout = 1
        url = 'https://accounts.spotify.com/authorize?' + urllib.parse.urlencode({'response_type': 'code', 'client_id': CLIENT_ID, 'redirect_uri': REDIRECT, 'scope': 'streaming', 'code_challenge_method': 'S256', 'code_challenge': challenge, 'state': state})
        print(url, flush=True)
        deadline = time.monotonic() + 900
        while not completed and time.monotonic() < deadline: server.handle_request()
        if not completed: raise TimeoutError('Authorization expired; run setup again.')

if __name__ == '__main__':
    if '--remote' in sys.argv: authorize()
    else:
        command = ['ssh', '-o', 'BatchMode=yes', '-o', 'ExitOnForwardFailure=yes', '-L', '127.0.0.1:4381:127.0.0.1:4381', 'ash', 'python3', '-', '--remote']
        raise SystemExit(subprocess.run(command, input=Path(__file__).read_text(), text=True).returncode)
