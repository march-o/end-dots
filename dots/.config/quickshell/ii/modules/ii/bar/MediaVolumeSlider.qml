import QtQuick
import qs.modules.common
import qs.modules.common.functions

Item {
    id: root
    property bool vertical: false
    property bool available: false
    property real value: 0
    property var statePalette: BarGlassPalette.buttonColors(BarGlassPalette.dominant)
    readonly property int segmentCount: 20
    readonly property real boundedValue: Math.max(0, Math.min(1, value))
    signal moved(real volume)
    implicitWidth: vertical ? 36 : 144
    implicitHeight: vertical ? 160 : 30
    function snap(value) {
        return Math.max(0, Math.min(segmentCount, Math.round(value * segmentCount))) / segmentCount;
    }
    function update(mouse) {
        if (available) moved(snap(vertical
            ? 1 - (mouse.y - 8) / Math.max(1, height - 16)
            : (mouse.x - 8) / Math.max(1, width - 16)));
    }
    function step(direction) {
        if (!available || direction === 0) return;
        // External volume need not be on the grid: move to the next step in the requested direction.
        const scaled = boundedValue * segmentCount;
        const next = direction > 0 ? Math.floor(scaled + 0.000001) + 1 : Math.ceil(scaled - 0.000001) - 1;
        moved(Math.max(0, Math.min(segmentCount, next)) / segmentCount);
    }
    Rectangle {
        id: track
        objectName: "volumeTrack"
        anchors.centerIn: parent
        width: root.vertical ? 5 : root.width - 16
        height: root.vertical ? root.height - 16 : 5
        radius: 2.5
        color: ColorUtils.applyAlpha(root.statePalette.off, 0.22)
        Rectangle {
            anchors.bottom: root.vertical ? parent.bottom : undefined
            width: root.vertical ? parent.width : parent.width * root.boundedValue
            height: root.vertical ? parent.height * root.boundedValue : parent.height
            radius: parent.radius
            color: volumeMouse.containsMouse ? root.statePalette.onHover : root.statePalette.on
        }
    }
    Rectangle {
        objectName: "volumeIndicator"
        x: root.vertical ? (root.width - width) / 2 : 8 + (root.width - 16) * root.boundedValue - width / 2
        y: root.vertical ? 8 + (root.height - 16) * (1 - root.boundedValue) - height / 2 : (root.height - height) / 2
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
        onWheel: wheel => { root.step(wheel.angleDelta.y); wheel.accepted = true }
    }
}
