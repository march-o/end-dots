import QtQuick
import Quickshell
import qs.services
import qs.modules.common

// Drive monitor focus in CI data only; never move the user's pointer or focus.
Scope {
    id: root
    property bool done: false
    property string failure: ""
    property string artifactPrefix: ""
    property int step: 0
    property var strip: null
    property var savedMonitors: []
    property var savedWorkspaces: ({})
    property string savedFocus: ""
    function walk(item, name, result) {
        if (item.objectName === name) result.push(item);
        for (const child of item.children ?? []) walk(child, name, result);
    }
    function require(condition, message) {
        if (!condition) { root.failure = message; root.done = true; steps.stop(); }
    }
    function fixture(focusLaptop, paired) {
        const local = Object.assign({}, root.savedMonitors[0], {
            focused: !focusLaptop, activeWorkspace: { id: 11, name: "11" }
        });
        const remote = Object.assign({}, local, {
            id: 9, name: "sunshine", focused: focusLaptop,
            activeWorkspace: { id: 5, name: "5" }, scale: 1.5
        });
        HyprlandData.monitors = paired ? [local, remote] : [local];
        HyprlandData.focusedMonitorName = focusLaptop && paired ? remote.name : local.name;
        const workspaces = {};
        for (let id = 1; id <= 11; id++)
            workspaces[id] = { id: id, monitor: id === 5 && paired ? remote.name : local.name };
        HyprlandData.workspaceById = workspaces;
    }
    function verify(paired, label) {
        const cells = [];
        walk(root.strip, "workspaceCell", cells);
        root.require(cells.length === Config.options.bar.workspaces.shown, "Missing workspace cells");
        const filled = cells.filter(cell => cell.backgroundTint.a > 0).map(cell => cell.wsId).sort((a,b) => a-b);
        root.require(JSON.stringify(filled) === JSON.stringify(paired ? [5,11] : [11]),
            label + " filled inactive workspaces: " + JSON.stringify(filled));
        root.strip.grabToImage(result => result.saveToFile("/work/artifacts/workspaces-" + label + ".png"));
    }
    Timer {
        id: steps
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            if (root.step === 0) {
                root.savedMonitors = HyprlandData.monitors;
                root.savedWorkspaces = HyprlandData.workspaceById;
                root.savedFocus = HyprlandData.focusedMonitorName;
                const strips = [];
                for (const window of GlobalFocusGrab.persistent) root.walk(window.contentItem, "workspaceStrip", strips);
                root.require(strips.length > 0, "No production workspace strip");
                if (root.done) return;
                root.strip = strips[0];
            }
            const paired = root.step !== 2;
            root.fixture(root.step === 1 || root.step === 3, paired);
            Qt.callLater(() => {
                root.verify(paired, ["desktop-focus", "laptop-focus", "single-display", "reconnected"][root.step]);
                if (root.step++ === 3) { steps.stop(); root.done = true; }
            });
        }
    }
    Component.onDestruction: {
        HyprlandData.monitors = root.savedMonitors;
        HyprlandData.workspaceById = root.savedWorkspaces;
        HyprlandData.focusedMonitorName = root.savedFocus;
        HyprlandData.updateAll();
    }
}
