pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Provides access to some Hyprland data not available in Quickshell.Hyprland.
 */
Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var layers: ({})
    property string focusedMonitorName: ""
    property int workspaceRevision: 0

    // Apply compositor events immediately; CLI snapshots remain the resume fallback.
    function handleEvent(name, data) {
        const parts = data.split(",");
        let monitorName = root.focusedMonitorName || root.monitors.find(m => m.focused)?.name;
        if (name === "focusedmonv2") {
            monitorName = parts[0];
            root.focusedMonitorName = monitorName;
        }
        if (name === "workspacev2" || name === "focusedmonv2") {
            const id = Number(parts[name === "workspacev2" ? 0 : 1]);
            if (Number.isFinite(id) && id > 0 && monitorName) {
                root.workspaceRevision++;
                const workspace = { id: id, name: name === "workspacev2" ? parts.slice(1).join(",") : String(id) };
                root.activeWorkspace = workspace;
                root.monitors = root.monitors.map(m => m.name === monitorName
                    ? Object.assign({}, m, { activeWorkspace: workspace }) : m);
            }
        } else if (name === "activespecialv2") {
            root.workspaceRevision++;
            const special = { id: Number(parts[0]) || 0, name: parts[1] || "" };
            root.monitors = root.monitors.map(m => m.name === parts[2]
                ? Object.assign({}, m, { specialWorkspace: special }) : m);
        }
        if (!["openlayer", "closelayer", "screencast", "screencastv2"].includes(name)) refreshEvents.restart();
    }

    // Convenient stuff

    function toplevelsForWorkspace(workspace) {
        return ToplevelManager.toplevels.values.filter(toplevel => {
            const address = `0x${toplevel.HyprlandToplevel?.address}`;
            var win = HyprlandData.windowByAddress[address];
            return win?.workspace?.id === workspace;
        })
    }

    function hyprlandClientsForWorkspace(workspace) {
        return root.windowList.filter(win => win.workspace.id === workspace);
    }

    function clientForToplevel(toplevel) {
        if (!toplevel || !toplevel.HyprlandToplevel) {
            return null;
        }
        const address = `0x${toplevel?.HyprlandToplevel?.address}`;
        return root.windowByAddress[address];
    }

    // Internals

    function updateWindowList() {
        getClients.running = true;
    }

    function updateLayers() {
        getLayers.running = true;
    }

    function updateMonitors() {
        if (getMonitors.running) return;
        getMonitors.requestRevision = root.workspaceRevision;
        getMonitors.running = true;
    }

    function updateWorkspaces() {
        getWorkspaces.running = true;

    }

    function updateAll() {
        updateWindowList();
        updateMonitors();
        updateLayers();
        updateWorkspaces();
    }

    function biggestWindowForWorkspace(workspaceId) {
        const windowsInThisWorkspace = HyprlandData.windowList.filter(w => w.workspace.id == workspaceId);
        return windowsInThisWorkspace.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
            return winArea > maxArea ? win : maxWin;
        }, null);
    }

    Component.onCompleted: {
        updateAll();
    }

    // Quickshell can miss Hyprland events after the compositor or screen resumes.
    // Refresh the workspace state so the bar keeps tracking the active workspace.
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            root.updateMonitors();
            root.updateWorkspaces();
            root.updateWindowList();
        }
    }

    Socket {
        id: workspaceEvents
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr/" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "/.socket2.sock"
        connected: true
        parser: SplitParser {
            onRead: line => {
                const separator = line.indexOf(">>");
                if (separator >= 0) root.handleEvent(line.slice(0, separator), line.slice(separator + 2));
            }
        }
    }
    Timer {
        interval: 1000
        running: !workspaceEvents.connected
        repeat: true
        onTriggered: workspaceEvents.connected = true
    }
    Timer {
        id: refreshEvents
        interval: 25
        onTriggered: root.updateAll()
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                root.windowList = JSON.parse(clientsCollector.text)
                let tempWinByAddress = {};
                for (var i = 0; i < root.windowList.length; ++i) {
                    var win = root.windowList[i];
                    tempWinByAddress[win.address] = win;
                }
                root.windowByAddress = tempWinByAddress;
                root.addresses = root.windowList.map(win => win.address);
            }
        }
    }

    Process {
        id: getMonitors
        property int requestRevision: 0
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                // Discard a snapshot started before a newer workspace event.
                if (getMonitors.requestRevision !== root.workspaceRevision) return;
                root.monitors = JSON.parse(monitorsCollector.text);
                const focused = root.monitors.find(m => m.focused);
                if (focused) {
                    root.focusedMonitorName = focused.name;
                    root.activeWorkspace = focused.activeWorkspace;
                }
            }
        }
    }

    Process {
        id: getLayers
        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            id: layersCollector
            onStreamFinished: {
                root.layers = JSON.parse(layersCollector.text);
            }
        }
    }

    Process {
        id: getWorkspaces
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            id: workspacesCollector
            onStreamFinished: {
                var rawWorkspaces = JSON.parse(workspacesCollector.text);
                // Filter out invalid workspace ids (e.g. lock-screen temp workspace 2147483647 - N)
                root.workspaces = rawWorkspaces.filter(ws => ws.id >= 1 && ws.id <= 100);
                let tempWorkspaceById = {};
                for (var i = 0; i < root.workspaces.length; ++i) {
                    var ws = root.workspaces[i];
                    tempWorkspaceById[ws.id] = ws;
                }
                root.workspaceById = tempWorkspaceById;
                root.workspaceIds = root.workspaces.map(ws => ws.id);
            }
        }
    }

}
