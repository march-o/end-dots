import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root
    required property Item hoverTarget
    property bool opened: false
    property bool popupHovered: false
    property bool keyboardMode: false
    function dismiss() { opened = false; keyboardMode = false; closeDelay.stop(); }
    function toggle(useKeyboard = false) {
        keyboardMode = useKeyboard;
        if (opened) dismiss(); else { opened = true; closeDelay.stop(); }
    }
    function updateHover() {
        if (keyboardMode && opened) return;
        if (hoverTarget.containsMouse || popupHovered) { closeDelay.stop(); opened = true; }
        else closeDelay.restart();
    }
    Connections {
        target: root.hoverTarget
        function onContainsMouseChanged() { root.updateHover(); }
    }
    onPopupHoveredChanged: updateHover()
    readonly property bool sampling: panel.visible
    property bool samplingRegistered: false
    onSamplingChanged: {
        if (sampling === samplingRegistered) return;
        samplingRegistered = sampling;
        SystemStats.hoverUsers = Math.max(0, SystemStats.hoverUsers + (sampling ? 1 : -1));
    }
    Component.onDestruction: {
        if (samplingRegistered) SystemStats.hoverUsers = Math.max(0, SystemStats.hoverUsers - 1);
        samplingRegistered = false;
    }
    Timer { id: closeDelay; interval: 320; onTriggered: if (!root.hoverTarget.containsMouse && !root.popupHovered) root.opened = false }

    GlassPanelWindow {
        id: panel
        panelName: "systemStats"
        screen: root.QsWindow.window?.screen ?? Quickshell.screens[0]
        shown: root.opened
        dismissOnFocusLoss: root.keyboardMode
        slideFrom: Config.options.bar.bottom ? "bottom" : "top"
        onDismissRequested: root.dismiss()
        WlrLayershell.keyboardFocus: root.keyboardMode && root.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: Math.min(610 * Math.max(1, Config.options.appearance.fontScale), (screen?.width ?? 800) - 16)
        implicitHeight: Math.min(650 * Math.max(1, Config.options.appearance.fontScale), (screen?.height ?? 900) - Appearance.sizes.barHeight - 24)
        anchors.left: !Config.options.bar.vertical || !Config.options.bar.bottom
        anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
        anchors.top: Config.options.bar.vertical || !Config.options.bar.bottom
        anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom
        margins {
            left: Config.options.bar.vertical ? Appearance.sizes.verticalBarWidth + 6 : Math.max(8,
                Math.min((panel.screen?.width ?? 800) - panel.implicitWidth - 8,
                    (root.QsWindow.window?.mapFromItem(root.hoverTarget, root.hoverTarget.width / 2, 0).x ?? 0) - panel.implicitWidth / 2))
            right: Appearance.sizes.verticalBarWidth + 6
            top: Config.options.bar.vertical ? 8 : Appearance.sizes.barHeight + 6
            bottom: Appearance.sizes.barHeight + 6
        }
        Loader {
            anchors.fill: parent
            active: panel.visible
            onLoaded: if (root.keyboardMode) item.forceActiveFocus()
            sourceComponent: SystemStatsContent {
                onHoveredChanged: root.popupHovered = hovered
                Keys.onEscapePressed: root.dismiss()
            }
        }
    }
}
