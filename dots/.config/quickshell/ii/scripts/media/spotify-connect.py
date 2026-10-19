#!/usr/bin/env python3
"""Spotify Connect through the user's existing Home Assistant on ash.

Credentials stay on ash. Only device names and playback state cross SSH.
"""
import json
import math
import subprocess
import sys

# Volume has its own short request, independent of full playback/status polls.
# It reads the cached address atomically and touches no Spotify credentials.
VOLUME_REMOTE = r"""
import json,subprocess
from pathlib import Path
params = REQUEST
try:
    cache=json.loads((Path.home()/'.cache/quickshell/spotify-connect.json').read_text())
    ip=cache.get('speaker_ip')
    if not ip:raise RuntimeError('No known speaker address')
    probe = r'''import json,sys,soco
soco.config.REQUEST_TIMEOUT=2
speaker=soco.SoCo(sys.argv[1])
speaker.volume=round(float(sys.argv[2])*100)
print(json.dumps({'ok':True,'volume':speaker.volume/100}))
'''
    result=subprocess.run(['docker','exec','-i','homeassistant','python3','-',ip,str(params['value'])],input=probe,text=True,capture_output=True,timeout=6)
    if result.returncode:raise RuntimeError('Speaker volume request failed')
    print(json.dumps(json.loads(result.stdout)))
except Exception:
    print(json.dumps({'ok':False,'error':'Could not change Living Room volume. Check the speaker and retry.'}))
"""

