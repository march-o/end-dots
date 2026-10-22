import QtQuick
import Quickshell
import qs.services
import qs.modules.ii.bar

Scope {
    id: root
    property bool done: false
    property string failure: ""
    property bool capturing: false
    property string artifactPrefix: ""
    property int step: 0
    property var details: null
    property var panel: null
    property real readyPanelHeight: 0
    property int startingGrabs: GlobalFocusGrab.dismissable.length
    function require(condition, message) { if (!condition) { failure = message; done = true; steps.stop(); } }
    function findDetails(item) {
        if (item.ashSelected !== undefined) return item;
        for (const child of item.children ?? []) { const found = findDetails(child); if (found) return found; }
        return null;
    }
    function capture(name) {
        require(details !== null, "Stats content was not loaded");
        capturing = true;
        if (details) details.grabToImage(result => {
            if (!result.saveToFile("/work/artifacts/" + artifactPrefix + name + ".png")) { failure = "Could not capture " + name; done = true; }
            capturing = false;
        });
    }
    FloatingWindow {
        visible: false
        Item { id: target; property bool containsMouse: false; width: 284; height: 40 }
        ResourcesPopup { id: popup; hoverTarget: target }
    }
    Timer {
        id: steps
        interval: 300
        repeat: true
        running: true
        onTriggered: {
            if (root.capturing) return;
            if (root.step === 0) target.containsMouse = true;
            if (root.step === 5) {
                root.panel = popup.data.find(item => item.panelName === "systemStats");
                root.require(!!root.panel && root.panel.backingWindowVisible, "Stats native surface did not open");
                if (root.panel) root.details = root.findDetails(root.panel.contentItem);
                root.require(root.details !== null, "Lazy stats content did not load");
                root.require(GlobalFocusGrab.dismissable.length === root.startingGrabs, "Passive hover grabbed focus");
            }
            if (root.step === 10 && root.details) {
                root.require(root.details.ready && !root.details.ashSelected, "Local stats are not ready");
                root.readyPanelHeight = root.panel.height;
                root.require(root.panel.height <= root.details.implicitHeight + 1, "Stats panel reserves empty height below content");
                root.capture("stats-local");
            }
            if (root.step === 11 && root.details) root.details.ashSelected = true;
            if (root.step === 21 && root.details) {
                root.require(!SystemStats.ashOnline && !root.details.ready, "Offline Ash still shows live data");
                root.require(root.panel.height < root.readyPanelHeight, "Offline stats panel retains unused height");
                root.capture("stats-ash-offline");
            }
            if (root.step === 22) {
                const sample = Object.assign({}, SystemStats.local, { hostname: "ash-test-fixture" });
                SystemStats.accept(JSON.stringify(sample), true);
            }
            if (root.step === 24) {
                root.require(SystemStats.ashOnline && root.details.ready, "Ash data did not render");
                root.capture("stats-ash");
            }
            if (root.step === 25) target.containsMouse = false;
            if (root.step === 30) {
                root.require(!popup.opened && !root.panel.backingWindowVisible, "Hover surface did not close");
                root.require(!SystemStats.remoteRequested, "Ash sampling continued after close");
                target.containsMouse = true;
            }
            if (root.step === 34) {
                root.require(popup.opened && root.panel.backingWindowVisible, "Hover surface did not reopen");
                target.containsMouse = false;
            }
            if (root.step === 38) {
                root.require(!SystemStats.remoteRequested, "Ash sampling leaked after reopening");
                root.done = true;
                steps.stop();
            }
            root.step++;
        }
    }
}
