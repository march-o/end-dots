pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland

ButtonMouseArea {
    id: root
    readonly property string screenName: root.QsWindow.window?.screen?.name ?? ""
    WorkspaceModel { id: wsModel; screenName: root.screenName }
    WallpaperIconColor { id: localColors; target: root }
    property bool vertical: Config.options.bar.vertical
    property bool superPressAndHeld: false
    property real workspaceButtonWidth: 32.5
    property real workspaceIconSize: Appearance.font.pixelSize.large * 1.25
    readonly property real barThickness: vertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight
    implicitWidth: vertical ? barThickness : workspaceLayout.implicitWidth
    implicitHeight: vertical ? workspaceLayout.implicitHeight : barThickness
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.BackButton
    property int hoverIndex: Math.floor((vertical ? mouseY : mouseX) / workspaceButtonWidth)

    function switchWorkspaceToHovered() {
        Hyprland.dispatch(`hl.dsp.focus({workspace = ${wsModel.getWorkspaceIdAt(hoverIndex)}})`)
    }
    function toggleSpecial() {
        Hyprland.dispatch('hl.dsp.workspace.toggle_special("special")')
    }
    onPressed: mouse => {
        if (mouse.button === Qt.LeftButton) switchWorkspaceToHovered()
        else if (mouse.button === Qt.RightButton) GlobalStates.overviewOpen = !GlobalStates.overviewOpen
        else if (mouse.button === Qt.BackButton) toggleSpecial()
    }
    onWheel: event => {
        Hyprland.dispatch(`hl.dsp.focus({workspace = "${event.angleDelta.y < 0 ? 'r+1' : 'r-1'}"})`)
    }

    Box {
        id: workspaceLayout
        anchors.centerIn: parent
        vertical: root.vertical
        rowSpacing: 0
        columnSpacing: 0
        opacity: wsModel.specialWorkspaceActive && !root.containsMouse ? 0.25 : 1
        Repeater {
            model: wsModel.shownCount
            delegate: Item {
                id: workspace
                required property int index
                readonly property int wsId: wsModel.getWorkspaceIdAt(index)
                readonly property bool active: wsId === wsModel.activeWorkspace
                readonly property bool occupied: !!wsModel.occupied[index] && wsId !== wsModel.fakeWorkspace
                readonly property var biggestWindow: wsModel.biggestWindow[index]
                readonly property bool hovered: root.containsMouse && root.hoverIndex === index
                readonly property bool showingNumber: root.superPressAndHeld ||
                    (Config.options.bar.workspaces.alwaysShowNumbers &&
                     (!Config.options.bar.workspaces.showAppIcons || !biggestWindow))
                readonly property bool showingApp: !showingNumber && !!biggestWindow && Config.options.bar.workspaces.showAppIcons
                property color iconColor: active
                    ? (hovered ? localColors.statePalette.onHover : localColors.statePalette.on)
                    : (hovered ? localColors.statePalette.offHover : localColors.statePalette.off)
                property color textColor: active
                    ? (hovered ? localColors.textStatePalette.onHover : localColors.textStatePalette.on)
                    : (hovered ? localColors.textStatePalette.offHover : localColors.textStatePalette.off)
                implicitWidth: root.vertical ? root.barThickness : root.workspaceButtonWidth
                implicitHeight: root.vertical ? root.workspaceButtonWidth : root.barThickness
                Behavior on iconColor { ColorAnimation { duration: 120 } }
                Behavior on textColor { ColorAnimation { duration: 120 } }

                AppIcon {
                    id: appIcon
                    anchors.centerIn: parent
                    implicitSize: NumberUtils.roundToEven(root.workspaceIconSize)
                    source: Quickshell.iconPath(AppSearch.guessIcon(workspace.biggestWindow?.class), "image-missing")
                    animated: false
                    visible: workspace.showingApp && !Config.options.bar.workspaces.monochromeIcons
                }
                Colorizer {
                    anchors.fill: appIcon
                    source: appIcon
                    visible: workspace.showingApp && Config.options.bar.workspaces.monochromeIcons
                    colorizationColor: workspace.iconColor
                    // Keep app artwork recognizable; a heavy tint and brightness
                    // lift erase the chrome/terminal details at this small size.
                    colorization: 0.2
                    brightness: BarGlassPalette.luminance(localColors.sampledBackground) < 0.4 ? 0.06 : -0.04
                    contrast: 0.15
                    saturation: 0.1
                }
                StyledText {
                    anchors.centerIn: parent
                    visible: workspace.showingNumber
                    text: Config.options.bar.workspaces.numberMap[workspace.wsId - 1] || workspace.wsId
                    color: workspace.textColor
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: workspace.active ? Font.DemiBold : Font.Medium
                    font.family: Config.options.bar.workspaces.useNerdFont ? Appearance.font.family.iconNerd : defaultFont
                }
                Rectangle {
                    anchors.centerIn: parent
                    visible: !workspace.showingNumber && !workspace.showingApp
                    width: workspace.active ? 7 : workspace.occupied ? 6 : 4
                    height: width
                    radius: width / 2
                    color: workspace.iconColor
                }
                Rectangle {
                    // Separate the active state from the artwork's own colors.
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: (root.barThickness - Appearance.sizes.baseBarHeight) / 2 + 6
                    width: 14
                    height: 2
                    radius: 1
                    visible: workspace.active && workspace.showingApp
                    color: workspace.iconColor
                }
            }
        }
    }
    StyledText {
        anchors.centerIn: parent
        visible: wsModel.specialWorkspaceActive && !root.containsMouse
        text: root.vertical ? "S" : wsModel.specialWorkspaceName
        color: localColors.textStatePalette.on
        font.pixelSize: Appearance.font.pixelSize.normal
        font.weight: Font.Medium
    }
    Timer {
        id: superPressAndHeldTimer
        interval: Config.options.bar.autoHide.showWhenPressingSuper.delay ?? 100
        onTriggered: root.superPressAndHeld = true
    }
    Connections {
        target: GlobalStates
        function onSuperDownChanged() {
            if (!Config.options.bar.autoHide.showWhenPressingSuper.enable) return
            if (GlobalStates.superDown) superPressAndHeldTimer.restart()
            else { superPressAndHeldTimer.stop(); root.superPressAndHeld = false }
        }
        function onSuperReleaseMightTriggerChanged() { superPressAndHeldTimer.stop() }
    }
}
