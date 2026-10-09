import qs.modules.common
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool vertical: false
    property bool glass: false
    property real glassWidth: width
    property real glassHeight: height
    property alias glassFrame: background
    property real padding: 5
    property color colBackground: "transparent"
    implicitWidth: vertical ? Appearance.sizes.baseVerticalBarWidth : (gridLayout.implicitWidth + padding * 2)
    implicitHeight: vertical ? (gridLayout.implicitHeight + padding * 2) : Appearance.sizes.baseBarHeight
    default property alias items: gridLayout.children

    BarGlassIsland {
        id: background
        parent: root
        x: root.glass ? (root.width - root.glassWidth) / 2 : (root.vertical ? 4 : 0)
        y: root.glass || root.vertical ? 0 : 4
        width: root.glass ? root.glassWidth : root.width - (root.vertical ? 8 : 0)
        height: root.glass ? root.glassHeight : root.height - (root.vertical ? 0 : 8)
        color: root.glass && Config.options.bar.showBackground ? Qt.rgba(1, 1, 1, 0.035) : root.colBackground
        radius: root.glass ? Math.min(height / 2, Appearance.rounding.windowRounding) : Appearance.rounding.small
        border.width: root.glass && Config.options.bar.showBackground ? 2 : 0
    }

    GridLayout {
        id: gridLayout
        columns: root.vertical ? 1 : -1
        anchors {
            verticalCenter: root.vertical ? undefined : parent.verticalCenter
            horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
            left: root.vertical ? undefined : parent.left
            right: root.vertical ? undefined : parent.right
            top: root.vertical ? parent.top : undefined
            bottom: root.vertical ? parent.bottom : undefined
            margins: root.padding
        }
        columnSpacing: 4
        rowSpacing: 12
    }
}
