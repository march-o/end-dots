import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    objectName: "systemStats"
    property bool alwaysShowAllResources: false // Kept for compact-screen callers.
    implicitWidth: 284 * Math.max(1, Config.options.appearance.fontScale)
    implicitHeight: Appearance.sizes.baseBarHeight
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "CPU and memory. Open system statistics"
    Accessible.onPressAction: popup.toggle()
    onClicked: popup.toggle()
    Keys.onReturnPressed: popup.toggle(true)
    Keys.onSpacePressed: popup.toggle(true)
    Keys.onEscapePressed: popup.dismiss()

    Row {
        id: metrics
        anchors.fill: parent
        spacing: 0
        Repeater {
            model: [
                { icon: "speed", value: SystemStats.local.cpu, history: SystemStats.localCpuHistory, mirrored: false },
                { icon: "memory", value: SystemStats.local.memory?.total > 0 ? SystemStats.local.memory.used / SystemStats.local.memory.total : undefined,
                    history: SystemStats.localMemoryHistory, mirrored: true }
            ]
            delegate: Rectangle {
                required property var modelData
                width: root.width / 2
                height: root.height
                color: GlassColors.statsTint
                topLeftRadius: modelData.mirrored ? 0 : height / 2
                bottomLeftRadius: topLeftRadius
                topRightRadius: modelData.mirrored ? height / 2 : 0
                bottomRightRadius: topRightRadius
                LineHistory {
                    anchors.fill: parent
                    values: modelData.history
                    lineColor: GlassColors.statsChart
                    showGrid: false
                    fillArea: true
                    fillTopOpacity: 0.16
                    fillFromTrace: true
                    fillBottomOpacity: 0
                    showEndpoint: false
                    lineWidth: 1
                    sampleCount: 24
                    stretchSamples: true
                    leftRadius: parent.topLeftRadius
                    rightRadius: parent.topRightRadius
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: modelData.mirrored ? 8 : 14
                    anchors.rightMargin: modelData.mirrored ? 14 : 8
                    layoutDirection: modelData.mirrored ? Qt.RightToLeft : Qt.LeftToRight
                    spacing: 7
                    MaterialSymbol { text: modelData.icon; iconSize: 20; color: GlassColors.foreground }
                    StyledText {
                        text: SystemStats.percent(modelData.value)
                        color: GlassColors.foreground
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        horizontalAlignment: modelData.mirrored ? Text.AlignRight : Text.AlignLeft
                        Layout.minimumWidth: percentageWidth.width
                    }
                    Item { Layout.fillWidth: true }
                    TextMetrics { id: percentageWidth; text: "100%"; font.family: Appearance.font.family.main; font.pixelSize: Appearance.font.pixelSize.normal; font.weight: Font.Medium }
                }
            }
        }
    }
    Rectangle {
        anchors.centerIn: parent
        width: 1
        height: parent.height
        color: GlassColors.statsDivider
    }
    ResourcesPopup { id: popup; hoverTarget: root }
}
