import QtQuick
import QtQuick.Effects
import Quickshell
import qs.services
import qs.modules.common

// Sample only the panel's wallpaper crop, not the windows behind the panel.
Item {
    id: root
    property real radius: BarGeometry.cornerRadius
    property color tint: BarGlassPalette.glassTint
    property string layerNamespace: "quickshell:bar"
    readonly property var window: root.QsWindow.window ?? null
    readonly property var screen: root.QsWindow.window?.screen ?? null
    readonly property var scene: WallpaperScene.images[root.screen?.name] ?? null
    readonly property var monitor: HyprlandData.monitors.find(m => m.name === root.screen?.name) ?? null
    readonly property string path: /\.(mp4|webm|mkv|avi|mov)$/i.test(Config.options.background.wallpaperPath)
        ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath
    readonly property var surface: {
        const levels = HyprlandData.layers[root.screen?.name]?.levels ?? {};
        for (const group of Object.values(levels)) {
            const layer = group.find(l => l.namespace === root.layerNamespace);
            if (layer) return layer;
        }
        return null;
    }
    property point origin: Qt.point(0, 0)
    function updateOrigin() {
        if (!root.screen || !root.monitor || !root.window) return;
        // Wayland layer surfaces do not expose their compositor-global origin
        // through Qt's mapToGlobal. Combine window-local coordinates with the
        // actual layer placement, including the right anchor and reserved bar.
        const p = root.mapToItem(root.window.contentItem, 0, 0);
        const reserved = root.monitor.reserved ?? [0, 0, 0, 0];
        const sidebar = root.layerNamespace.endsWith("sidebarRight");
        const gallery = root.layerNamespace.endsWith("wallpaperSelector");
        const fallbackX = sidebar ? root.screen.width - root.window.width - reserved[2]
            : gallery ? (root.screen.width - root.window.width) / 2 : 0;
        const fallbackY = sidebar ? reserved[1]
            : gallery ? (root.window.margins?.top ?? 0)
            : (root.window.anchors?.bottom && !root.window.anchors?.top ? root.screen.height - root.window.height : 0);
        root.origin = Qt.point((root.surface ? root.surface.x - root.monitor.x : fallbackX) + p.x,
                              (root.surface ? root.surface.y - root.monitor.y : fallbackY) + p.y);
    }
    onWidthChanged: updateOrigin()
    onHeightChanged: updateOrigin()
    Component.onCompleted: { updateOrigin(); HyprlandData.updateLayers(); }
    // A compositor slide moves a cached surface without updating QML coordinates.
    // GlassPanelWindow keeps that surface fixed; track its animated child each frame.
    FrameAnimation {
        running: root.visible && (root.window?.visible ?? false)
        onTriggered: root.updateOrigin()
    }

    Image {
        id: wallpaper
        width: root.scene?.width ?? root.screen?.width ?? root.width
        height: root.scene?.height ?? root.screen?.height ?? root.height
        source: root.scene?.source ?? root.path
        sourceSize: Qt.size(2048, 2048)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        retainWhileLoading: true
        visible: false
    }
    ShaderEffectSource {
        id: patch
        anchors.fill: parent
        sourceItem: wallpaper
        sourceRect: Qt.rect(root.origin.x - (root.scene?.x ?? 0),
                            root.origin.y - (root.scene?.y ?? 0), root.width, root.height)
        textureSize: Qt.size(Math.max(1, root.width), Math.max(1, root.height))
        hideSource: true
        visible: false
    }
    Rectangle {
        id: roundedMask
        anchors.fill: parent
        radius: root.radius
        color: "white"
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        source: patch
        visible: wallpaper.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 32
        blur: 0.45
        maskEnabled: true
        maskSource: roundedMask
    }
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.tint
    }
}
