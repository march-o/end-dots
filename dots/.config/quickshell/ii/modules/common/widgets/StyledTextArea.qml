import qs.modules.common
import QtQuick
import QtQuick.Controls

/**
 * Does not include visual layout, but includes the easily neglected colors.
 */
TextArea {
    id: root
    renderType: Text.NativeRendering
    selectedTextColor: ScopedColors.m3ForItem(root).m3onSecondaryContainer
    selectionColor: ScopedColors.forItem(root).colSecondaryContainer
    placeholderTextColor: ScopedColors.m3ForItem(root).m3outline
    color: ScopedColors.forItem(root).colOnLayer0
    font {
        family: Appearance.font.family.main
        pixelSize: Appearance?.font.pixelSize.small ?? 15
        hintingPreference: Font.PreferFullHinting
        variableAxes: Appearance.font.variableAxes.main
    }
}
