import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.modules.common

// Operates only on CI's private Sway seat and the actual full-shell stats island.
Scope {
    id: root
    property bool done: false
    property string failure: ""
    property bool capturing: false
    property string artifactPrefix: ""
    property int step: 0
    property var widget: null
    property var window: null
    property real startingHeight: 0
    property real startingZone: 0
    property real readyHeight: 0
    property real compactBottom: 0
    property int startingGrabs: GlobalFocusGrab.dismissable.length
    property bool openingCaptured: false
    property bool closingCaptured: false
    function require(condition, message) {
        if (!condition) { failure = "step " + step + ": " + message; done = true; steps.stop(); }
    }
    function findStats(item) {
        if (item.objectName === "systemStats") return item;
        for (const child of item.children ?? []) { const found = findStats(child); if (found) return found; }
        return null;
    }
    function capture(name) {
        capturing = true;
        widget.parent.grabToImage(result => {
            if (!result.saveToFile("/work/artifacts/" + artifactPrefix + name + ".png")) {
                failure = "Could not capture " + name; done = true;
            }
            capturing = false;
        });
    }
    function movePointer(x, y) {
        require(!pointer.running, "Pointer operation overlapped");
        pointer.command = ["swaymsg", "-s", Quickshell.env("SWAYSOCK"), "seat", "seat0", "cursor", "set", String(Math.round(x)), String(Math.round(y))];
        pointer.running = true;
    }
    function pointInWidget(x, y) {
        const point = widget.mapToItem(window.contentItem, x, y);
        movePointer(point.x, point.y + (Config.options.bar.bottom ? window.screen.height - window.height : 0));
    }
    function leave() { movePointer(window.screen.width - 2, window.screen.height / 2); }
    function checkExpanded() {
        require(widget.expanded && widget.expansionProgress > .999 && !!widget.expandedContent, "Stats island did not expand: " + JSON.stringify({ expanded: widget.expanded, progress: widget.expansionProgress, loaded: !!widget.expandedContent, pointer: widget.containsMouse, bottom: Config.options.bar.bottom }));
        if (!widget.expandedContent) return;
        require(widget.QsWindow.window === widget.expandedContent.QsWindow.window, "Stats appeared in a separate native window");
        require(window.height === startingHeight && window.exclusiveZone === startingZone, "Expansion changed the native surface or application reservation");
        require(GlobalFocusGrab.dismissable.length === startingGrabs && window.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None, "Passive expansion grabbed focus");
        require(widget.height <= widget.expandedContent.implicitHeight + 1, "Expanded stats retains empty height");
    }
    function checkCollapsed() {
        require(!widget.presented && !widget.expandedContent && widget.height <= Appearance.sizes.baseBarHeight + 1, "Stats did not collapse and unload");
        require(!SystemStats.remoteRequested, "Ash sampler remained active after collapse");
        require(window.height === startingHeight && window.exclusiveZone === startingZone, "Collapse changed native geometry");
    }
    Process {
        id: pointer
        stdout: StdioCollector {}
        onExited: (code, status) => root.require(code === 0, "Private Sway pointer command failed")
    }
    Timer { id: reverse; interval: 90; onTriggered: root.widget.openCard() }
    FrameAnimation {
        running: !!root.widget && !root.done
        onTriggered: {
            const progress = root.widget.expansionProgress;
            if (!root.capturing && progress > .2 && progress < .8) {
                if (root.widget.expanded && !root.openingCaptured) { root.openingCaptured = true; root.capture("stats-morph-opening"); }
                else if (!root.widget.expanded && !root.closingCaptured) { root.closingCaptured = true; root.capture("stats-morph-closing"); }
            }
        }
    }
    Timer {
        id: steps
        interval: 300
        repeat: true
        running: true
        onTriggered: {
            if (root.capturing) return;
            if (root.step === 0) {
                for (const candidate of GlobalFocusGrab.persistent) {
                    const stats = root.findStats(candidate.contentItem);
                    if (stats?.morphEnabled) { root.widget = stats; break; }
                }
                root.require(!!root.widget, "No actual bar stats island found");
                if (!root.widget) return;
                root.window = root.widget.QsWindow.window;
                root.startingHeight = root.window.height;
                root.startingZone = root.window.exclusiveZone;
                root.pointInWidget(root.widget.width / 2, root.widget.height / 2);
            }
            if (root.step === 5) { root.checkExpanded(); root.readyHeight = root.widget.height; }
            if (root.step === 6) root.pointInWidget(root.widget.width / 2, root.widget.height * .8);
            if (root.step === 8) {
                root.checkExpanded();
                root.require(root.widget.containsMouse && root.widget.expandedContent.ready, "Pointer could not enter expanded controls");
                root.capture("stats-local");
            }
            if (root.step === 9) root.pointInWidget(root.widget.width * .75, 24);
            if (root.step === 10) root.widget.expandedContent.ashSelected = true;
            if (root.step === 16) {
                root.require(!!root.widget.expandedContent, "Stats collapsed during device selection");
                if (!root.widget.expandedContent) return;
                root.require(!SystemStats.ashOnline && !root.widget.expandedContent.ready, "Offline Ash still shows live data");
                root.require(root.widget.height < root.readyHeight, "Offline stats retained unused height");
                root.capture("stats-ash-offline");
            }
            if (root.step === 17) SystemStats.accept(JSON.stringify(Object.assign({}, SystemStats.local, { hostname: "ash-test-fixture" })), true);
            if (root.step === 19) {
                root.require(SystemStats.ashOnline && root.widget.expandedContent.ready, "Ash data did not render");
                root.capture("stats-ash");
            }
            if (root.step === 20) root.leave();
            if (root.step === 23) {
                root.checkCollapsed();
                // Former expanded bounds must pass through and must not reopen.
                root.pointInWidget(root.widget.width / 2, 180);
            }
            if (root.step === 26) { root.checkCollapsed(); root.widget.openCard(); }
            if (root.step === 28) { root.widget.dismiss(); reverse.restart(); }
            if (root.step === 31) { root.checkExpanded(); root.widget.dismiss(); }
            if (root.step === 34) { root.checkCollapsed(); Config.options.bar.bottom = true; }
            if (root.step === 35) {
                const point = root.widget.mapToItem(root.window.contentItem, 0, root.widget.height);
                root.compactBottom = point.y;
                root.pointInWidget(root.widget.width / 2, root.widget.height / 2);
            }
            if (root.step === 40) {
                root.checkExpanded();
                const point = root.widget.mapToItem(root.window.contentItem, 0, root.widget.height);
                root.require(Math.abs(point.y - root.compactBottom) < 1, "Bottom expansion moved its attached edge");
                root.capture("stats-bottom-expanded");
            }
            if (root.step === 41) root.leave();
            if (root.step === 45) { root.checkCollapsed(); Config.options.bar.bottom = false; }
            if (root.step === 47) {
                root.require(root.openingCaptured && root.closingCaptured, "Intermediate morph frames were not rendered");
                root.done = true; steps.stop();
            }
            root.step++;
        }
    }
}
