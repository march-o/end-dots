pragma Singleton
import QtQuick
import qs.modules.common
import qs.modules.ii.bar

QtObject {
    // A modestly darker shared surface for expanded telemetry only.
    readonly property color monitorSurface: Qt.rgba(surface.r * 0.80, surface.g * 0.80, surface.b * 0.80, Math.min(0.86, surface.a + 0.035))
    readonly property color monitorForeground: BarGlassPalette.islandColor([foreground], monitorSurface, 4.5)
    readonly property color monitorMuted: BarGlassPalette.islandColor([textStates.off], monitorSurface, 4.5)
    readonly property color statsCpuTint: BarGlassPalette.highlightTint(Appearance.m3colors.m3primary, 0.24)
    readonly property color statsMemoryTint: BarGlassPalette.highlightTint(Appearance.m3colors.m3tertiary, 0.24)
    readonly property color monitorCpu: "#67d4ed"
    readonly property color monitorMemory: "#a6df8a"
    readonly property color monitorSwap: "#c4a0ef"
    readonly property color monitorDisk: "#efc078"
    readonly property color monitorReceive: "#67d4ed"
    readonly property color monitorTransmit: "#ee93b2"
    readonly property color monitorLine: Qt.rgba(0.60, 0.69, 0.77, 0.18)
    readonly property color surface: BarGlassPalette.glassTint
    readonly property color foreground: BarGlassPalette.glassTextTone
    readonly property var states: BarGlassPalette.islandButtonColors(surface)
    readonly property var textStates: BarGlassPalette.islandButtonColors(surface, 4.5)
    // Keep monitor identity consistent in overview labels and bar highlights.
    function monitorColor(focused): color {
        return focused ? states.on : states.off;
    }
    readonly property color onAccent: BarGlassPalette.readableColor(
        [BarGlassPalette.darkestTone, BarGlassPalette.lightestTone], textStates.on, 4.5)
    readonly property var colors: colorsFor(surface, foreground)
    function colorsFor(surface: color, foreground: color): var {
        const states = BarGlassPalette.islandButtonColors(surface);
        const textStates = BarGlassPalette.islandButtonColors(surface, 4.5);
        const onAccent = BarGlassPalette.readableColor(
            [BarGlassPalette.darkestTone, BarGlassPalette.lightestTone], textStates.on, 4.5);
        const result = Object.assign({}, Appearance.colors);
        result.colLayer0 = surface;
        for (const role of ["colLayer1", "colLayer2", "colLayer3", "colLayer4"]) {
            result[role] = "transparent";
            result[role + "Hover"] = "transparent";
            result[role + "Active"] = "transparent";
        }
        for (const role of ["colOnLayer0", "colOnLayer1", "colOnLayer2", "colOnLayer3",
             "colOnLayer4", "colOnSurface", "colSubtext", "colOnSurfaceVariant", "colOnSecondaryContainer"]) result[role] = foreground;
        result.colPrimary = textStates.on;
        result.colPrimaryHover = textStates.onHover;
        result.colPrimaryActive = textStates.onHover;
        result.colOnPrimary = onAccent;
        result.colSecondaryContainer = Qt.rgba(states.off.r, states.off.g, states.off.b, 0.10);
        result.colPrimaryContainer = result.colSecondaryContainer;
        result.colOnPrimaryContainer = foreground;
        result.colSecondaryContainerHover = result.colSecondaryContainer;
        result.colSecondaryContainerActive = result.colSecondaryContainer;
        result.colOutlineVariant = textStates.off;
        result.colLayer0Border = states.off;
        result.colError = BarGlassPalette.islandColor([Appearance.m3colors.m3error], surface, 4.5);
        result.colErrorHover = result.colError;
        result.colErrorActive = result.colError;
        return result;
    }
    readonly property var m3colors: Object.assign({}, Appearance.m3colors, {
        m3onBackground: foreground, m3onSurface: foreground, m3onSurfaceVariant: foreground,
        m3onPrimary: onAccent, m3onSecondaryContainer: foreground,
        m3primary: textStates.on, m3outline: textStates.off, m3surfaceContainerHigh: surface
    })
}
