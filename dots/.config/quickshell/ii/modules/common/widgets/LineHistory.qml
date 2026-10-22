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
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (width < 2 || height < 2) return;
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
        const points = samples.map((value, index) => ({
            x: 1 + (sampleCount - samples.length + index) / Math.max(1, sampleCount - 1) * (width - 2),
            y: height - 2 - Math.max(0, Math.min(1, value / Math.max(0.001, ceiling))) * (height - 4)
        }));
        if (fillArea && points.length > 1) {
            ctx.beginPath();
            ctx.moveTo(points[0].x, height - 1);
            for (const point of points) ctx.lineTo(point.x, point.y);
            ctx.lineTo(points[points.length - 1].x, height - 1);
            ctx.closePath();
            const fill = ctx.createLinearGradient(0, 0, 0, height);
            fill.addColorStop(0, Qt.alpha(lineColor, 0.24));
            fill.addColorStop(1, Qt.alpha(lineColor, 0.02));
            ctx.fillStyle = fill; ctx.fill();
        }
        ctx.beginPath();
        ctx.moveTo(points[0].x, points[0].y);
        for (const point of points.slice(1)) ctx.lineTo(point.x, point.y);
        ctx.lineWidth = lineWidth;
        ctx.lineJoin = "miter";
        ctx.lineCap = "butt";
        ctx.strokeStyle = lineColor; ctx.stroke();
        const last = points[points.length - 1];
        ctx.fillStyle = lineColor;
        ctx.fillRect(last.x - 1, last.y - 1, 2, 2);
    }
}
