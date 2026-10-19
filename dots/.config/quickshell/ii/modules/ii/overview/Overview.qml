import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt.labs.synchronizer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false

    GlassPanelWindow {
        id: panelWindow
        panelName: "overview"
        screen: Quickshell.screens.find(s => s.name === HyprlandData.monitors.find(m => m.focused)?.name)
            ?? Quickshell.screens[0]
        shown: GlobalStates.overviewOpen
        slideFrom: "top"
        anchors.top: true
        margins.top: 56
        implicitWidth: Math.min(1360, (screen?.width ?? 1440) - 48)
        implicitHeight: contentLoader.item?.implicitHeight ?? 600
        onDismissRequested: GlobalStates.overviewOpen = false

        function setSearchingText(text) {
            LauncherSearch.query = text;
            contentLoader.item?.setSearchingText(text);
        }

        Connections {
            target: GlobalStates
            function onOverviewOpenChanged() {
                if (GlobalStates.overviewOpen) {
                    if (!overviewScope.dontAutoCancelSearch) LauncherSearch.query = "";
                    contentLoader.item?.resetSelection();
                    Qt.callLater(() => contentLoader.item?.focusSearchInput());
                } else {
                    GlobalStates.superReleaseMightTrigger = false;
                    overviewScope.dontAutoCancelSearch = false;
                }
            }
        }

        Loader {
            id: contentLoader
            anchors.fill: parent
            active: panelWindow.visible
            sourceComponent: OverviewContent { screen: panelWindow.screen }
        }
    }

    function toggleClipboard() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.clipboard);
        GlobalStates.overviewOpen = true;
    }

    function toggleEmojis() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.emojis);
        GlobalStates.overviewOpen = true;
    }

    IpcHandler {
        target: "search"

        function toggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function workspacesToggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            GlobalStates.overviewOpen = true;
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle() {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "overviewNavigateLeft"
        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
            if (GlobalStates.overviewOpen) contentLoader.item?.navigate("left");
        }
    }
    GlobalShortcut {
        name: "overviewNavigateRight"
        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
            if (GlobalStates.overviewOpen) contentLoader.item?.navigate("right");
        }
    }
    GlobalShortcut {
        name: "overviewNavigateUp"
        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
            if (GlobalStates.overviewOpen) contentLoader.item?.navigate("up");
        }
    }
    GlobalShortcut {
        name: "overviewNavigateDown"
        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
            if (GlobalStates.overviewOpen) contentLoader.item?.navigate("down");
        }
    }
    GlobalShortcut {
        name: "overviewActivate"
        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
            contentLoader.item?.acceptSelection();
        }
    }
    GlobalShortcut {
        name: "searchToggle"
        description: "Toggles search on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes overview on press"

        onPressed: {
            GlobalStates.overviewOpen = false;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles overview on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "searchToggleRelease"
        description: "Toggles search on release"

        onPressed: {
            GlobalStates.superReleaseMightTrigger = true;
        }

        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Interrupts possibility of search being toggled on release. " + "This is necessary because GlobalShortcut.onReleased in quickshell triggers whether or not you press something else while holding the key. " + "To make sure this works consistently, use binditn = MODKEYS, catchall in an automatically triggered submap that includes everything."

        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
        }
    }
    GlobalShortcut {
        name: "overviewClipboardToggle"
        description: "Toggle clipboard query on overview widget"

        onPressed: {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "overviewEmojiToggle"
        description: "Toggle emoji query on overview widget"

        onPressed: {
            overviewScope.toggleEmojis();
        }
    }
}
