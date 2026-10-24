import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common.models
import qs.modules.ii.overview

// Real ListView/ScriptModel lifecycle, using harmless result actions in CI only.
Scope {
    id: root
    property bool done: false
    property string failure: ""
    property string artifactPrefix: ""
    property int step: 0
    property var list: null
    property var entries: []
    property string accepted: ""
    function require(condition, message) {
        if (!condition) { failure = "search step " + step + ": " + message; done = true; steps.stop(); }
    }
    Component { id: result; LauncherSearchResult {} }
    PanelWindow {
        visible: true
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusiveZone: 0
        implicitWidth: 760
        implicitHeight: 550
        SearchWidget { id: search; anchors.fill: parent; anchors.margins: 16 }
    }
    Timer {
        id: steps
        interval: 150
        running: true
        repeat: true
        onTriggered: {
            if (root.step === 0) {
                root.list = search.children.find(item => item.currentIndex !== undefined && item.positionViewAtIndex !== undefined);
                root.require(!!root.list, "Actual results ListView not found");
                for (const name of ["Alpha", "Beta", "Fallback", "Delayed"]) {
                    root.entries.push(result.createObject(root, { id: name, name: name, iconType: LauncherSearchResult.IconType.Material, iconName: "apps", execute: () => root.accepted = name }));
                }
                LauncherSearch.query = "a";
                LauncherSearch.results = root.entries.slice(0, 3);
            }
            if (root.step === 3) {
                root.require(root.list.count === 3 && root.list.currentIndex === 0, "First query did not select the best match: " + root.list.currentIndex);
                search.chooseResult(1);
            }
            if (root.step === 4) root.require(root.list.currentIndex === 1, "Arrow navigation did not select the next result");
            if (root.step === 5) {
                // Same count, old first result moves last after queryChanged.
                LauncherSearch.query = "ab";
                LauncherSearch.results = [root.entries[1], root.entries[2], root.entries[0]];
            }
            if (root.step === 8) {
                root.require(root.list.currentIndex === 0, "Query change preserved the old result at index " + root.list.currentIndex);
                if (root.done) return;
                search.acceptSelection();
                root.require(root.accepted === "Beta", "Enter did not activate the first match");
                search.chooseResult(1);
                // A delayed result must not override deliberate keyboard navigation.
                LauncherSearch.results = [root.entries[1], root.entries[2], root.entries[0], root.entries[3]];
            }
            if (root.step === 11) {
                root.require(root.list.currentIndex === 1, "Delayed results overrode keyboard navigation");
                LauncherSearch.query = "abc";
                LauncherSearch.results = [root.entries[0], root.entries[1]];
            }
            if (root.step === 14) {
                root.require(root.list.currentIndex === 0 && root.list.contentY <= 0, "New query did not reset selection and scrolling");
                LauncherSearch.results = [];
            }
            if (root.step === 16) {
                root.require(root.list.currentIndex === -1, "Empty results retained a selection");
                LauncherSearch.results = [root.entries[2], root.entries[1]];
            }
            if (root.step === 19) {
                root.require(root.list.currentIndex === 0, "Results arriving after an empty model did not select first");
                LauncherSearch.query = "";
                root.done = true;
                steps.stop();
            }
            root.step++;
        }
    }
}
