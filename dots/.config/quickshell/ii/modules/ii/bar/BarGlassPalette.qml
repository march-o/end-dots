pragma Singleton
import QtQuick
import Quickshell
import qs.modules.common

QtObject {
    id: root
    property ColorQuantizer wallpaper: ColorQuantizer {
        readonly property string path: Config.options.background.wallpaperPath
        source: Qt.resolvedUrl(/\.(mp4|webm|mkv|avi|mov)$/i.test(path)
            ? Config.options.background.thumbnailPath : path)
        depth: 0
        rescaleSize: 64
    }
    readonly property color dominant: wallpaper.colors[0] ?? Appearance.m3colors.m3primary
    readonly property color iconColor: bestColor(dominant)
    readonly property color darkestTone: [Appearance.m3colors.m3surfaceContainerLowest,
        Appearance.m3colors.m3surfaceDim, Appearance.m3colors.m3onPrimaryFixed,
        Appearance.m3colors.m3onSecondaryFixed, Appearance.m3colors.m3onTertiaryFixed]
        .reduce((best, candidate) => luminance(candidate) < luminance(best) ? candidate : best)
    readonly property color lightestTone: [Appearance.m3colors.m3onSurface,
        Appearance.m3colors.m3primaryFixed, Appearance.m3colors.m3secondaryFixed,
        Appearance.m3colors.m3tertiaryFixed]
        .reduce((best, candidate) => luminance(candidate) > luminance(best) ? candidate : best)

    function readableColor(preferred, background, minimumContrast = 3): color {
        const candidates = preferred.concat([Appearance.m3colors.m3primary,
            Appearance.m3colors.m3tertiary, Appearance.m3colors.m3onSurface,
            Appearance.m3colors.m3surfaceDim])
        let best = candidates[0]
        let bestContrast = 0
        for (const candidate of candidates) {
            const score = contrast(candidate, background)
            if (score >= minimumContrast) return candidate
            if (score > bestContrast) {
                best = candidate
                bestContrast = score
            }
        }
        return best
    }
    function bestColor(background, minimumContrast = 3): color {
        return readableColor([Appearance.m3colors.m3secondaryContainer], background, minimumContrast)
    }
    function buttonColors(background, minimumContrast = 3) {
        const off = bestColor(background, minimumContrast)
        const lightIcons = luminance(off) > luminance(background)
        const palette = Appearance.m3colors
        return {
            off: off,
            offHover: readableColor(lightIcons
                ? [palette.m3primaryFixed, palette.m3onSurface]
                : [palette.m3primaryContainer, palette.m3onPrimaryFixedVariant], background, minimumContrast),
            on: readableColor(lightIcons
                ? [palette.m3tertiary, palette.m3tertiaryFixedDim]
                : [palette.m3tertiaryContainer, palette.m3onTertiaryFixedVariant], background, minimumContrast),
            onHover: readableColor(lightIcons
                ? [palette.m3tertiaryFixed, palette.m3onSurface]
                : [palette.m3onTertiaryFixedVariant, palette.m3onTertiary], background, minimumContrast)
        }
    }

    function luminance(color): real {
        function linear(channel) {
            return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
    }
    function contrast(first, second): real {
        const a = luminance(first)
        const b = luminance(second)
        return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)
    }
}
