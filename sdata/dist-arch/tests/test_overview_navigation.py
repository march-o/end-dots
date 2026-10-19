"""Exercise the overview's actual JavaScript navigation without a desktop."""
import json
import re
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[3]
NAVIGATION = ROOT / "dots/.config/quickshell/ii/modules/ii/overview/OverviewNavigation.js"


@unittest.skipUnless(shutil.which("node"), "Node.js is needed to execute the QML helper")
class OverviewNavigationTest(unittest.TestCase):
    def evaluate(self, expression):
        source = NAVIGATION.read_text().replace(".pragma library", "")
        return json.loads(subprocess.check_output(
            ["node", "-e", source + "\nconsole.log(JSON.stringify(" + expression + "));"], text=True))

    def test_spatial_navigation_and_vertical_wrap(self):
        self.assertEqual(self.evaluate('[move(0,"up",5,3,4), move(8,"down",5,3,4),'
            'move(5,"left",5,3,4), move(4,"left",5,3,4)]'), [8, 0, 4, 4])

    def test_grid_to_hidden_list_and_back(self):
        self.assertEqual(self.evaluate('[move(3,"right",5,3,4), move(7,"right",5,3,4),'
            'move(11,"right",5,3,4), move(12,"left",5,3,4), move(14,"left",5,3,4),'
            'move(16,"left",5,3,4)]'), [12, 14, 16, 3, 7, 11])

    def test_hidden_list_wrap(self):
        self.assertEqual(self.evaluate('[move(12,"up",5,3,4),move(16,"down",5,3,4)]'), [16, 12])

    def test_no_hidden_workspaces(self):
        self.assertEqual(self.evaluate('[move(3,"right",0,3,4), move(11,"next",0,3,4),'
            'move(0,"previous",0,3,4)]'), [3, 0, 11])

    def test_all_sessions_reachable_even_with_long_hidden_list(self):
        self.assertTrue(self.evaluate('(() => { for (const hidden of [0,1,2,5,30]) {'
            'const seen = new Set(); let i = 0; for (let n=0;n<12+hidden;n++) {'
            'seen.add(i); i=move(i,"next",hidden,3,4); }'
            'if (seen.size !== 12+hidden || i !== 0) return false;'
            'for (const start of seen) for (const d of ["left","right","up","down"]) {'
            'const next=move(start,d,hidden,3,4); if(next<0 || next>=12+hidden) return false; }'
            '} return true; })()'))

    def test_stale_selection_is_clamped_after_removal(self):
        self.assertEqual(self.evaluate('move(40,"next",2,3,4)'), 0)

    def test_human_names(self):
        self.assertEqual(self.evaluate('["special:spotify","special:ash-piper-setup",'
            '"special:special"].map(displayName)'), ["Spotify", "Ash Piper Setup", "Scratchpad"])


    def activate(self, function, argument, monitors, workspaces):
        qml = NAVIGATION.with_name("OverviewContent.qml").read_text()
        body = re.search(r"    function " + function + r"\((.*?)\) \{(.*?)^    \}", qml, re.S | re.M)
        source = "const commands=[]; const Hyprland={dispatch:c=>commands.push(c)}; const GlobalStates={};"
        source += "const HyprlandData=" + json.dumps({"monitors": monitors, "workspaceById": {w["id"]: w for w in workspaces}}) + ";"
        source += "const hiddenWorkspaces=" + json.dumps(workspaces) + "; const root={monitor:HyprlandData.monitors[0]};"
        source += "function activate(" + body[1] + "){" + body[2] + "}; activate(" + json.dumps(argument) + "); console.log(JSON.stringify(commands));"
        return json.loads(subprocess.check_output(["node", "-e", source], text=True))

    def test_visible_hidden_workspace_focuses_its_display_without_toggling(self):
        result = self.activate("activateHidden", "special:spotify", [
            {"name": "DP-1"}, {"name": "sunshine", "specialWorkspace": {"name": "special:spotify"}}],
            [{"id": -98, "name": "special:spotify", "monitor": "sunshine"}])
        self.assertEqual(result, ['hl.dsp.focus({ monitor = "sunshine" })'])

    def test_hidden_workspace_opens_on_assigned_display(self):
        result = self.activate("activateHidden", "special:spotify", [{"name": "DP-1"}, {"name": "sunshine"}],
            [{"id": -98, "name": "special:spotify", "monitor": "sunshine"}])
        self.assertEqual(result, ['hl.dsp.focus({ monitor = "sunshine" })', 'hl.dsp.workspace.toggle_special("spotify")'])

    def test_numbered_workspace_dismisses_special_on_target_display(self):
        result = self.activate("activateWorkspace", 12, [
            {"name": "DP-1"}, {"name": "sunshine", "specialWorkspace": {"name": "special:spotify"}}],
            [{"id": 12, "monitor": "sunshine"}])
        self.assertEqual(result, ['hl.dsp.focus({ monitor = "sunshine" })',
            'hl.dsp.workspace.toggle_special("spotify")', 'hl.dsp.focus({ workspace = 12 })'])

    def test_monitor_identity_uses_configured_output_and_builtin_laptop_panels(self):
        data = ROOT / "dots/.config/quickshell/ii/services/HyprlandData.qml"
        body = re.search(r"    function isLaptopMonitor\((.*?)\) \{(.*?)^    \}", data.read_text(), re.S | re.M)
        source = 'const root={laptopMonitorOutput:"sunshine"}; function isLaptopMonitor(' + body[1] + '){' + body[2] + '};'
        source += 'const names=["DP-1","sunshine","eDP-1","LVDS-1","HDMI-A-1","custom-laptop"];'
        source += 'const original=names.map(isLaptopMonitor); root.laptopMonitorOutput="custom-laptop";'
        source += 'console.log(JSON.stringify([original,names.map(isLaptopMonitor)]));'
        result = json.loads(subprocess.check_output(["node", "-e", source], text=True))
        self.assertEqual(result, [[False, True, True, True, False, False], [False, False, True, True, False, True]])


if __name__ == "__main__":
    unittest.main()
