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
        // External volume need not be on the grid: move to the next rib in the requested direction.
        const scaled = boundedValue * segmentCount;
        const next = direction > 0 ? Math.floor(scaled + 0.000001) + 1 : Math.ceil(scaled - 0.000001) - 1;
        moved(Math.max(0, Math.min(segmentCount, next)) / segmentCount);
    }
    Item {
        id: track
        objectName: "volumeTrack"
        anchors.centerIn: parent
        width: root.vertical ? 10 : root.width - 16
        height: root.vertical ? root.height - 16 : 10
        // One continuous hairline; ribs mark every selectable level, including both endpoints.
        Rectangle {
            anchors.centerIn: parent
            width: root.vertical ? 1 : parent.width
            height: root.vertical ? parent.height : 1
            color: ColorUtils.applyAlpha(root.statePalette.off, 0.38)
        }
        Rectangle {
            x: root.vertical ? (parent.width - width) / 2 : 0
            y: root.vertical ? parent.height * (1 - root.boundedValue) : (parent.height - height) / 2
            width: root.vertical ? 1 : parent.width * root.boundedValue
            height: root.vertical ? parent.height * root.boundedValue : 1
            color: indicator.color
        }
        Repeater {
            model: root.segmentCount + 1
            delegate: Rectangle {
                required property int index
                objectName: "volumeRib" + index
                readonly property real level: index / root.segmentCount
                x: root.vertical ? 0 : level * track.width - width / 2
                y: root.vertical ? (1 - level) * track.height - height / 2 : 0
                width: root.vertical ? track.width : 1
                height: root.vertical ? 1 : track.height
                radius: 0.5
                color: ColorUtils.applyAlpha(root.statePalette.off, 0.5)
            }
        }
    }
    Rectangle {
        id: indicator
        objectName: "volumeIndicator"
        x: root.vertical ? (root.width - width) / 2 : 8 + (root.width - 16) * root.boundedValue - width / 2
        y: root.vertical ? 8 + (root.height - 16) * (1 - root.boundedValue) - height / 2 : (root.height - height) / 2
        width: root.vertical ? (volumeMouse.pressed ? 20 : 16) : 2
        height: root.vertical ? 2 : (volumeMouse.pressed ? 20 : 16)
        radius: 1
        color: root.available ? (volumeMouse.containsMouse ? root.statePalette.onHover : root.statePalette.on) : root.statePalette.off
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
