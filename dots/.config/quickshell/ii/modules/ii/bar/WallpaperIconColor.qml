import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Item {
    id: root
    required property Item target
    property real rightPadding: 0
    property string lastGeometry: ""
    readonly property var screen: target.QsWindow.window?.screen ?? null
    readonly property string selectedPath: Config.options.background.wallpaperPath
    readonly property string path: /\.(mp4|webm|mkv|avi|mov)$/i.test(selectedPath)
        ? Config.options.background.thumbnailPath : selectedPath
    property color sampledBackground: BarGlassPalette.dominant
    readonly property var statePalette: BarGlassPalette.buttonColors(sampledBackground)
    readonly property var textStatePalette: BarGlassPalette.buttonColors(sampledBackground, 4.5)
    readonly property color textColor: BarGlassPalette.bestColor(sampledBackground, 4.5)
    readonly property color mutedColor: BarGlassPalette.readableColor(
        [Appearance.m3colors.m3outline, Appearance.m3colors.m3outlineVariant], sampledBackground)
    readonly property color warningColor: BarGlassPalette.readableColor(
        [Appearance.m3colors.m3error, Appearance.m3colors.m3onErrorContainer,
         Appearance.m3colors.m3errorContainer], sampledBackground, 4.5)
    readonly property color iconColor: BarGlassPalette.bestColor(sampledBackground)
    readonly property real zoom: Config.options.background.parallax.workspaceZoom
    onPathChanged: { lastGeometry = ""; refresh.restart() }
    onScreenChanged: refresh.restart()
    onZoomChanged: { lastGeometry = ""; refresh.restart() }
    Component.onCompleted: refresh.restart()

    Connections {
        target: root.target
        function onWidthChanged() { refresh.restart() }
        function onHeightChanged() { refresh.restart() }
        function onXChanged() { refresh.restart() }
        function onYChanged() { refresh.restart() }
    }
    Connections {
        target: root.screen
        function onWidthChanged() { refresh.restart() }
        function onHeightChanged() { refresh.restart() }
    }
    Timer {
        id: refresh
        interval: 250
        onTriggered: {
            if (!root.screen || !root.path || root.target.width <= 0 || root.target.height <= 0 || probe.running) {
                if (probe.running) restart()
                return
            }
            const position = root.target.mapToItem(null, 0, 0)
            const y = position.y + (Config.options.bar.bottom ? root.screen.height - root.target.QsWindow.window.height : 0)
            root.lastGeometry = [position.x, y, root.target.width, root.target.height].join(",")
            probe.command = ["python3", Quickshell.shellPath("scripts/images/sample-bar-wallpaper.py"),
                root.path, String(root.screen.width), String(root.screen.height),
                String(position.x), String(y), String(root.target.width + root.rightPadding),
                String(root.target.height), String(root.zoom)]
            probe.running = true
        }
    }
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            if (!root.screen) return
            const position = root.target.mapToItem(null, 0, 0)
            const y = position.y + (Config.options.bar.bottom ? root.screen.height - root.target.QsWindow.window.height : 0)
            const geometry = [position.x, y, root.target.width, root.target.height].join(",")
            if (geometry !== root.lastGeometry) refresh.restart()
        }
    }
    Process {
        id: probe
        stdout: StdioCollector {
            onStreamFinished: {
                const color = text.trim()
                if (/^#[0-9a-f]{6}$/i.test(color)) root.sampledBackground = color
            }
        }
    }
}
