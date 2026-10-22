pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var local: ({})
    property var ash: ({})
    property int hoverUsers: 0
    readonly property bool remoteRequested: hoverUsers > 0
    property string remoteState: "idle"
    property double ashReceivedAt: 0
    property double clock: Date.now()
    readonly property bool ashOnline: remoteRequested && remoteState === "online" && clock - ashReceivedAt < 12000
    property var localCpuHistory: []
    property var localMemoryHistory: []
    property var ashCpuHistory: []
    property var ashMemoryHistory: []
    property var localReceiveHistory: []
    property var localSendHistory: []
    property var ashReceiveHistory: []
    property var ashSendHistory: []

    function append(history, value) { return history.concat([value]).slice(-40); }
    function accept(line, remote) {
        try {
            const data = JSON.parse(line);
            if (!data.memory || !data.network || !Array.isArray(data.cores)) return;
            const ram = data.memory.total > 0 ? data.memory.used / data.memory.total : 0;
            if (remote) {
                ash = data;
                ashReceivedAt = Date.now();
                remoteState = "online";
                if (data.cpu !== null) ashCpuHistory = append(ashCpuHistory, data.cpu);
                ashMemoryHistory = append(ashMemoryHistory, ram);
                if (data.network.ready) {
                    ashReceiveHistory = append(ashReceiveHistory, data.network.received);
                    ashSendHistory = append(ashSendHistory, data.network.sent);
                }
            } else {
                local = data;
                if (data.cpu !== null) localCpuHistory = append(localCpuHistory, data.cpu);
                localMemoryHistory = append(localMemoryHistory, ram);
                if (data.network.ready) {
                    localReceiveHistory = append(localReceiveHistory, data.network.received);
                    localSendHistory = append(localSendHistory, data.network.sent);
                }
            }
        } catch (error) { console.warn("System stats: invalid sample"); }
    }
    function bytes(value) {
        if (!Number.isFinite(value)) return "—";
        const labels = ["B", "KiB", "MiB", "GiB", "TiB"];
        const n = value > 0 ? Math.min(4, Math.floor(Math.log(value) / Math.log(1024))) : 0;
        return (value / Math.pow(1024, n)).toFixed(n > 1 ? 1 : 0) + " " + labels[n];
    }
    function percent(value) { return Number.isFinite(value) ? Math.round(value * 100) + "%" : "—"; }
    onRemoteRequestedChanged: {
        if (remoteRequested) {
            remoteState = "connecting";
            ashCpuHistory = []; ashMemoryHistory = [];
            ashReceiveHistory = []; ashSendHistory = [];
        } else { remoteState = "idle"; remoteRetry.stop(); }
    }
    Process {
        command: ["python3", "-u", Quickshell.shellPath("scripts/system-stats.py")]
        running: !localRetry.running
        stdout: SplitParser { onRead: data => root.accept(data, false) }
        onExited: localRetry.restart()
        id: localProcess
    }
    Timer { id: localRetry; interval: 5000 }
    Process {
        id: remoteProcess
        command: ["python3", "-u", Quickshell.shellPath("scripts/system-stats.py"), "--host", "ash", "--interval", "3"]
        running: root.remoteRequested && !remoteRetry.running
        stdout: SplitParser { onRead: data => root.accept(data, true) }
        stderr: StdioCollector {}
        onExited: {
            if (root.remoteRequested) { root.remoteState = "offline"; remoteRetry.restart(); }
        }
    }
    Timer { id: remoteRetry; interval: 10000; onTriggered: if (root.remoteRequested) root.remoteState = "connecting" }
    Timer { interval: 1000; running: root.remoteRequested; repeat: true; onTriggered: root.clock = Date.now() }
}
