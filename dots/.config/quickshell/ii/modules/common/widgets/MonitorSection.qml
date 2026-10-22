import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common

GroupBox {
    id: box
    property color accent: GlassColors.monitorCpu
    default property alias sectionData: body.data
    padding: 12
    topPadding: 34
    label: StyledText {
        x: 12
        y: 10
        text: box.title
        color: box.accent
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2
    }
    background: Rectangle {
        color: "transparent"
        radius: 4
        border.width: 1
        border.color: GlassColors.monitorLine
    }
    contentItem: ColumnLayout { id: body; spacing: 7 }
}
