import QtQuick
import qs.modules.common

Rectangle {
    id: root
    property real value: 0
    property color meterColor: GlassColors.monitorMemory
    implicitHeight: 6
    implicitWidth: 100
    color: GlassColors.monitorLine
    Rectangle {
        height: parent.height
        width: Math.max(0, Math.min(1, root.value)) * parent.width
        color: root.meterColor
    }
}
