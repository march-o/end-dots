import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common

GroupBox {
    id: box
    property color accent: GlassColors.monitorForeground
    property string icon: ""
    default property alias sectionData: body.data
    padding: 0
    topPadding: 30
    label: RowLayout {
        spacing: 7
        MaterialSymbol { text: box.icon; iconSize: 20; color: box.accent; visible: box.icon.length > 0 }
        StyledText { text: box.title; color: box.accent; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.Medium }
    }
    background: Item {}
    contentItem: ColumnLayout { id: body; spacing: 8 }
}