REMOTE = r"""
import json,time,urllib.request,urllib.parse,fcntl,subprocess,os
from pathlib import Path
from datetime import datetime,timezone
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
    with urllib.request.urlopen(req,timeout=12) as response:return json.load(response)
entity='media_player.spotify_martinjs'
room_entity='media_player.living_room'
room_name='Living Room'
cache_path=Path.home()/'.cache/quickshell/spotify-connect.json'
cache_path.parent.mkdir(parents=True,exist_ok=True)
lock=cache_path.with_suffix('.lock').open('a')
fcntl.flock(lock,fcntl.LOCK_EX)
try:cache=json.loads(cache_path.read_text())
except (OSError,ValueError):cache={}
def save():
    temp=cache_path.with_suffix('.tmp')
    temp.write_text(json.dumps(cache));temp.replace(cache_path)
def state():return call('states/'+entity)
def room():
    # HA's Sonos metadata can lag behind acknowledged transport commands.
    # Read the device itself; never present cached HA metadata as live playback.
    probe = r'''import json,sys,soco
from datetime import datetime,timezone
ip=sys.argv[1]
speaker=soco.SoCo(ip) if ip else next((s for s in soco.discover(timeout=2) or [] if s.player_name=='Living Room'),None)
if speaker is None:raise RuntimeError('Speaker unavailable')
address=speaker.ip_address
volume=speaker.volume/100
speaker=speaker.group.coordinator
transport=speaker.get_current_transport_info()['current_transport_state']
t=speaker.get_current_track_info()
def seconds(value):
    try:
        parts=[int(p) for p in value.split(':')]
        return sum(v*60**i for i,v in enumerate(reversed(parts)))
    except (ValueError,AttributeError):return 0
print(json.dumps({'ip':address,'state':{'PLAYING':'playing','PAUSED_PLAYBACK':'paused','STOPPED':'idle','TRANSITIONING':'buffering'}.get(transport,'idle'),
'attributes':{'media_title':t.get('title',''),'media_artist':t.get('artist',''),'media_content_id':t.get('uri',''),
'media_duration':seconds(t.get('duration')),'media_position':seconds(t.get('position')),
'media_position_updated_at':datetime.now(timezone.utc).isoformat(),'volume_level':volume,
'transport_actions':speaker.available_actions,
'source':'Spotify Connect' if t.get('uri','').startswith('x-sonos-vli:') else '', 'album_art':t.get('album_art','')}}))
'''
    try:
        result=subprocess.run(['docker','exec','-i','homeassistant','python3','-',cache.get('speaker_ip','')],input=probe,text=True,capture_output=True,timeout=8)
        if result.returncode:raise RuntimeError('Speaker probe failed')
        actual=json.loads(result.stdout);cache['speaker_ip']=actual.pop('ip')
        return actual
    except Exception:
        cache.pop('speaker_ip',None)
        raise DeviceError('Cannot read Living Room playback. Check its power and network, then retry.')
def service(name,target=room_entity,**data):
    return call('services/media_player/'+name,dict(entity_id=target,**data))
def uri_from(content):
    content=urllib.parse.unquote(content or '')
    import re
    match=re.search(r'spotify:(track|album|playlist):[A-Za-z0-9]+',content)
    return match.group(0) if match else ''
def remember(s):
    uri=uri_from(s['attributes'].get('media_content_id'))
    if uri:cache['last_uri']=uri
class DeviceError(Exception):pass
def wait_room():
    deadline=time.monotonic()+12
    while True:
        r=room()
        if r['state']=='playing':return r
        if time.monotonic()>=deadline:raise DeviceError('Living Room did not start playing. Check the speaker and retry.')
        time.sleep(.5)
def spotify_get(path):
    # Reuse HA's authorization on ash; no token or client secret crosses SSH.
    import base64
    base=Path('/home/martins/homelab/infra/homeassistant/.storage')
    entry=next(e for e in json.loads((base/'core.config_entries').read_text())['data']['entries'] if e['domain']=='spotify')
    token=entry['data']['token']
    if token.get('expires_at',0)<time.time()+30:
        app=next(a for a in json.loads((base/'application_credentials').read_text())['data']['items'] if a['domain']=='spotify' and a['id']==entry['data']['auth_implementation'])
        req=urllib.request.Request('https://accounts.spotify.com/api/token',data=urllib.parse.urlencode({'grant_type':'refresh_token','refresh_token':token['refresh_token']}).encode(),headers={'Authorization':'Basic '+base64.b64encode((app['client_id']+':'+app['client_secret']).encode()).decode(),'Content-Type':'application/x-www-form-urlencoded'})
        with urllib.request.urlopen(req,timeout=6) as response:token=json.load(response)
    req=urllib.request.Request('https://api.spotify.com/v1/'+path,headers={'Authorization':'Bearer '+token['access_token']})
    with urllib.request.urlopen(req,timeout=6) as response:
        body=response.read()
        return json.loads(body) if body else None
def remember_art(track):
    if not track:return
    images=(track.get('album') or {}).get('images',[])
    if images and urllib.parse.urlparse(images[0]['url']).hostname=='i.scdn.co':
        cache.setdefault('art',{})[track['uri']]=images[0]['url']
        cache['art']=dict(list(cache['art'].items())[-60:])
def is_room_playback(playback):
    return bool(playback and playback.get('device',{}).get('name')==room_name)
def desktop_token():
    path=Path.home()/'.local/state/quickshell/spotify-desktop-auth.json'
    if not path.exists():raise DeviceError('Living Room needs one-time Spotify Connect authorization. Complete the sign-in, then retry.')
    token=json.loads(path.read_text())
    if token.get('expires_at',0)<time.time()+60:
        body=urllib.parse.urlencode({'grant_type':'refresh_token','client_id':'65b708073fc0480ea92a077233ca87bd','refresh_token':token['refresh_token']}).encode()
        req=urllib.request.Request('https://accounts.spotify.com/api/token',data=body,headers={'Content-Type':'application/x-www-form-urlencoded'})
        try:
            with urllib.request.urlopen(req,timeout=8) as response:fresh=json.load(response)
        except Exception:raise DeviceError('Spotify Connect authorization expired. Complete the sign-in again.')
        fresh.setdefault('refresh_token',token['refresh_token']);fresh['expires_at']=time.time()+fresh['expires_in']
        temp=path.with_suffix('.tmp')
        fd=os.open(temp,os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
        with os.fdopen(fd,'w') as file:json.dump(fresh,file)
        temp.chmod(0o600);temp.replace(path);token=fresh
    return token['access_token']
def activate_connect():
    token=desktop_token()
    ip=cache.get('speaker_ip')
    if not ip:room();ip=cache['speaker_ip']
    url='http://'+ip+':1400/spotifyzc'
    with urllib.request.urlopen(url+'?action=getInfo',timeout=4) as response:info=json.load(response)
    if info.get('remoteName')!=room_name or info.get('tokenType')!='authorization_code':
        raise DeviceError('Living Room does not expose the expected Spotify Connect endpoint.')
    # This documented OAuth token exchange activates Sonos Connect itself.
    # It does not replace the Sonos local queue or extract app/browser secrets.
    fields={'grant_type':'urn:ietf:params:oauth:grant-type:token-exchange','subject_token':token,
        'subject_token_type':'urn:ietf:params:oauth:token-type:access_token','requested_token_type':'urn:spotify:params:oauth:authorization_code',
        'client_id':'65b708073fc0480ea92a077233ca87bd','audience':info['clientID'],
        'resource':'urn:spotify:resources:connect','scope':'streaming'}
    req=urllib.request.Request('https://accounts.spotify.com/api/token',data=urllib.parse.urlencode(fields).encode(),headers={'Content-Type':'application/x-www-form-urlencoded'})
    with urllib.request.urlopen(req,timeout=8) as response:activation=json.load(response)
    user=spotify_get('me')['id']
    fields={'action':'addUser','version':info.get('version','2.9.0'),'tokenType':'authorization_code',
        'clientKey':'','loginId':user,'userName':user,'blob':activation['access_token'],
        'deviceName':'Quickshell','deviceId':__import__('hashlib').sha1(('quickshell-'+user).encode()).hexdigest()}
    req=urllib.request.Request(url,data=urllib.parse.urlencode(fields).encode(),headers={'Content-Type':'application/x-www-form-urlencoded'})
    with urllib.request.urlopen(req,timeout=8) as response:reply=json.load(response)
    if reply.get('status')!=101:raise DeviceError('Living Room refused Spotify Connect activation. Retry authorization.')
    cache['connect_device_id']=info['deviceID']
def play_room(resume=False):
    r=room()
    # Existing true Connect sessions can resume without a new authorization.
    # Never silently fall back to a local Sonos queue: Spotify cannot see it.
    playback=spotify_get('me/player')
    if r['attributes'].get('source')!='Spotify Connect' or not is_room_playback(playback):activate_connect()
    service('media_play')
    r=wait_room()
    deadline=time.monotonic()+12
    while True:
        playback=spotify_get('me/player')
        if is_room_playback(playback) and playback.get('is_playing'):
            remember_art(playback.get('item'));cache['room_mode']=True;remember(r);save();return
        if time.monotonic()>=deadline:raise DeviceError('The speaker started, but Spotify did not confirm the Connect session. No local-queue fallback was used.')
        time.sleep(.5)
def select(source):
    if source==room_name:return play_room()
    call('services/media_player/select_source',{'entity_id':entity,'source':source})
    cache['room_mode']=False;save()
    call('services/homeassistant/update_entity',{'entity_id':entity})
def room_control():
    action=params['control']
    if action=='play':return play_room(resume=True)
    names={'pause':'media_pause','next':'media_next_track','previous':'media_previous_track','volume':'volume_set','seek':'media_seek'}
    extra={}
    if action=='volume':extra['volume_level']=max(0,min(1,float(params['value'])))
    if action=='seek':extra['seek_position']=max(0,float(params['value']))
    r=room()
    # Advancing an orphaned Sonos queue keeps Spotify blind to playback.
    # Reconnect before transport actions; pause must still stop that queue.
    if action in ['next','previous','seek']:
        if r['attributes'].get('source')!='Spotify Connect' or not is_room_playback(spotify_get('me/player')):
            play_room(resume=True)
            r=room()
    was_playing=r['state']=='playing'
    service(names[action],**extra)
    if was_playing and action in ['next','previous','seek']:wait_room()
    else:time.sleep(.5)
def output():
    s=state();remember(s);a=s['attributes']
    active=bool(cache.get('room_mode'))
    try:r=room()
    except DeviceError:
        if active:raise
        r={'state':'unavailable','attributes':{}}
    ra=r['attributes']
    connected=False if ra.get('source')!='Spotify Connect' else None
    if active and ra.get('source')=='Spotify Connect':
        try:
            playback=spotify_get('me/player')
            connected=is_room_playback(playback)
            if connected and playback.get('item'):
                track=playback['item'];remember_art(track)
                ra.update(media_title=track['name'],media_artist=', '.join(a['name'] for a in track.get('artists',[])),
                    media_content_id=track['uri'],media_duration=track['duration_ms']/1000,
                    media_position=(playback.get('progress_ms') or 0)/1000,
                    media_position_updated_at=datetime.now(timezone.utc).isoformat())
        except Exception:pass # Direct speaker state still works during an API outage.
    if active:remember(r)
    position=ra.get('media_position',0) or 0
    if r['state']=='playing' and ra.get('media_position_updated_at'):
        try:position+=max(0,(datetime.now(timezone.utc)-datetime.fromisoformat(ra['media_position_updated_at'])).total_seconds())
        except (ValueError,TypeError):pass
    duration=ra.get('media_duration',0) or 0
    uri=uri_from(ra.get('media_content_id'))
    if active and uri and not cache.get('art',{}).get(uri) and cache.get('art_checked')!=uri:
        cache['art_checked']=uri
        try:remember_art(spotify_get('tracks/'+uri.split(':')[-1]))
        except Exception:pass
    save()
    return {'ok':True,'source':(room_name if connected is not False else '') if active else (a.get('source') or ''),
        'warning':'Living Room is outside Spotify Connect. Select it to reconnect.' if active and connected is False else '',
        'devices':list(dict.fromkeys([room_name]+([a['source']] if a.get('source') else [])+a.get('source_list',[]))),
        'state':r['state'] if active else s['state'],
        'room':{'active':active,'connected':connected,'playing':r['state']=='playing','available':r['state'] not in ['unknown','unavailable'],
            'title':ra.get('media_title',''),'artist':ra.get('media_artist',''),
            'art':cache.get('art',{}).get(uri,'') or ra.get('album_art',''),
            'can_next':'Next' in ra.get('transport_actions',[]),'can_previous':'Previous' in ra.get('transport_actions',[]),'can_seek':'SeekTime' in ra.get('transport_actions',[]),
            'volume':ra.get('volume_level',0),'duration':duration,'position':min(position,duration) if duration else position}}
try:
    if params['action']=='select':select(params['source'])
    elif params['action']=='play-room':play_room()
    elif params['action']=='room-control':room_control()
    print(json.dumps(output()))
except DeviceError as error:print(json.dumps({'ok':False,'error':str(error)}))
except Exception:print(json.dumps({'ok':False,'error':'Home Assistant could not complete speaker playback. Check its Spotify/Sonos connection and retry.'}))
"""

