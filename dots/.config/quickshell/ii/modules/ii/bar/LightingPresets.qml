import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services as Services
import qs.modules.common
import qs.modules.common.widgets

// Keep the passive hover pill in the existing bar window and input mask.
Item {
    id: root
    objectName: "homeLighting"
    property var controller: Services.HomeLighting
    readonly property var presets: controller.presets
    property bool expanded: false
    property real expansionProgress: expanded ? 1 : 0
    readonly property bool presented: expanded || expansionProgress > 0
    readonly property alias panelItem: panel
    readonly property real compactWidth: Math.max(100, face.implicitWidth + 24)
    readonly property real segmentWidth: Math.max(78, labelMetrics.width + 28)
    readonly property real expandedWidth: Math.min(Math.max(compactWidth, presets.length * segmentWidth + 12),
        (root.QsWindow.window?.screen?.width ?? 800) - 16)
    readonly property real expandedHeight: Math.max(52, BarGeometry.buttonSize + 16)
    readonly property string selectedPreset: controller.busy ? controller.pendingPreset : controller.selectedPreset
    readonly property string statusText: controller.busy ? "Sending…" : controller.lastError ? "Offline"
        : controller.selectedPreset ? label(controller.selectedPreset) : "Ready"
    implicitWidth: compactWidth
    implicitHeight: Appearance.sizes.baseBarHeight
    function label(preset) { return preset === "__off__" ? "Off" : preset.charAt(0).toUpperCase() + preset.slice(1); }
    function icon(preset) {
        const icons = { "__off__": "power_settings_new", unwind: "bedtime", chill: "weekend",
            building: "construction", cooking: "cooking", morning: "light_mode" };
        return icons[preset] ?? "lightbulb";
    }
    function dismiss() { openDelay.stop(); closeDelay.stop(); expanded = false; }
    Behavior on expansionProgress { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    TextMetrics {
        id: labelMetrics
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.normal
        text: root.presets.map(p => root.label(p)).sort((a, b) => b.length - a.length)[0] ?? "Lighting"
    }
    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered) { closeDelay.stop(); if (!root.expanded) openDelay.restart(); }
            else { openDelay.stop(); closeDelay.restart(); }
        }
    }
    Timer { id: openDelay; interval: 180; onTriggered: if (hover.hovered) root.expanded = true }
    Timer { id: closeDelay; interval: 300; onTriggered: if (!hover.hovered && !panelHover.hovered) root.dismiss() }
    WallpaperIconColor { id: colors; target: root }
    GlassButton {
        id: status
        objectName: "lightingStatus"
        anchors.centerIn: parent
        width: root.compactWidth
        height: Appearance.sizes.baseBarHeight
        Accessible.name: "Home lighting: " + root.statusText + ". Show lighting presets"
        onClicked: {
            if (root.controller.lastError) root.controller.refresh();
            root.expanded = true;
        }
        Item {
            property color color
            RowLayout {
                id: face
                anchors.centerIn: parent
                spacing: 8
                GlassIcon { text: root.controller.lastError ? "lightbulb" : root.icon(root.controller.selectedPreset); color: colors.iconColor }
                StyledText { text: root.statusText; color: colors.textColor; font.pixelSize: Appearance.font.pixelSize.normal }
            }
        }
    }
    GlassPanel {
        id: panel
        layerNamespace: "quickshell:bar"
        x: Math.max(8 - root.mapToItem(null, 0, 0).x,
            Math.min((root.QsWindow.window?.width ?? 800) - 8 - root.mapToItem(null, 0, 0).x - width,
                (root.width - width) / 2))
        y: Config.options.bar.bottom ? -height - 6 : root.height + 6
        width: root.expandedWidth
        height: root.expandedHeight
        contentPadding: 6
        radius: height / 2
        visible: root.presented
        opacity: root.expansionProgress
        scale: .94 + .06 * root.expansionProgress
        transformOrigin: Config.options.bar.bottom ? Item.Bottom : Item.Top
        HoverHandler {
            id: panelHover
            enabled: root.presented
            onHoveredChanged: {
                if (hovered) { closeDelay.stop(); root.expanded = true; }
                else closeDelay.restart();
            }
        }
        Row {
            id: sections
            anchors.centerIn: parent
            opacity: Math.max(0, root.expansionProgress * 3 - 2)
            visible: opacity > 0
            enabled: root.expanded && root.expansionProgress > .98
            spacing: 0
            Repeater {
                model: root.presets
                delegate: GlassButton {
                    id: button
                    required property string modelData
                    objectName: "lightingPreset-" + modelData
                    width: Math.min(root.segmentWidth, (root.expandedWidth - 12) / Math.max(1, root.presets.length))
                    height: root.expandedHeight - 12
                    toggled: root.selectedPreset === modelData
                    enabled: !root.controller.busy
                    buttonRadius: height / 2
                    selectionTint: BarGlassPalette.highlightTint(Appearance.m3colors.m3primary, .5)
                    statePalette: BarGlassPalette.islandButtonColors(toggled
                        ? BarGlassPalette.overlayTint(selectionTint) : BarGlassPalette.glassTint, 4.5)
                    Accessible.name: "Home lighting: " + root.label(modelData)
                    onClicked: root.controller.select(modelData)
                    StyledText {
                        text: root.label(button.modelData)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: button.toggled ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
        GlassButton {
            anchors.centerIn: parent
            visible: root.presets.length === 0 && root.presented
            opacity: sections.opacity
            width: root.compactWidth
            Accessible.name: "Reconnect Home lighting"
            onClicked: root.controller.refresh()
            StyledText { text: "Reconnect"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        }
    }
}
