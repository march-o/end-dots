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
    readonly property color iconColor: islandButtonColors(glassTint).off
    readonly property color darkestTone: [Appearance.m3colors.m3surfaceContainerLowest,
        Appearance.m3colors.m3surfaceDim, Appearance.m3colors.m3onPrimaryFixed,
        Appearance.m3colors.m3onSecondaryFixed, Appearance.m3colors.m3onTertiaryFixed]
        .reduce((best, candidate) => luminance(candidate) < luminance(best) ? candidate : best)
    readonly property color lightestTone: [Appearance.m3colors.m3onSurface,
        Appearance.m3colors.m3primaryFixed, Appearance.m3colors.m3secondaryFixed,
        Appearance.m3colors.m3tertiaryFixed]
        .reduce((best, candidate) => luminance(candidate) > luminance(best) ? candidate : best)

    // A visible theme accent establishes one surface for all compact islands.
    // Blue/yellow accents retain their color better in deep glass with bright ink.
    // Smooth hue affinity avoids abrupt wallpaper or color-family special cases.
    readonly property real blueAffinity: hueAffinity(Appearance.m3colors.m3primaryFixed, 2 / 3, 8)
    readonly property real yellowAffinity: hueAffinity(Appearance.m3colors.m3primaryFixed, 1 / 6, 16)
    readonly property bool lightGlass: luminance(dominant) <
        0.14 * (1 - 0.94 * Math.max(blueAffinity, yellowAffinity))
    function hueAffinity(tone, hue, exponent): real {
        // Achromatic themes should keep the normal brightness-based choice.
        return Math.pow((1 + Math.cos(2 * Math.PI * (tone.hslHue - hue))) / 2, exponent)
            * Math.min(1, tone.hslSaturation * 2);
    }
    readonly property color glassTextTone: {
        const tone = lightGlass ? Appearance.m3colors.m3onPrimaryFixed : Appearance.m3colors.m3primaryFixed;
        const lift = lightGlass ? 0 : BarGeometry.textLift;
        return Qt.rgba(tone.r * (1 - lift) + lift,
                       tone.g * (1 - lift) + lift, tone.b * (1 - lift) + lift, 1);
    }
    readonly property color glassTint: chooseGlassTint()
    // Compose a translucent control highlight with the shared glass surface.
    function overlayTint(overlay, base = glassTint): color {
        const alpha = overlay.a + base.a * (1 - overlay.a);
        if (alpha <= 0) return Qt.rgba(0, 0, 0, 0);
        return Qt.rgba((overlay.r * overlay.a + base.r * base.a * (1 - overlay.a)) / alpha,
                       (overlay.g * overlay.a + base.g * base.a * (1 - overlay.a)) / alpha,
                       (overlay.b * overlay.a + base.b * base.a * (1 - overlay.a)) / alpha, alpha);
    }
    function highlightTint(tone, alpha): color {
        // Preserve the overview color's hue and saturation. Only adjust its
        // lightness when the translucent fill would make bar labels unreadable.
        let overlay = Qt.alpha(tone, alpha);
        for (let step = 0; step <= 49; step++) {
            for (const direction of (lightGlass ? [1, -1] : [-1, 1])) {
                const lightness = Math.max(0.02, Math.min(0.98, tone.hslLightness + step * direction * 0.02));
                overlay = step === 0 ? Qt.alpha(tone, alpha)
                    : Qt.hsla(tone.hslHue, tone.hslSaturation, lightness, alpha);
                const tint = overlayTint(overlay);
                const foreground = islandColor([glassTextTone], tint, 4.5);
                if (glassBounds(tint).every(background => contrast(foreground, background) >= 4.5)) return overlay;
            }
        }
        return overlay;
    }
    function glassBounds(tint) {
        const low = glassBackground(Qt.rgba(0, 0, 0, 1), tint);
        const high = glassBackground(Qt.rgba(1, 1, 1, 1), tint);
        // Include the brightest possible inset reflection, not only flat fill.
        return [low, Qt.rgba(high.r * 0.93 + 0.07, high.g * 0.93 + 0.07,
                             high.b * 0.93 + 0.07, 1)];
    }
    function chooseGlassTint(): color {
        const palette = Appearance.m3colors;
        const candidates = lightGlass
            ? [palette.m3primaryFixed, palette.m3secondaryFixed, palette.m3tertiaryFixed, palette.m3primaryFixedDim]
            : [palette.m3onPrimaryFixed, palette.m3onSecondaryFixed, palette.m3onTertiaryFixed,
               palette.m3onPrimaryFixedVariant, palette.m3primaryContainer, palette.m3secondaryContainer];
        // Cool pale washes lose chroma; prefer a richer generated blue tone.
        let best = candidates[0], bestOpacity = BarGeometry.maximumTintOpacity, bestScore = Infinity;
        for (const candidate of candidates) {
            let opacity = BarGeometry.minimumTintOpacity;
            for (; opacity < BarGeometry.maximumTintOpacity; opacity += 0.01) {
                const tint = Qt.rgba(candidate.r, candidate.g, candidate.b, opacity);
                if (Math.min(...glassBounds(tint).map(bg => contrast(glassTextTone, bg))) >= 4.5) break;
            }
            // A little more of the generated yellow makes dark-backdrop glass luminous.
            opacity = Math.min(opacity + (lightGlass ? yellowAffinity * 0.04 : 0), BarGeometry.maximumTintOpacity);
            const distance = Math.abs(candidate.hslHue - palette.m3primaryFixed.hslHue);
            const hueDistance = Math.min(distance, 1 - distance);
            // Favor the theme's principal hue and the least opaque readable wash.
            const paleness = lightGlass ? Math.max(0, luminance(candidate) - 0.50) * blueAffinity * 0.55 : 0;
            const tint = Qt.rgba(candidate.r, candidate.g, candidate.b, opacity);
            if (Math.min(...glassBounds(tint).map(bg => contrast(glassTextTone, bg))) < 4.5) continue;
            const score = opacity + hueDistance * 1.25 + (1 - candidate.hslSaturation) * 0.24 + paleness;
            if (score < bestScore) { best = candidate; bestOpacity = opacity; bestScore = score; }
        }
        return Qt.rgba(best.r, best.g, best.b, bestOpacity);
    }
    function islandColor(preferred, tint, minimumContrast = 4.5): color {
        const backgrounds = glassBounds(tint);
        const candidates = preferred.concat([glassTextTone, Appearance.m3colors.m3onPrimaryContainer,
            Appearance.m3colors.m3onPrimaryFixed, lightestTone, darkestTone]);
        let best = candidates[0], bestScore = 0;
        for (const candidate of candidates) {
            const score = Math.min(...backgrounds.map(background => contrast(candidate, background)));
            if (score >= minimumContrast) return candidate;
            if (score > bestScore) { best = candidate; bestScore = score; }
        }
        return best;
    }
    function islandButtonColors(tint, minimumContrast = 3) {
        const palette = Appearance.m3colors;
        const lightText = luminance(tint) < 0.30;
        return {
            off: islandColor(lightText ? [palette.m3primaryFixed, palette.m3onSurface]
                                       : [palette.m3onPrimaryFixed, palette.m3onSecondaryFixed], tint, minimumContrast),
            offHover: islandColor(lightText ? [palette.m3onPrimaryContainer, palette.m3secondaryFixed]
                                            : [palette.m3onPrimaryFixedVariant, palette.m3onSecondaryFixed], tint, minimumContrast),
            on: islandColor(lightText ? [palette.m3tertiaryFixedDim, palette.m3tertiaryFixed]
                                      : [palette.m3onTertiaryFixed, palette.m3onTertiaryFixedVariant], tint, minimumContrast),
            onHover: islandColor(lightText ? [palette.m3tertiaryFixed, palette.m3onSurface]
                                           : [palette.m3onTertiaryFixedVariant, palette.m3onTertiaryFixed], tint, minimumContrast)
        };
    }
    function glassBackground(background, selectedTint = glassTint): color {
        const tint = Config.options.bar.showBackground ? selectedTint : Qt.rgba(0, 0, 0, 0);
        return Qt.rgba(tint.r * tint.a + background.r * (1 - tint.a),
                       tint.g * tint.a + background.g * (1 - tint.a),
                       tint.b * tint.a + background.b * (1 - tint.a), 1);
    }

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
