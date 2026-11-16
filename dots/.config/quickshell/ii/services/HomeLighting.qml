pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var presets: []
    property string lastError: ""
    property string selectedPreset: ""
    property string pendingPreset: ""
    readonly property bool busy: command.running
    function refresh() { if (!discovery.running && !busy) discovery.running = true; }
    function select(preset) {
        if (busy || !presets.includes(preset)) return;
        lastError = "";
        pendingPreset = preset;
        command.exec(["python3", Quickshell.shellPath("scripts/home-lighting.py"), "select", preset]);
    }
    Process {
        id: discovery
        command: ["python3", Quickshell.shellPath("scripts/home-lighting.py"), "scenes"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (!data.ok || !Array.isArray(data.presets)) throw Error();
                    root.presets = ["__off__"].concat(data.presets);
                    if (!command.running) root.lastError = "";
                } catch (e) { root.lastError = "Home lighting unavailable. Click to reconnect."; }
            }
        }
    }
    Process {
        id: command
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (!data.ok) throw Error(data.error);
                    // Acknowledged dispatch is not an observed active scene.
                    root.selectedPreset = root.pendingPreset;
                } catch (e) {
                    root.lastError = "Could not confirm the lighting change.";
                    Quickshell.execDetached(["notify-send", "Home lighting", root.lastError]);
                }
            }
        }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.refresh() }
}
