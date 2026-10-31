import QtQuick
import Quickshell
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
    // Align in scene/device space, including fractional RowLayout placement.
    readonly property real dpr: QsWindow.window?.devicePixelRatio ?? 1
    property point sceneOrigin: mapToItem(null, 0, 0)
    FrameAnimation {
        running: root.visible
        onTriggered: root.sceneOrigin = root.mapToItem(null, 0, 0)
    }
    readonly property real hairline: 1 / dpr
    function oddPixels(length) { return (2 * Math.floor(length * dpr / 2) + 1) / dpr; }
    function pixelCenter(position, verticalAxis) {
        const origin = verticalAxis ? sceneOrigin.y : sceneOrigin.x;
        return (Math.round((origin + position) * dpr - .5) + .5) / dpr - origin;
    }
    function levelPosition(level) {
        return pixelCenter(8 + ((vertical ? height : width) - 16) * (vertical ? 1 - level : level), vertical);
    }
    readonly property real crossCenter: pixelCenter((vertical ? width : height) / 2, !vertical)
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
        anchors.fill: parent
        // All visible edges land on device pixels; odd-width marks share one center.
        Rectangle {
            x: root.vertical ? root.crossCenter - width / 2 : root.levelPosition(0)
            y: root.vertical ? root.levelPosition(1) : root.crossCenter - height / 2
            width: root.vertical ? root.hairline : root.levelPosition(1) - root.levelPosition(0)
            height: root.vertical ? root.levelPosition(0) - root.levelPosition(1) : root.hairline
            color: ColorUtils.applyAlpha(root.statePalette.off, 0.38)
        }
        Rectangle {
            x: root.vertical ? root.crossCenter - width / 2 : root.levelPosition(0)
            y: root.vertical ? root.levelPosition(root.boundedValue) : root.crossCenter - height / 2
            width: root.vertical ? root.hairline : root.levelPosition(root.boundedValue) - root.levelPosition(0)
            height: root.vertical ? root.levelPosition(0) - root.levelPosition(root.boundedValue) : root.hairline
            color: indicator.color
        }
        Repeater {
            model: root.segmentCount + 1
            delegate: Rectangle {
                required property int index
                objectName: "volumeRib" + index
                readonly property real level: index / root.segmentCount
                x: root.vertical ? root.crossCenter - width / 2 : root.levelPosition(level) - width / 2
                y: root.vertical ? root.levelPosition(level) - height / 2 : root.crossCenter - height / 2
                width: root.vertical ? root.oddPixels(4) : root.hairline
                height: root.vertical ? root.hairline : root.oddPixels(4)
                color: ColorUtils.applyAlpha(root.statePalette.off, 0.5)
            }
        }
    }
    Rectangle {
        id: indicator
        objectName: "volumeIndicator"
        x: root.vertical ? root.crossCenter - width / 2 : root.levelPosition(root.boundedValue) - width / 2
        y: root.vertical ? root.levelPosition(root.boundedValue) - height / 2 : root.crossCenter - height / 2
        width: root.vertical ? root.oddPixels(volumeMouse.pressed ? 10 : 8) : 3 * root.hairline
        height: root.vertical ? 3 * root.hairline : root.oddPixels(volumeMouse.pressed ? 10 : 8)
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
