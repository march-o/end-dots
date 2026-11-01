#!/usr/bin/env python3
'''Fast speaker commands and read-only Connect state; credentials stay on Ash.'''
import json
import math
import subprocess
import sys

VOLUME_REMOTE = "\nimport json,subprocess\nfrom pathlib import Path\nparams = REQUEST\ntry:\n    cache=json.loads((Path.home()/'.cache/quickshell/spotify-connect.json').read_text())\n    ip=cache.get('speaker_ip')\n    if not ip:raise RuntimeError('No known speaker address')\n    probe = r'''import json,sys,soco\nsoco.config.REQUEST_TIMEOUT=2\nspeaker=soco.SoCo(sys.argv[1])\nspeaker.volume=round(float(sys.argv[2])*100)\nprint(json.dumps({'ok':True,'volume':speaker.volume/100}))\n'''\n    result=subprocess.run(['docker','exec','-i','homeassistant','python3','-',ip,str(params['value'])],input=probe,text=True,capture_output=True,timeout=6)\n    if result.returncode:raise RuntimeError('Speaker volume request failed')\n    print(json.dumps(json.loads(result.stdout)))\nexcept Exception:\n    print(json.dumps({'ok':False,'error':'Could not change Living Room volume. Check the speaker and retry.'}))\n\n"
REMOTE = r"""
import json,time,urllib.request,urllib.error,urllib.parse,fcntl,subprocess,os
from pathlib import Path
params=REQUEST
deploy=Path.home()/'projects/home-assistant/deploy'
class DeviceError(Exception):pass
music=json.loads((deploy/'source/projects/home/mcp/home.json').read_text())['music']
room_entity=music['player'];room_name=music['device']
cache_path=Path.home()/'.cache/quickshell/spotify-connect.json'
cache_path.parent.mkdir(parents=True,exist_ok=True)
def read_cache():
    try:return json.loads(cache_path.read_text())
    except (OSError,ValueError):return {}
cache=read_cache()
def save(patch):
    # Serialize only a short atomic cache merge, never network or Docker work.
    with cache_path.with_suffix('.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        latest=read_cache();latest.update(patch)
        temp=cache_path.with_suffix('.tmp');temp.write_text(json.dumps(latest));temp.replace(cache_path)
    cache.update(patch)
_token=None
def home_token():
    global _token
    if _token:return _token
    try:
        values={}
        for line in (deploy/'secrets/piper-legacy.env').read_text().splitlines():
            if '=' in line and not line.lstrip().startswith('#'):
                key,value=line.split('=',1);values[key.strip()]=value.strip().strip(chr(34)).strip(chr(39))
        caller=values['PIPER_LEGACY_TOKEN']
        req=urllib.request.Request('http://127.0.0.1:4318/v1/call',
            data=json.dumps({'operation':'secrets.get','args':{'name':'homeassistant.token'}}).encode(),
            headers={'Authorization':'Bearer '+caller,'Content-Type':'application/json'})
        with urllib.request.urlopen(req,timeout=3) as response:_token=json.load(response).get('result',{}).get('value')
        if not isinstance(_token,str) or not _token:raise ValueError('Missing token')
        return _token
    except Exception:raise DeviceError('Home playback access is unavailable on Ash.')
def call(path,payload=None,timeout=5):
    req=urllib.request.Request('http://127.0.0.1:8123/api/'+path,
        data=None if payload is None else json.dumps(payload).encode(),
        headers={'Authorization':'Bearer '+home_token(),'Content-Type':'application/json'})
    try:
        with urllib.request.urlopen(req,timeout=timeout) as response:return json.load(response)
    except urllib.error.HTTPError as error:
        raise DeviceError('Home playback request failed (HTTP '+str(error.code)+').')
    except (urllib.error.URLError,TimeoutError):raise DeviceError('Home playback request timed out; it was not retried.')
def control(action,value=None):
    # Transport commands never wait for metadata, discovery, a cloud read,
    # or the status cache lock. No skip/seek/recovery is retried automatically.
    if action=='play':return play_room(resume=True)
    names={'pause':'media_pause','next':'media_next_track','previous':'media_previous_track','seek':'media_seek'}
    data={'entity_id':room_entity}
    if action=='seek':data['seek_position']=max(0,float(value))
    call('services/media_player/'+names[action],data)
    return {'ok':True,'accepted':True}
def play_room(resume=False):
    operation='resume' if resume else 'transfer'
    response=call('services/home_music/'+operation+'?return_response',{'player':room_entity},timeout=30).get('service_response',{})
    if response.get('verified') is not True:raise DeviceError(response.get('reason') or 'Playback is not confirmed; no retry was sent.')
    save({'room_mode':True})
    return {'ok':True,'accepted':True,'verified':True}
def select(source):
    if source==room_name:return play_room()
    # Other available Spotify devices use the same modern SpotifyPlus owner.
    # There is no widget-specific OAuth refresh or private token cache.
    call('services/spotifyplus/player_transfer_playback',{
        'entity_id':music['account_entity'],'device_id':source,'play':True},timeout=30)
    save({'room_mode':False})
    return {'ok':True,'accepted':True}
def room():
    probe=r'''import json,sys,soco,xml.etree.ElementTree as ET,urllib.parse
soco.config.REQUEST_TIMEOUT=2
s=soco.SoCo(sys.argv[1]) if sys.argv[1] else next((p for p in soco.discover(timeout=2) or [] if p.player_name==sys.argv[2]),None)
if s is None:raise RuntimeError('Speaker unavailable')
ip=s.ip_address;volume=s.volume/100;s=s.group.coordinator
transport=s.get_current_transport_info()['current_transport_state'];t=s.get_current_track_info()
def seconds(value):
    try:return sum(int(v)*60**i for i,v in enumerate(reversed(value.split(':'))))
    except (ValueError,AttributeError):return 0
uri=''
try:
 for node in ET.fromstring(t.get('metadata','')).iter():
  value=urllib.parse.unquote(node.text or '')
  if node.tag.rsplit('}',1)[-1]=='res' and value.startswith('x-sonos-spotify:'):
   uri=value.removeprefix('x-sonos-spotify:').split('?',1)[0];break
except ET.ParseError:pass
print(json.dumps({'ip':ip,'state':{'PLAYING':'playing','PAUSED_PLAYBACK':'paused','STOPPED':'idle','TRANSITIONING':'buffering'}.get(transport,'idle'),
 'title':t.get('title',''),'artist':t.get('artist',''),'uri':uri,'duration':seconds(t.get('duration')),
 'position':seconds(t.get('position')),'volume':volume,'actions':s.available_actions,
 'source':'Spotify Connect' if t.get('uri','').startswith('x-sonos-vli:') and ',spotify:' in t.get('uri','') else '',
 'art':t.get('album_art','')}))
'''
    result=subprocess.run(['docker','exec','-i','homeassistant','python3','-',cache.get('speaker_ip',''),room_name],input=probe,text=True,capture_output=True,timeout=8)
    if result.returncode:
        save({'speaker_ip':''})
        raise DeviceError('Cannot read Living Room playback. Check the speaker connection.')
    actual=json.loads(result.stdout);save({'speaker_ip':actual.pop('ip')});return actual

def devices(force=False):
    names=cache.get('devices',[room_name])
    if force or time.time()-cache.get('devices_at',0)>60:
        try:
            result=call('services/spotifyplus/get_player_devices?return_response',{'entity_id':music['account_entity']}).get('service_response',{}).get('result',[])
            names=list(dict.fromkeys([room_name]+[d['name'] for d in result if d.get('name') and d['name']!=music.get('preparation_device')]))
            save({'devices':names,'devices_at':time.time()})
        except DeviceError:pass
    return names

def output():
    # Speaker reads and canonical cloud confirmation are read-only. A cloud
    # outage is unknown confirmation, never evidence that playback stopped.
    r=room();warning='';connected=None;sp={}
    try:
        response=call('services/home_music/status?return_response',{}).get('service_response',{})
        if response.get('playback'):
            playback=response['playback'];sp=playback['spotify'];native=playback['sonos']
            connected=bool(sp.get('device')==room_name and native.get('source')=='Spotify Connect'
                and sp.get('track_uri') and sp.get('track_uri')==native.get('track_uri'))
        else:warning=response.get('reason') or 'Spotify confirmation is unavailable.'
    except DeviceError as error:warning=str(error)
    source=sp.get('device') or ''
    active=connected is True or (bool(cache.get('room_mode')) and bool(r.get('uri')) and (not source or source==room_name))
    if connected is True:save({'room_mode':True})
    elif source and source!=room_name:save({'room_mode':False})
    if connected is False and active:warning='Living Room is outside Spotify Connect. Select it to reconnect.'
    position=(sp.get('progress_ms') or 0)/1000 if connected is True else r.get('position',0)
    result={'active':active,'connected':connected,'available':r['state'] not in ['unknown','unavailable'],
        'playing':r['state']=='playing','title':sp.get('title') if connected is True else r['title'],
        'artist':r['artist'],'uri':sp.get('track_uri') if connected is True else r['uri'],
        'art':r['art'],'volume':r['volume'],'duration':r['duration'],
        'position':min(position,r['duration']) if r['duration'] else position,
        'can_next':'Next' in r['actions'],'can_previous':'Previous' in r['actions'],'can_seek':'SeekTime' in r['actions']}
    return {'ok':True,'source':source,'devices':devices(params.get('devices',False)),'warning':warning,'room':result,'state':r['state']}

try:
    action=params['action']
    if action=='status':result=output()
    elif action=='room-control':result=control(params['control'],params.get('value'))
    elif action=='play-room':result=play_room()
    else:result=select(params['source'])
    print(json.dumps(result))
except DeviceError as error:print(json.dumps({'ok':False,'error':str(error)}))
except Exception:print(json.dumps({'ok':False,'error':'Home could not complete this request. No automatic retry was sent.'}))
"""

