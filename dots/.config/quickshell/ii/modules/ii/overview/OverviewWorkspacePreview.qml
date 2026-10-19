pragma ComponentBehavior: Bound
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// A complete workspace thumbnail, including the arrangement of all its windows.
Rectangle {
    id: root
    required property var workspace
    readonly property var monitor: HyprlandData.monitors.find(m => m.name === root.workspace?.monitor) ?? null
    readonly property real monitorScale: Math.max(0.1, monitor?.scale ?? 1)
    readonly property bool rotated: (monitor?.transform ?? 0) % 2 === 1
    readonly property real usableWidth: Math.max(1, ((rotated ? monitor?.height : monitor?.width) ?? 2560)
        - (monitor?.reserved?.[0] ?? 0) - (monitor?.reserved?.[2] ?? 0)) / monitorScale
    readonly property real usableHeight: Math.max(1, ((rotated ? monitor?.width : monitor?.height) ?? 1440)
        - (monitor?.reserved?.[1] ?? 0) - (monitor?.reserved?.[3] ?? 0)) / monitorScale
    readonly property real previewScale: width / usableWidth
    implicitWidth: 140
    implicitHeight: usableHeight * previewScale
    color: "transparent"
    radius: 8
    border.width: 1
    border.color: Qt.alpha(GlassColors.states.off, 0.3)
    clip: true
    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle { width: root.width; height: root.height; radius: root.radius }
    }

    MaterialSymbol {
        anchors.centerIn: parent
        visible: windows.count === 0
        text: "stacks"
        iconSize: 24
        color: GlassColors.states.off
    }
    Repeater {
        id: windows
        model: ScriptModel {
            values: !root.monitor ? [] : ToplevelManager.toplevels.values.filter(toplevel => {
                const window = HyprlandData.windowByAddress[`0x${toplevel.HyprlandToplevel?.address}`];
                return window?.workspace?.id === root.workspace.id
                    && HyprlandData.monitors.some(m => m.id === window.monitor);
            })
        }
        delegate: OverviewWindow {
            required property var modelData
            toplevel: modelData
            windowData: HyprlandData.windowByAddress[`0x${modelData.HyprlandToplevel.address}`]
            monitorData: HyprlandData.monitors.find(m => m.id === windowData?.monitor) ?? null
            widgetMonitor: root.monitor
            scale: root.previewScale
            centerIcons: false
            iconToWindowRatio: 0.18
            iconToWindowRatioCompact: 0.18
            topLeftRadius: 4
            topRightRadius: 4
            bottomLeftRadius: 4
            bottomRightRadius: 4
            z: (windowData?.floating ? 1 : 0) + (windowData?.fullscreen ?? 0) * 2
        }
    }
}
