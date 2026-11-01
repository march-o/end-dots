'''Execute production QML command handlers against slow/failing background reads.'''
import json
from pathlib import Path
import re
import shutil
import subprocess
import unittest

QML=Path(__file__).resolve().parents[3]/'dots/.config/quickshell/ii/modules/ii/bar/Media.qml'

@unittest.skipUnless(shutil.which('node'),'Node is required to execute QML JavaScript handlers')
class MediaLanes(unittest.TestCase):
    def evaluate(self,expression,native=False):
        qml=QML.read_text();methods=[]
        for name in ['controlRoom','drainControls','completeTransport','refreshDevices','selectDevice']:
            match=re.search(r'^    function '+name+r'\((.*?)\) \{(.*?)^    \}',qml,re.M|re.S)
            self.assertIsNotNone(match,name)
            methods.append('function '+name+'('+match[1]+'){'+match[2]+'}\nroot.'+name+'='+name+';')
        setup='''const calls=[];const card={devicesOpen:false};
const root={requestedSource:'',pendingControls:[],pendingDeviceSource:'',pendingDevicesRefresh:false,connectError:''};
const connect={running:true,command:['status']};const transportWrite={running:false,command:[]};
const transport={revision:0,dispatch:(a,v)=>{NATIVE}};
const nativeRefresh={restart:()=>calls.push('refresh')};
const Qt={callLater:f=>f()};const Quickshell={shellPath:p=>p};
'''.replace('NATIVE',"calls.push(a);return true;" if native else 'return false;')
        source=setup+'\n'.join(methods)+'\nconsole.log(JSON.stringify((()=>{'+expression+'})()));'
        return json.loads(subprocess.check_output(['node','-e',source],text=True))

    def test_skip_dispatches_while_status_is_still_running(self):
        result=self.evaluate("controlRoom('next');return [transportWrite.running,transportWrite.command,connect.command,root.requestedSource,card.devicesOpen,root.pendingControls];")
        self.assertTrue(result[0]);self.assertEqual(result[1][-2:],['room-control','next'])
        self.assertEqual(result[2],['status']);self.assertEqual(result[3:],[ '',False,[]])

    def test_failed_transport_does_not_open_device_dialogue(self):
        self.assertEqual(self.evaluate("completeTransport(1,{ok:false,error:'Offline'});return [root.connectError,card.devicesOpen,root.requestedSource];"),['Offline',False,''])

    def test_native_transport_never_waits_for_status_or_starts_remote_worker(self):
        self.assertEqual(self.evaluate("controlRoom('next');return [calls,transportWrite.running,connect.command];",native=True),[['next'],False,['status']])

    def test_rapid_transport_clicks_are_kept_once_in_order(self):
        result=self.evaluate("transportWrite.running=true;controlRoom('next');controlRoom('previous');controlRoom('next');transportWrite.running=false;drainControls();return [transportWrite.command.at(-1),root.pendingControls.map(c=>c.action)];")
        self.assertEqual(result,['next',['previous','next']])

    def test_seek_coalesces_without_dropping_skip_clicks(self):
        result=self.evaluate("transportWrite.running=true;controlRoom('seek',3);controlRoom('next');controlRoom('seek',8);return root.pendingControls;")
        self.assertEqual(result,[{'action':'next'},{'action':'seek','value':8}])

    def test_controls_cannot_change_old_speaker_during_explicit_source_switch(self):
        self.assertEqual(self.evaluate("root.requestedSource='PC';controlRoom('next');return [transportWrite.running,root.pendingControls];"),[False,[]])

    def test_device_selection_is_retained_during_status_poll(self):
        self.assertEqual(self.evaluate("selectDevice('PC');return [root.pendingDeviceSource,transportWrite.running];"),['PC',False])

    def test_opening_device_picker_retains_force_refresh_intent(self):
        self.assertTrue(self.evaluate("refreshDevices(true);return root.pendingDevicesRefresh;"))

if __name__=='__main__':unittest.main()