def main():
    action=sys.argv[1] if len(sys.argv)>1 else 'status'
    if action not in ['status','select','play-room','room-control','room-volume']:raise ValueError('Invalid action')
    request={'action':action}
    if action=='room-volume':
        value=float(sys.argv[2])
        if not math.isfinite(value):raise ValueError('Invalid volume')
        request['value']=max(0,min(1,value))
    if action=='select':
        request['source']=sys.argv[2]
        if not request['source'] or len(request['source'])>200:raise ValueError('Invalid device')
    if action=='room-control':
        request['control']=sys.argv[2]
        if request['control'] not in ['play','pause','next','previous','volume','seek']:raise ValueError('Invalid control')
        if request['control'] in ['volume','seek']:request['value']=float(sys.argv[3])
    code=(VOLUME_REMOTE if action=='room-volume' else REMOTE).replace('REQUEST',repr(request),1)
    timeout=10 if action=='room-volume' else (20 if action=='status' else 90)
    result=subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=3','ash','python3','-'],input=code,text=True,capture_output=True,timeout=timeout)
    if result.returncode:raise RuntimeError('Spotify connection unavailable')
    data=json.loads(result.stdout)
    print(json.dumps(data))

if __name__=='__main__':
    try:main()
    except Exception:print(json.dumps({'ok':False,'error':'Could not reach Spotify on ash. Retry when connected.'}))
