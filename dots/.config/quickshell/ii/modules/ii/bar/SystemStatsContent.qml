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
        font.family: Appearance.font.family.monospace
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
                text: root.ashSelected ? (SystemStats.ashOnline ? "SSH · LIVE" : SystemStats.remoteState === "connecting" ? "CONNECTING" : "OFFLINE") : "LIVE"
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
                spacing: 10
                MonitorSection {
                    Layout.fillWidth: true
                    title: "CPU"
                    accent: GlassColors.monitorCpu
                    RowLayout {
                        Layout.fillWidth: true
                        Numeric {
                            text: SystemStats.percent(root.stats.cpu)
                            color: GlassColors.monitorCpu
                            font.pixelSize: Appearance.font.pixelSize.huge
                        }
                        Item { Layout.fillWidth: true }
                        Caption { text: "user " + SystemStats.percent(root.stats.cpuUser) + "  /  system " + SystemStats.percent(root.stats.cpuSystem) }
                    }
                    LineHistory {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 68
                        values: root.cpuHistory
                        lineColor: GlassColors.monitorCpu
                        Accessible.name: "CPU history, " + SystemStats.percent(root.stats.cpu) + " currently"
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Caption { text: root.ashSelected ? "3s samples" : "2s samples" }
                        Item { Layout.fillWidth: true }
                        Caption { text: "0–100%" }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 6
                        columnSpacing: 10
                        rowSpacing: 4
                        Repeater {
                            model: root.stats.cores ?? []
                            delegate: RowLayout {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                spacing: 5
                                Numeric { text: (index + 1).toString().padStart(2, "0"); color: GlassColors.monitorMuted; font.pixelSize: Appearance.font.pixelSize.smallest }
                                MeterBar {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 4
                                    value: modelData ?? 0
                                    meterColor: GlassColors.monitorCpu
                                    Accessible.name: "Thread " + (index + 1) + ": " + SystemStats.percent(modelData)
                                }
                            }
                        }
                    }
                    ValueRow {
                        Layout.fillWidth: true
                        label: (root.stats.cores?.length ?? 0) + " threads · load average"
                        value: (root.stats.load ?? []).map(n => n.toFixed(2)).join("  ")
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    MonitorSection {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        title: "MEMORY"
                        accent: GlassColors.monitorMemory
                        Numeric {
                            text: SystemStats.percent(root.stats.memory?.total > 0 ? root.stats.memory.used / root.stats.memory.total : undefined)
                            font.pixelSize: Appearance.font.pixelSize.huge
                            color: GlassColors.monitorMemory
                        }
                        LineHistory {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            values: root.memoryHistory
                            lineColor: GlassColors.monitorMemory
                            Accessible.name: "Memory history"
                        }
                        ValueRow { Layout.fillWidth: true; label: "Used"; value: SystemStats.bytes(root.stats.memory?.used); valueColor: GlassColors.monitorMemory }
                        ValueRow { Layout.fillWidth: true; label: "Total"; value: SystemStats.bytes(root.stats.memory?.total) }
                        ValueRow { Layout.fillWidth: true; label: "Available"; value: SystemStats.bytes(root.stats.memory?.available) }
                        ValueRow { Layout.fillWidth: true; label: "Cache"; value: SystemStats.bytes(root.stats.memory?.cache) }
                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: GlassColors.monitorLine }
                        ValueRow {
                            Layout.fillWidth: true
                            label: "Swap"
                            value: (root.stats.swap?.total ?? 0) > 0 ? SystemStats.bytes(root.stats.swap.used) + " / " + SystemStats.bytes(root.stats.swap.total) : "None"
                            valueColor: GlassColors.monitorSwap
                        }
                        MeterBar {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            value: (root.stats.swap?.total ?? 0) > 0 ? root.stats.swap.used / root.stats.swap.total : 0
                            meterColor: GlassColors.monitorSwap
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        spacing: 10
                        MonitorSection {
                            Layout.fillWidth: true
                            title: "STORAGE"
                            accent: GlassColors.monitorDisk
                            Repeater {
                                model: root.stats.disks ?? []
                                delegate: ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 6
                                    ValueRow { Layout.fillWidth: true; label: modelData.mount; value: SystemStats.percent(modelData.total > 0 ? modelData.used / modelData.total : 0); valueColor: GlassColors.monitorDisk }
                                    MeterBar { Layout.fillWidth: true; Layout.preferredHeight: 6; value: modelData.total > 0 ? modelData.used / modelData.total : 0; meterColor: GlassColors.monitorDisk }
                                    Caption { text: SystemStats.bytes(modelData.free) + " free / " + SystemStats.bytes(modelData.total) }
                                }
                            }
                        }
                        MonitorSection {
                            Layout.fillWidth: true
                            title: "NETWORK"
                            accent: GlassColors.monitorReceive
                            ValueRow { Layout.fillWidth: true; label: "↓ RX"; value: root.stats.network?.ready ? SystemStats.bytes(root.stats.network.received) + "/s" : "Sampling…"; valueColor: GlassColors.monitorReceive }
                            LineHistory {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                values: root.receiveHistory
                                ceiling: root.networkCeiling
                                lineColor: GlassColors.monitorReceive
                                showGrid: false
                                Accessible.name: "Download history"
                            }
                            ValueRow { Layout.fillWidth: true; label: "↑ TX"; value: root.stats.network?.ready ? SystemStats.bytes(root.stats.network.sent) + "/s" : "Sampling…"; valueColor: GlassColors.monitorTransmit }
                            LineHistory {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                values: root.sendHistory
                                ceiling: root.networkCeiling
                                lineColor: GlassColors.monitorTransmit
                                showGrid: false
                                Accessible.name: "Upload history"
                            }
                            Caption { text: (root.stats.network?.interfaces ?? []).join(", "); Layout.fillWidth: true; elide: Text.ElideRight }
                        }
                    }
                }
            }
        }
    }
}
