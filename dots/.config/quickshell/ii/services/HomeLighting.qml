pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var presets: []
    property string lastError: ""
    property string lastRequested: ""
    readonly property bool busy: command.running
    function refresh() { if (!discovery.running && !busy) discovery.running = true; }
    function select(preset) {
        if (busy || !presets.includes(preset)) return;
        lastError = "";
        lastRequested = "";
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
                } catch (e) { root.lastError = "Cannot discover Home lighting presets. Click to refresh."; }
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
                    root.lastRequested = "Command accepted; physical state not verified";
                } catch (e) {
                    root.lastError = "Lighting command unconfirmed. No automatic retry.";
                    Quickshell.execDetached(["notify-send", "Home lighting", root.lastError]);
                }
            }
        }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.refresh() }
}
