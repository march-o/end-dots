import QtQuick
import qs.modules.common
import qs.modules.common.functions

Item {
    id: root
    property bool vertical: false
    property bool available: false
    property real value: 0
    property var statePalette: BarGlassPalette.buttonColors(BarGlassPalette.dominant)
    signal moved(real volume)
    implicitWidth: vertical ? 36 : 144
    implicitHeight: vertical ? 160 : 30
    function update(mouse) {
        if (available) moved(Math.max(0, Math.min(1, vertical
            ? 1 - (mouse.y - 8) / (height - 16)
            : (mouse.x - 8) / (width - 16))))
    }
    Rectangle {
        id: track
        anchors.centerIn: parent
        width: root.vertical ? 5 : root.width - 16
        height: root.vertical ? root.height - 16 : 5
        radius: 2.5
        color: ColorUtils.applyAlpha(root.statePalette.off, 0.22)
        Rectangle {
            anchors.bottom: root.vertical ? parent.bottom : undefined
            width: root.vertical ? parent.width : parent.width * root.value
            height: root.vertical ? parent.height * root.value : parent.height
            radius: parent.radius
            color: volumeMouse.containsMouse ? root.statePalette.onHover : root.statePalette.on
        }
    }
    Rectangle {
        x: root.vertical ? (root.width - width) / 2 : 8 + (root.width - 16) * root.value - width / 2
        y: root.vertical ? 8 + (root.height - 16) * (1 - root.value) - height / 2 : (root.height - height) / 2
        width: root.vertical ? (volumeMouse.pressed ? 22 : 18) : 3
        height: root.vertical ? 3 : (volumeMouse.pressed ? 22 : 18)
        radius: 1.5
        color: volumeMouse.containsMouse ? root.statePalette.onHover : root.statePalette.on
    }
    MouseArea {
        id: volumeMouse
        anchors.fill: parent
        enabled: root.available
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.update(mouse)
        onPositionChanged: mouse => { if (pressed) root.update(mouse) }
        onWheel: wheel => { root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.04 : -0.04)))); wheel.accepted = true }
    }
}
