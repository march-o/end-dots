pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.bar

RowLayout {
    id: root
    spacing: 12
    property alias searchInput: searchInput
    property string searchingText: ""
    signal keyPressed(var event)
    signal accepted()
    function forceFocus() { searchInput.forceActiveFocus(); }

    MaterialSymbol { text: "search"; iconSize: 26; color: GlassColors.states.off }
    GlassTextField {
        id: searchInput
        Layout.fillWidth: true
        implicitHeight: 46
        text: LauncherSearch.query
        placeholderText: Translation.tr("Search apps, calculate or run a command")
        onTextChanged: if (LauncherSearch.query !== text) LauncherSearch.query = text
        onAccepted: root.accepted()
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: event => {
            root.keyPressed(event);
            if (!event.accepted && event.key === Qt.Key_Tab && LauncherSearch.results.length) {
                text = LauncherSearch.results[0].name;
                event.accepted = true;
            }
        }
    }
    GlassButton {
        content: GlassIcon { text: "image_search" }
        onClicked: {
            GlobalStates.overviewOpen = false;
            Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "search"]);
        }
        property StyledToolTip tooltip: StyledToolTip { text: Translation.tr("Google Lens") }
    }
    GlassButton {
        toggled: SongRec.running
        content: GlassIcon { text: "music_note" }
        onClicked: SongRec.toggleRunning()
        property StyledToolTip tooltip: StyledToolTip { text: Translation.tr("Recognize music") }
    }
}
