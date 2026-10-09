#!/usr/bin/env python3
"""Spotify Connect through the user's existing Home Assistant on ash.

Credentials stay on ash. Only device names and playback state cross SSH.
"""
import json
import subprocess
import sys

REMOTE = r"""
import json,urllib.request
from pathlib import Path
params = REQUEST
values = {}
for line in Path('/home/martins/homelab/.env').read_text().splitlines():
    if '=' in line and not line.lstrip().startswith('#'):
        k,v = line.split('=',1)
        values[k.strip()] = v.strip().strip(chr(34)).strip(chr(39))
def call(path,payload=None):
    req=urllib.request.Request('http://127.0.0.1:8123/api/'+path,
        data=None if payload is None else json.dumps(payload).encode(),
        headers={'Authorization':'Bearer '+values['HA_TOKEN'],'Content-Type':'application/json'})
    with urllib.request.urlopen(req,timeout=5) as response:return json.load(response)
entity='media_player.spotify_martinjs'
if params['action']=='select':
    call('services/media_player/select_source',{'entity_id':entity,'source':params['source']})
    call('services/homeassistant/update_entity',{'entity_id':entity})
state=call('states/'+entity)
a=state['attributes']
sources=list(dict.fromkeys(([a['source']] if a.get('source') else [])+a.get('source_list',[])))
print(json.dumps({'ok':True,'source':a.get('source',''),'devices':sources,'state':state['state']}))
"""

def main():
    action=sys.argv[1] if len(sys.argv)>1 else 'status'
    if action not in ['status','select']:raise ValueError('Invalid action')
    request={'action':action}
    if action=='select':
        request['source']=sys.argv[2]
        if not request['source'] or len(request['source'])>200:raise ValueError('Invalid device')
    code=REMOTE.replace('REQUEST',repr(request),1)
    result=subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=3','ash','python3','-'],input=code,text=True,capture_output=True,timeout=12)
    if result.returncode:raise RuntimeError('Spotify connection unavailable')
    data=json.loads(result.stdout)
    print(json.dumps(data))

if __name__=='__main__':
    try:main()
    except Exception:print(json.dumps({'ok':False,'error':'Could not reach Spotify on ash. Retry when connected.'}))
