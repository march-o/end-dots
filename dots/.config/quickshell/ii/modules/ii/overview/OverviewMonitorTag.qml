pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.bar

RowLayout {
    id: root
    property string monitorName: ""
    property bool current: false
    property bool expanded: false
    readonly property var displays: HyprlandData.monitors.slice().sort((a, b) => a.id - b.id)
    readonly property int displayIndex: displays.findIndex(m => m.name === root.monitorName)
    readonly property bool isLaptop: HyprlandData.isLaptopMonitor(monitorName)
    readonly property string referenceMonitorName: HyprlandData.focusedMonitorName
        || HyprlandData.monitors.find(m => m.focused)?.name || ""
    readonly property color monitorColor: GlassColors.monitorColor(monitorName === referenceMonitorName)
    visible: displayIndex >= 0
    spacing: 4
    MonitorIcon {
        monitorName: root.monitorName
        iconSize: 15
        color: root.monitorColor
    }
    StyledText {
        text: root.expanded ? Translation.tr(root.isLaptop ? "Laptop" : "Display") + " " + (root.displayIndex + 1) + " · " + root.monitorName
            : String(root.displayIndex + 1)
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: root.current ? Font.DemiBold : Font.Normal
        color: BarGlassPalette.islandColor([root.monitorColor], GlassColors.surface, 4.5)
    }
    Rectangle {
        visible: root.current && !root.expanded
        width: 4; height: 4; radius: 2
        color: root.monitorColor
    }
}
