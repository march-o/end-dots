pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: root
    property string monitorName: ""
    property bool current: false
    property bool expanded: false
    readonly property var displays: HyprlandData.monitors.slice().sort((a, b) => a.id - b.id)
    readonly property int displayIndex: displays.findIndex(m => m.name === root.monitorName)
    visible: displayIndex >= 0
    spacing: 4
    MaterialSymbol {
        text: "desktop_windows"
        iconSize: 15
        color: root.current ? GlassColors.states.on : GlassColors.states.off
    }
    StyledText {
        text: root.expanded ? Translation.tr("Display") + " " + (root.displayIndex + 1) + " · " + root.monitorName
            : String(root.displayIndex + 1)
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: root.current ? Font.DemiBold : Font.Normal
        color: root.current ? GlassColors.textStates.on : GlassColors.textStates.off
    }
    Rectangle {
        visible: root.current && !root.expanded
        width: 4; height: 4; radius: 2
        color: GlassColors.states.on
    }
}
