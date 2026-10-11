#!/usr/bin/env python3
"""Spotify Connect through the user's existing Home Assistant on ash.

Credentials stay on ash. Only device names and playback state cross SSH.
"""
import json
import subprocess
import sys

REMOTE = r"""
import json,time,urllib.request
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
room_entity='media_player.living_room'
room_name='Living Room'
def status():
    return call('states/'+entity)
def sources(state):
    a=state['attributes']
    return list(dict.fromkeys([room_name]+([a['source']] if a.get('source') else [])+a.get('source_list',[])))
class DeviceError(Exception):pass
def select(source):
    state=status()
    a=state['attributes']
    if a.get('source')==source:return
    if source==room_name and source not in a.get('source_list',[]):
        room=call('states/'+room_entity)
        if room['state'] in ['unavailable','unknown']:
            raise DeviceError('Living Room is offline. Check the speaker and retry.')
        # Resume its existing Spotify Connect session; an idle Sonos can disappear
        # from Spotify's discovery list even while Home Assistant can reach it.
        if room['attributes'].get('source')!='Spotify Connect':
            raise DeviceError('Open Spotify on Living Room once, then retry.')
        call('services/media_player/media_play',{'entity_id':room_entity})
    else:
        call('services/media_player/select_source',{'entity_id':entity,'source':source})
    # HA's Spotify state can lag behind the actual transfer. Verify the destination
    # before reporting success, without hammering its API or silently playing locally.
    deadline=time.monotonic()+45
    while True:
        call('services/homeassistant/update_entity',{'entity_id':entity})
        state=status()
        if state['attributes'].get('source')==source:return
        if time.monotonic()>=deadline:
            raise DeviceError('Spotify has not confirmed the device switch. Refresh and retry.')
        time.sleep(2)
try:
    if params['action'] in ['select','play-room']:
        select(room_name if params['action']=='play-room' else params['source'])
    if params['action']=='play-room':
        # Use Sonos to resume: Spotify's select/play service can reject a speaker
        # that is the current source but is absent from its source_list.
        call('services/media_player/media_play',{'entity_id':room_entity})
    state=status()
    a=state['attributes']
    print(json.dumps({'ok':True,'source':a.get('source',''),'devices':sources(state),'state':state['state']}))
except DeviceError as error:
    print(json.dumps({'ok':False,'error':str(error)}))
"""

def main():
    action=sys.argv[1] if len(sys.argv)>1 else 'status'
    if action not in ['status','select','play-room']:raise ValueError('Invalid action')
    request={'action':action}
    if action=='select':
        request['source']=sys.argv[2]
        if not request['source'] or len(request['source'])>200:raise ValueError('Invalid device')
    code=REMOTE.replace('REQUEST',repr(request),1)
    result=subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=3','ash','python3','-'],input=code,text=True,capture_output=True,timeout=70 if action!='status' else 12)
    if result.returncode:raise RuntimeError('Spotify connection unavailable')
    data=json.loads(result.stdout)
    print(json.dumps(data))

if __name__=='__main__':
    try:main()
    except Exception:print(json.dumps({'ok':False,'error':'Could not reach Spotify on ash. Retry when connected.'}))
