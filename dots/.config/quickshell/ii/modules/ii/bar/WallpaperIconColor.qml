import QtQuick
import Quickshell
import qs.modules.common

// Compatibility provider: compact controls share the tinted glass palette.
// No individual image decode or wallpaper patch probe is needed.
Item {
    id: root
    required property Item target
    property real rightPadding: 0
    readonly property color wallpaperSample: BarGlassPalette.dominant
    readonly property color glassTint: BarGlassPalette.glassTint
    readonly property color sampledBackground: BarGlassPalette.glassBackground(wallpaperSample, glassTint)
    readonly property var statePalette: BarGlassPalette.islandButtonColors(glassTint)
    readonly property var textStatePalette: BarGlassPalette.islandButtonColors(glassTint, 4.5)
    readonly property color textColor: textStatePalette.off
    readonly property color mutedColor: BarGlassPalette.islandColor(
        [Appearance.m3colors.m3outline, Appearance.m3colors.m3onSurfaceVariant], glassTint, 4.5)
    readonly property color warningColor: BarGlassPalette.islandColor(
        [Appearance.m3colors.m3error, Appearance.m3colors.m3onErrorContainer], glassTint, 4.5)
    readonly property color iconColor: statePalette.off
}
