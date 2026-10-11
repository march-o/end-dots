import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

GlassButton {
    id: root
    property bool connected: false
    property bool busy: false
    property string errorText: ""
    readonly property string helper: FileUtils.trimFileProtocol(Directories.home) + "/.local/bin/laptop-monitor"
    toggled: connected
    enabled: !busy
    opacity: 1
    onClicked: {
        if (operation.running) return;
        root.busy = true;
        operation.running = true;
    }
    GlassIcon { text: root.busy ? "sync" : "laptop_mac" }
    property Process operationProcess: Process {
        id: operation
        command: [root.helper, "toggle"]
        onExited: { root.busy = false; root.refresh(); }
    }
    function refresh() { if (!status.running) status.running = true; }
    property Process statusProcess: Process {
        id: status
        command: [root.helper, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.connected = data.active;
                    root.busy = operation.running || data.busy;
                    root.errorText = data.error;
                } catch (e) { root.errorText = "Laptop monitor unavailable"; }
            }
        }
    }
    property Timer statusTimer: Timer { interval: 2000; running: root.visible; repeat: true; onTriggered: root.refresh(); }
    Component.onCompleted: refresh()
    property StyledToolTip hoverTip: StyledToolTip {
        parent: root
        visible: root.hovered
        text: root.errorText || (root.busy ? "Connecting laptop…" : root.connected ? "Disconnect laptop display" : "Use laptop as second display")
    }
}
