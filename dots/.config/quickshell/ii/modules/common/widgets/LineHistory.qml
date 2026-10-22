import QtQuick
import qs.modules.common

Canvas {
    id: root
    property var values: []
    property color lineColor: GlassColors.monitorCpu
    property color gridColor: GlassColors.monitorLine
    property int sampleCount: 40
    property real ceiling: 1
    property real lineWidth: 1.5
    property bool showGrid: true
    property bool fillArea: true
    property bool stretchSamples: false
    property bool showEndpoint: true
    property real fillTopOpacity: 0.24
    property real fillBottomOpacity: 0.02
    property real leftRadius: 0
    property real rightRadius: 0
    implicitWidth: 180
    implicitHeight: 64
    Accessible.role: Accessible.Graphic
    Accessible.name: "Recent activity history"
    onValuesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onGridColorChanged: requestPaint()
    onCeilingChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onShowGridChanged: requestPaint()
    onFillAreaChanged: requestPaint()
    onStretchSamplesChanged: requestPaint()
    onShowEndpointChanged: requestPaint()
    onFillTopOpacityChanged: requestPaint()
    onFillBottomOpacityChanged: requestPaint()
    onLeftRadiusChanged: requestPaint()
    onRightRadiusChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (width < 2 || height < 2) return;
        // Clip filled histories to the owning pill without an offscreen layer.
        if (leftRadius > 0 || rightRadius > 0) {
            const left = Math.min(leftRadius, width / 2, height / 2);
            const right = Math.min(rightRadius, width / 2, height / 2);
            ctx.beginPath();
            ctx.moveTo(left, 0); ctx.lineTo(width - right, 0);
            ctx.quadraticCurveTo(width, 0, width, right);
            ctx.lineTo(width, height - right);
            ctx.quadraticCurveTo(width, height, width - right, height);
            ctx.lineTo(left, height);
            ctx.quadraticCurveTo(0, height, 0, height - left);
            ctx.lineTo(0, left); ctx.quadraticCurveTo(0, 0, left, 0);
            ctx.closePath(); ctx.clip();
        }
        if (showGrid) {
            ctx.strokeStyle = gridColor;
            ctx.lineWidth = 1;
            for (const ratio of [0, 0.5, 1]) {
                const y = 1 + ratio * (height - 2);
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
            }
        }
        const samples = values.slice(-sampleCount);
        if (!samples.length) return;
        if (stretchSamples && samples.length === 1) samples.unshift(samples[0]);
        const points = samples.map((value, index) => ({
            x: 1 + (stretchSamples ? index / Math.max(1, samples.length - 1)
                : (sampleCount - samples.length + index) / Math.max(1, sampleCount - 1)) * (width - 2),
            y: height - 2 - Math.max(0, Math.min(1, value / Math.max(0.001, ceiling))) * (height - 4)
        }));
        if (fillArea && points.length > 1) {
            ctx.beginPath();
            ctx.moveTo(points[0].x, height - 1);
            for (const point of points) ctx.lineTo(point.x, point.y);
            ctx.lineTo(points[points.length - 1].x, height - 1);
            ctx.closePath();
            const fill = ctx.createLinearGradient(0, 0, 0, height);
            fill.addColorStop(0, Qt.alpha(lineColor, fillTopOpacity));
            fill.addColorStop(1, Qt.alpha(lineColor, fillBottomOpacity));
            ctx.fillStyle = fill; ctx.fill();
        }
        ctx.beginPath();
        ctx.moveTo(points[0].x, points[0].y);
        for (const point of points.slice(1)) ctx.lineTo(point.x, point.y);
        ctx.lineWidth = lineWidth;
        ctx.lineJoin = "miter";
        ctx.lineCap = "butt";
        ctx.strokeStyle = lineColor; ctx.stroke();
        if (showEndpoint) {
            const last = points[points.length - 1];
            ctx.fillStyle = lineColor;
            ctx.fillRect(last.x - 1, last.y - 1, 2, 2);
        }
    }
}