def main():
    action=sys.argv[1] if len(sys.argv)>1 else 'status'
    if action not in ['status','select','play-room','room-control','room-volume']:raise ValueError('Invalid action')
    request={'action':action}
    if action=='status':request['devices']='--devices' in sys.argv[2:]
    if action=='select':
        request['source']=sys.argv[2]
        if not request['source'] or len(request['source'])>200:raise ValueError('Invalid device')
    if action=='room-control':
        request['control']=sys.argv[2]
        if request['control'] not in ['play','pause','next','previous','seek']:raise ValueError('Invalid control')
        if request['control']=='seek':
            value=float(sys.argv[3])
            if not math.isfinite(value):raise ValueError('Invalid seek position')
            request['value']=max(0,value)
    if action=='room-volume':
        value=float(sys.argv[2])
        if not math.isfinite(value):raise ValueError('Invalid volume')
        request['value']=max(0,min(1,value))
    code=(VOLUME_REMOTE if action=='room-volume' else REMOTE).replace('REQUEST',repr(request),1)
    timeout=10 if action=='room-volume' else (18 if action=='status' else (35 if action in ['play-room','select'] or request.get('control')=='play' else 10))
    result=subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=3','ash','python3','-'],input=code,text=True,capture_output=True,timeout=timeout)
    if result.returncode:raise RuntimeError('Home connection unavailable')
    print(json.dumps(json.loads(result.stdout)))

if __name__=='__main__':
    try:main()
    except Exception:print(json.dumps({'ok':False,'error':'Could not reach Home on Ash. This command was not retried.'}))
