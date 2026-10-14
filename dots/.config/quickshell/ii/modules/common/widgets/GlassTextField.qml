import QtQuick
import QtQuick.Layouts
import qs.modules.common

// Use with GlassPanel: no opaque input plate or unrelated application palette.
ToolbarTextField {
    id: root
    Layout.fillHeight: false
    color: GlassColors.foreground
    placeholderTextColor: GlassColors.textStates.off
    selectedTextColor: GlassColors.onAccent
    selectionColor: GlassColors.textStates.on
    background: Rectangle {
        radius: height / 2
        color: "transparent"
        border.width: 1
        border.color: root.activeFocus ? GlassColors.textStates.offHover : GlassColors.textStates.off
    }
}
