import QtQuick
import qs.modules.common

Rectangle {
    id: root
    property Item colorTarget: root
    WallpaperIconColor { id: frameColors; target: root.colorTarget }
    readonly property color outlineColor: BarGlassPalette.readableColor(
        [Appearance.m3colors.m3primary, Appearance.m3colors.m3primaryContainer,
         Appearance.m3colors.m3onPrimaryFixedVariant, Appearance.m3colors.m3secondary],
        frameColors.sampledBackground, 2)
    readonly property color tintColor: BarGlassPalette.glassTint
    property var seams: []
    readonly property real edgeWidth: 1.25
    readonly property color reflectionColor: Qt.rgba(
        0.34 + outlineColor.r * (1 - 0.34),
        0.34 + outlineColor.g * (1 - 0.34),
        0.34 + outlineColor.b * (1 - 0.34), 1)
    color: Config.options.bar.showBackground ? tintColor : "transparent"
    radius: Math.min(height / 2, BarGeometry.cornerRadius)
    border.width: Config.options.bar.showBackground ? edgeWidth : 0
    border.color: "transparent"

    // One continuous beveled edge; no separate bright horizontal streaks.
    Canvas {
        id: edge
        anchors.fill: parent
        visible: root.border.width > 0
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: requestPaint()
        Connections {
            target: root
            function onOutlineColorChanged() { edge.requestPaint(); }
            function onReflectionColorChanged() { edge.requestPaint(); }
            function onRadiusChanged() { edge.requestPaint(); }
            function onSeamsChanged() { edge.requestPaint(); }
        }
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var inset = root.border.width / 2;
            var w = width - 2 * inset, h = height - 2 * inset;
            if (w <= 0 || h <= 0) return;
            var r = Math.max(0, Math.min(root.radius - inset, w / 2, h / 2));
            var gradient = ctx.createLinearGradient(0, 0, width * 0.025, height);
            gradient.addColorStop(0, Qt.rgba(root.reflectionColor.r, root.reflectionColor.g, root.reflectionColor.b, 0.5));
            gradient.addColorStop(0.45, Qt.rgba(root.outlineColor.r, root.outlineColor.g, root.outlineColor.b, 0.32));
            gradient.addColorStop(1, Qt.rgba(root.outlineColor.r, root.outlineColor.g, root.outlineColor.b, 0.24));
            ctx.strokeStyle = gradient;
            ctx.lineWidth = root.border.width;
            ctx.beginPath();
            ctx.moveTo(inset + r, inset);
            ctx.lineTo(inset + w - r, inset);
            ctx.arcTo(inset + w, inset, inset + w, inset + r, r);
            ctx.lineTo(inset + w, inset + h - r);
            ctx.arcTo(inset + w, inset + h, inset + w - r, inset + h, r);
            ctx.lineTo(inset + r, inset + h);
            ctx.arcTo(inset, inset + h, inset, inset + h - r, r);
            ctx.lineTo(inset, inset + r);
            ctx.arcTo(inset, inset, inset + r, inset, r);
            ctx.closePath();
            ctx.stroke();
            // A recessed seam stays inside the continuous glass surface.
            for (var i = 0; i < root.seams.length; i++) {
                var x = root.seams[i];
                if (!isFinite(x) || x <= r || x >= width - r) continue;
                var dark = ctx.createLinearGradient(0, 3, 0, height - 3);
                dark.addColorStop(0, "transparent");
                dark.addColorStop(0.3, Qt.rgba(root.outlineColor.r, root.outlineColor.g, root.outlineColor.b, BarGeometry.seamOpacity));
                dark.addColorStop(0.7, Qt.rgba(root.outlineColor.r, root.outlineColor.g, root.outlineColor.b, BarGeometry.seamOpacity));
                dark.addColorStop(1, "transparent");
                ctx.fillStyle = dark;
                ctx.fillRect(x - 1, 3, 1.5, height - 6);
                var light = ctx.createLinearGradient(0, 3, 0, height - 3);
                light.addColorStop(0, "transparent");
                light.addColorStop(0.3, Qt.rgba(root.reflectionColor.r, root.reflectionColor.g, root.reflectionColor.b, BarGeometry.seamHighlightOpacity));
                light.addColorStop(0.7, Qt.rgba(root.reflectionColor.r, root.reflectionColor.g, root.reflectionColor.b, BarGeometry.seamHighlightOpacity));
                light.addColorStop(1, "transparent");
                ctx.fillStyle = light;
                ctx.fillRect(x + 0.5, 3, 1, height - 6);
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.edgeWidth
        radius: Math.max(0, root.radius - root.edgeWidth)
        visible: root.border.width > 0
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(root.reflectionColor.r, root.reflectionColor.g, root.reflectionColor.b, 0.07) }
            GradientStop { position: 0.24; color: Qt.rgba(root.reflectionColor.r, root.reflectionColor.g, root.reflectionColor.b, 0.006) }
            GradientStop { position: 0.65; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(root.outlineColor.r, root.outlineColor.g, root.outlineColor.b, 0.02) }
        }
    }
}
