pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ColumnLayout {
    id: root
    spacing: 12
    property string searchingText: LauncherSearch.query
    readonly property bool showResults: searchingText !== ""
    property real maximumResultsHeight: 560
    property bool keyboardSelection: false
    signal navigateRequested(string direction)
    signal workspaceAccepted()
    signal dismissRequested()

    function resetDefaultResult() {
        if (root.keyboardSelection) return;
        appResults.currentIndex = appResults.count > 0 ? 0 : -1;
        appResults.positionViewAtBeginning();
    }
    function focusFirstItem() {
        root.keyboardSelection = false;
        // ScriptModel moves the old current item while applying its diff.
        Qt.callLater(root.resetDefaultResult);
    }
    function focusSearchInput() { searchBar.forceFocus(); }
    function setSearchingText(text) {
        searchBar.searchInput.text = text;
        LauncherSearch.query = text;
        focusFirstItem();
    }
    function chooseResult(delta) {
        if (!appResults.count) return;
        root.keyboardSelection = true;
        appResults.currentIndex = appResults.currentIndex < 0 ? (delta < 0 ? appResults.count - 1 : 0)
            : (appResults.currentIndex + delta + appResults.count) % appResults.count;
        appResults.positionViewAtIndex(appResults.currentIndex, ListView.Contain);
    }
    function acceptSelection() {
        if (!root.showResults) root.workspaceAccepted();
        else appResults.currentItem?.clicked();
    }
    function handleKey(event) {
        if (event.key === Qt.Key_Escape) root.dismissRequested();
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.acceptSelection();
        else if (!root.showResults && [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down, Qt.Key_Tab, Qt.Key_Backtab].includes(event.key)) {
            const directions = {};
            directions[Qt.Key_Left] = "left"; directions[Qt.Key_Right] = "right";
            directions[Qt.Key_Up] = "up"; directions[Qt.Key_Down] = "down";
            directions[Qt.Key_Tab] = event.modifiers & Qt.ShiftModifier ? "previous" : "next";
            directions[Qt.Key_Backtab] = "previous";
            root.navigateRequested(directions[event.key]);
        } else if (root.showResults && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
            root.chooseResult(event.key === Qt.Key_Up ? -1 : 1);
        } else return;
        event.accepted = true;
    }

    SearchBar {
        id: searchBar
        Layout.fillWidth: true
        searchingText: root.searchingText
        onKeyPressed: event => root.handleKey(event)
        onAccepted: root.acceptSelection()
    }
    ListView {
        id: appResults
        visible: root.showResults
        Layout.fillWidth: true
        implicitHeight: Math.min(root.maximumResultsHeight, contentHeight)
        clip: true
        spacing: 4
        currentIndex: 0
        model: ScriptModel {
            values: LauncherSearch.results.slice(0, 15)
            objectProp: "key"
            onValuesChanged: Qt.callLater(root.resetDefaultResult)
        }
        onCountChanged: Qt.callLater(root.resetDefaultResult)
        Connections {
            target: LauncherSearch
            function onQueryChanged() { root.focusFirstItem(); }
        }
        delegate: SearchItem {
            required property var modelData
            width: appResults.width
            entry: modelData
            query: StringUtils.cleanOnePrefix(root.searchingText, [Config.options.search.prefix.action,
                Config.options.search.prefix.app, Config.options.search.prefix.clipboard, Config.options.search.prefix.emojis,
                Config.options.search.prefix.math, Config.options.search.prefix.shellCommand, Config.options.search.prefix.webSearch])
            selected: hovered || ListView.isCurrentItem
            Keys.onPressed: event => root.handleKey(event)
        }
    }
}
