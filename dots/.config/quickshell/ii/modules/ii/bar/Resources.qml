import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool alwaysShowAllResources: false // Kept for compact-screen callers.
    implicitWidth: metrics.implicitWidth
    implicitHeight: Appearance.sizes.barHeight
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

    RowLayout {
        id: metrics
        anchors.centerIn: parent
        spacing: 18
        Repeater {
            model: [
                { label: "CPU", value: SystemStats.local.cpu, history: SystemStats.localCpuHistory, color: GlassColors.monitorCpu },
                { label: "MEM", value: SystemStats.local.memory?.total > 0 ? SystemStats.local.memory.used / SystemStats.local.memory.total : undefined,
                    history: SystemStats.localMemoryHistory, color: GlassColors.monitorMemory }
            ]
            delegate: RowLayout {
                required property var modelData
                spacing: 6
                StyledText {
                    text: modelData.label
                    color: GlassColors.monitorForeground
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                }
                StyledText {
                    text: SystemStats.percent(modelData.value)
                    color: modelData.color
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    Layout.minimumWidth: percentageWidth.width
                }
                LineHistory {
                    values: modelData.history
                    lineColor: modelData.color
                    showGrid: false
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 22
                }
                TextMetrics { id: percentageWidth; text: "100%"; font.family: Appearance.font.family.monospace; font.pixelSize: Appearance.font.pixelSize.small }
            }
        }
    }
    ResourcesPopup { id: popup; hoverTarget: root }
}
