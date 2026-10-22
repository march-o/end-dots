import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

GlassPanel {
    id: root
    contentPadding: 16
    radius: 12
    surfaceTint: GlassColors.monitorSurface
    foregroundColor: GlassColors.monitorForeground
    property bool ashSelected: false
    readonly property bool hovered: pointer.hovered
    readonly property var stats: ashSelected ? SystemStats.ash : SystemStats.local
    readonly property bool ready: ashSelected ? SystemStats.ashOnline : !!stats.memory
    readonly property var cpuHistory: ashSelected ? SystemStats.ashCpuHistory : SystemStats.localCpuHistory
    readonly property var memoryHistory: ashSelected ? SystemStats.ashMemoryHistory : SystemStats.localMemoryHistory
    readonly property var receiveHistory: ashSelected ? SystemStats.ashReceiveHistory : SystemStats.localReceiveHistory
    readonly property var sendHistory: ashSelected ? SystemStats.ashSendHistory : SystemStats.localSendHistory
    readonly property real networkCeiling: Math.max(1024, ...receiveHistory, ...sendHistory)
    HoverHandler { id: pointer }

    component Caption: StyledText {
        color: GlassColors.monitorMuted
        font.pixelSize: Appearance.font.pixelSize.smaller
    }
    component Numeric: StyledText {
        color: GlassColors.monitorForeground
        font.pixelSize: Appearance.font.pixelSize.smaller
    }
    component ValueRow: RowLayout {
        property string label
        property string value
        property color valueColor: GlassColors.monitorForeground
        spacing: 8
        Caption { text: parent.label; Layout.fillWidth: true }
        Numeric { text: parent.value; color: parent.valueColor }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                text: "System"
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: GlassColors.monitorForeground
            }
            Item { Layout.fillWidth: true }
            Repeater {
                model: [{ label: "Local", remote: false }, { label: "Ash", remote: true }]
                delegate: GlassButton {
                    id: choice
                    required property var modelData
                    statePalette: root.statePalette
                    toggled: root.ashSelected === modelData.remote
                    implicitWidth: 68
                    implicitHeight: 32
                    Accessible.name: modelData.label + " system statistics"
                    onClicked: root.ashSelected = modelData.remote
                    Column {
                        property color color: choice.iconColor
                        spacing: 5
                        StyledText {
                            id: choiceLabel
                            text: choice.modelData.label
                            color: choice.toggled ? GlassColors.monitorForeground : GlassColors.monitorMuted
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                        Rectangle { width: choiceLabel.implicitWidth; height: 2; color: choiceLabel.color; opacity: choice.toggled ? 1 : 0 }
                    }
                }
            }
            Caption {
                text: root.ashSelected ? (SystemStats.ashOnline ? "LIVE" : SystemStats.remoteState === "connecting" ? "CONNECTING" : "OFFLINE") : "LIVE"
                font.pixelSize: Appearance.font.pixelSize.smallest
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Caption {
                text: root.ready ? (root.stats.hostname ?? "") + "  /  " + (root.stats.cpuName ?? "") : root.ashSelected ? "ash" : "This device"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Caption { text: root.ready ? Math.floor((root.stats.uptime ?? 0) / 86400) + "d uptime" : "" }
        }
        ColumnLayout {
            visible: !root.ready
            Layout.fillWidth: true
            Layout.fillHeight: true
            Item { Layout.fillHeight: true }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.ashSelected ? (SystemStats.remoteState === "connecting" ? "Connecting to Ash…" : "Ash is unavailable") : "Reading system statistics…"
                color: GlassColors.monitorForeground
            }
            Caption { Layout.alignment: Qt.AlignHCenter; text: root.ashSelected ? "Retries automatically while this panel is open" : "Waiting for the first sample" }
            Item { Layout.fillHeight: true }
        }
        Flickable {
            id: scroll
            visible: root.ready
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: sections.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            Connections { target: root; function onAshSelectedChanged() { scroll.contentY = 0; } }
            ColumnLayout {
                id: sections
                width: scroll.width - 4
                spacing: 16
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 24
                    MonitorSection {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        title: "CPU"
                        icon: "speed"
                        Numeric { text: SystemStats.percent(root.stats.cpu); font.pixelSize: Appearance.font.pixelSize.huge }
                        LineHistory {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 66
                            values: root.cpuHistory
                            lineColor: GlassColors.monitorCpu
                            Accessible.name: "CPU usage history"
                        }
                        ValueRow { Layout.fillWidth: true; label: "User / system"; value: SystemStats.percent(root.stats.cpuUser) + " / " + SystemStats.percent(root.stats.cpuSystem) }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 6
                            columnSpacing: 4
                            rowSpacing: 4
                            Repeater {
                                model: root.stats.cores ?? []
                                delegate: MeterBar {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 4
                                    value: modelData ?? 0
                                    meterColor: GlassColors.monitorCpu
                                    Accessible.name: "Thread " + (index + 1) + ": " + SystemStats.percent(modelData)
                                }
                            }
                        }
                        Caption { text: (root.stats.cores?.length ?? 0) + " threads · load " + (root.stats.load ?? []).map(n => n.toFixed(1)).join(" / "); Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                    MonitorSection {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        title: "Memory"
                        icon: "memory"
                        Numeric { text: SystemStats.percent(root.stats.memory?.total > 0 ? root.stats.memory.used / root.stats.memory.total : undefined); font.pixelSize: Appearance.font.pixelSize.huge }
                        LineHistory {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 66
                            values: root.memoryHistory
                            lineColor: GlassColors.monitorMemory
                            Accessible.name: "Memory usage history"
                        }
                        ValueRow { Layout.fillWidth: true; label: "Used"; value: SystemStats.bytes(root.stats.memory?.used) + " / " + SystemStats.bytes(root.stats.memory?.total) }
                        ValueRow { Layout.fillWidth: true; label: "Available"; value: SystemStats.bytes(root.stats.memory?.available) }
                        ValueRow { Layout.fillWidth: true; label: "Cache"; value: SystemStats.bytes(root.stats.memory?.cache) }
                    }
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: GlassColors.monitorLine }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 24
                    MonitorSection {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        title: "Storage"
                        icon: "storage"
                        Repeater {
                            model: root.stats.disks ?? []
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 8
                                ValueRow { Layout.fillWidth: true; label: modelData.mount; value: SystemStats.percent(modelData.total > 0 ? modelData.used / modelData.total : 0) }
                                MeterBar { Layout.fillWidth: true; Layout.preferredHeight: 5; value: modelData.total > 0 ? modelData.used / modelData.total : 0; meterColor: GlassColors.monitorDisk }
                                Caption { text: SystemStats.bytes(modelData.free) + " free / " + SystemStats.bytes(modelData.total) }
                            }
                        }
                    }
                    MonitorSection {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        title: "Swap"
                        icon: "swap_horiz"
                        ValueRow { Layout.fillWidth: true; label: "Used"; value: (root.stats.swap?.total ?? 0) > 0 ? SystemStats.bytes(root.stats.swap.used) + " / " + SystemStats.bytes(root.stats.swap.total) : "Not configured" }
                        MeterBar { Layout.fillWidth: true; Layout.preferredHeight: 5; value: (root.stats.swap?.total ?? 0) > 0 ? root.stats.swap.used / root.stats.swap.total : 0; meterColor: GlassColors.monitorSwap }
                    }
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: GlassColors.monitorLine }
                MonitorSection {
                    Layout.fillWidth: true
                    title: "Network"
                    icon: "network_check"
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 24
                        Repeater {
                            model: [
                                { icon: "download", label: "Download", value: root.stats.network?.received, history: root.receiveHistory, color: GlassColors.monitorReceive },
                                { icon: "upload", label: "Upload", value: root.stats.network?.sent, history: root.sendHistory, color: GlassColors.monitorTransmit }
                            ]
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                spacing: 6
                                RowLayout {
                                    Layout.fillWidth: true
                                    MaterialSymbol { text: modelData.icon; iconSize: 18; color: GlassColors.monitorForeground }
                                    Caption { text: modelData.label; Layout.fillWidth: true }
                                    Numeric { text: root.stats.network?.ready ? SystemStats.bytes(modelData.value) + "/s" : "Sampling…" }
                                }
                                LineHistory {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    values: modelData.history
                                    ceiling: root.networkCeiling
                                    lineColor: modelData.color
                                    showGrid: false
                                    Accessible.name: modelData.label + " history"
                                }
                            }
                        }
                    }
                    Caption { text: (root.stats.network?.interfaces ?? []).join(", "); Layout.fillWidth: true; elide: Text.ElideRight }
                }
            }
        }
    }
}
