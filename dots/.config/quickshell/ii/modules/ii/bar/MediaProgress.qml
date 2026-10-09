import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root
    required property var player
    property bool active: false
    property color foreground: elapsedColors.textColor
    property color accent: railColors.statePalette.on
    readonly property real duration: player?.lengthSupported ? Math.max(0, player.length) : 0
    readonly property real position: Math.max(0, player?.position ?? 0)
    readonly property bool seekable: !!(player?.canSeek && player?.positionSupported && duration > 0)
    Layout.fillWidth: true
    Layout.preferredHeight: 25
    implicitHeight: 25
    WallpaperIconColor { id: elapsedColors; target: elapsed }
    WallpaperIconColor { id: durationColors; target: total }
    WallpaperIconColor { id: railColors; target: root }
    function formatTime(seconds) {
        const value = Math.floor(Math.max(0, seconds))
        return Math.floor(value / 60) + ":" + String(value % 60).padStart(2, "0")
    }
    function seek(mouse) {
        if (seekable) player.position = Math.max(0, Math.min(duration, mouse.x / width * duration))
    }
    Timer {
        interval: 1000
        running: root.active && !!root.player?.positionSupported
        repeat: true
        onTriggered: root.player.positionChanged()
    }
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 3
        radius: 1.5
        color: ColorUtils.applyAlpha(root.foreground, 0.25)
        Rectangle {
            width: parent.width * (root.duration > 0 ? Math.min(1, root.position / root.duration) : 0)
            height: parent.height
            radius: parent.radius
            color: root.accent
        }
    }
    MouseArea {
        width: parent.width
        height: 12
        enabled: root.seekable
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.seek(mouse)
        onPositionChanged: mouse => { if (pressed) root.seek(mouse) }
    }
    StyledText {
        id: elapsed
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        text: root.player?.positionSupported ? root.formatTime(root.position) : "—:—"
        font.pixelSize: 10
        color: root.foreground
    }
    StyledText {
        id: total
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: root.duration > 0 ? root.formatTime(root.duration) : "—:—"
        font.pixelSize: 10
        color: root.foreground
    }
}
