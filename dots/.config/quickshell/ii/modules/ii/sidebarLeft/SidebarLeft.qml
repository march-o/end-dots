import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    PanelWindow {
        id: popupWindow
        visible: GlobalStates.sidebarLeftOpen
        anchors { top: true; bottom: true; left: true; right: true }
        implicitWidth: screen?.width ?? 1920
        implicitHeight: screen?.height ?? 1080
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:sidebarLeft"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        color: "transparent"

        function hide() { GlobalStates.sidebarLeftOpen = false }

        onVisibleChanged: {
            if (visible) GlobalFocusGrab.addDismissable(popupWindow)
            else GlobalFocusGrab.removeDismissable(popupWindow)
        }
        Connections {
            target: GlobalFocusGrab
            function onDismissed() { popupWindow.hide() }
        }

        Rectangle {
            anchors.fill: parent
            color: "#99000000"
            MouseArea {
                anchors.fill: parent
                onClicked: popupWindow.hide()
            }
        }

        StyledRectangularShadow {
            target: popup
            radius: popup.radius
        }
        Rectangle {
            id: popup
            anchors.centerIn: parent
            width: Math.min(parent.width - 64, 1180)
            height: Math.min(parent.height - 96, 900)
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer0
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
            focus: true

            MouseArea {
                anchors.fill: parent
                onClicked: mouse => mouse.accepted = true
            }
            SidebarLeftContent {
                anchors.fill: parent
                scopeRoot: root
            }

            Keys.onEscapePressed: popupWindow.hide()
        }
    }

    IpcHandler {
        target: "sidebarLeft"
        function toggle(): void { GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen }
        function close(): void { GlobalStates.sidebarLeftOpen = false }
        function open(): void { GlobalStates.sidebarLeftOpen = true }
    }

    GlobalShortcut {
        name: "sidebarLeftToggle"
        description: "Toggles the AI popup on press"
        onPressed: GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen
    }
    GlobalShortcut {
        name: "sidebarLeftOpen"
        description: "Opens the AI popup on press"
        onPressed: GlobalStates.sidebarLeftOpen = true
    }
    GlobalShortcut {
        name: "sidebarLeftClose"
        description: "Closes the AI popup on press"
        onPressed: GlobalStates.sidebarLeftOpen = false
    }
}
