pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.bar
import "OverviewNavigation.js" as Navigation

GlassPanel {
    id: root
    required property var screen
    contentPadding: 24
    readonly property int rows: Config.options.overview.rows
    readonly property int columns: Config.options.overview.columns
    readonly property int count: rows * columns
    readonly property var hiddenWorkspaces: HyprlandData.specialWorkspaces
    readonly property var monitor: HyprlandData.monitors.find(m => m.name === root.screen?.name) ?? null
    property int selectedIndex: 0
    // Keep identity through asynchronous workspace refreshes and removals.
    property string selectedHiddenName: ""
    readonly property bool searching: LauncherSearch.query !== ""
    implicitHeight: content.implicitHeight + contentPadding * 2

    function focusSearchInput() { searchWidget.focusSearchInput(); }
    function setSearchingText(text) { searchWidget.setSearchingText(text); }
    function resetSelection() {
        const special = hiddenWorkspaces.findIndex(ws => ws.name === monitor?.specialWorkspace?.name);
        selectedIndex = special >= 0 ? count + special : Math.max(0, Math.min(count - 1, (monitor?.activeWorkspace?.id ?? 1) - 1));
        selectedHiddenName = special >= 0 ? hiddenWorkspaces[special].name : "";
    }
    function acceptSelection() { searchWidget.acceptSelection(); }
    function navigate(direction) {
        if (root.searching) {
            if (direction === "up" || direction === "down") searchWidget.chooseResult(direction === "up" ? -1 : 1);
            return;
        }
        selectedIndex = Navigation.move(selectedIndex, direction, hiddenWorkspaces.length, rows, columns);
        selectedHiddenName = selectedIndex >= count ? hiddenWorkspaces[selectedIndex - count].name : "";
        hiddenList.positionViewAtIndex(selectedIndex - count, ListView.Contain);
    }
    function activateWorkspace(id) {
        GlobalStates.overviewOpen = false;
        const assigned = HyprlandData.workspaceById[id]?.monitor;
        const targetMonitor = HyprlandData.monitors.find(m => m.name === assigned) ?? root.monitor;
        if (targetMonitor) Hyprland.dispatch(`hl.dsp.focus({ monitor = ${JSON.stringify(targetMonitor.name)} })`);
        const special = targetMonitor?.specialWorkspace?.name?.replace(/^special:/, "");
        if (special) Hyprland.dispatch(`hl.dsp.workspace.toggle_special(${JSON.stringify(special)})`);
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
    }
    function activateHidden(name) {
        GlobalStates.overviewOpen = false;
        const visibleMonitor = HyprlandData.monitors.find(m => m.specialWorkspace?.name === name);
        const assigned = hiddenWorkspaces.find(ws => ws.name === name)?.monitor;
        const target = visibleMonitor?.name ?? assigned;
        if (HyprlandData.monitors.some(m => m.name === target))
            Hyprland.dispatch(`hl.dsp.focus({ monitor = ${JSON.stringify(target)} })`);
        if (!visibleMonitor)
            Hyprland.dispatch(`hl.dsp.workspace.toggle_special(${JSON.stringify(name.replace(/^special:/, ""))})`);
    }
    function activateSelection() {
        if (selectedIndex < count) activateWorkspace(selectedIndex + 1);
        else if (hiddenWorkspaces[selectedIndex - count]) activateHidden(hiddenWorkspaces[selectedIndex - count].name);
    }
    onHiddenWorkspacesChanged: {
        if (selectedHiddenName) {
            const index = hiddenWorkspaces.findIndex(ws => ws.name === selectedHiddenName);
            selectedIndex = index >= 0 ? count + index : Math.min(count - 1, selectedIndex);
            if (index < 0) selectedHiddenName = "";
        }
    }
    Component.onCompleted: { resetSelection(); Qt.callLater(focusSearchInput); }

    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 18
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                text: Translation.tr("Overview")
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            GlassButton {
                content: GlassIcon { text: "close" }
                onClicked: GlobalStates.overviewOpen = false
            }
        }
        SearchWidget {
            id: searchWidget
            Layout.fillWidth: true
            maximumResultsHeight: Math.min(560, (root.screen?.height ?? 900) - 300)
            onNavigateRequested: direction => root.navigate(direction)
            onWorkspaceAccepted: root.activateSelection()
            onDismissRequested: GlobalStates.overviewOpen = false
        }
        RowLayout {
            visible: !root.searching
            Layout.fillWidth: true
            spacing: 24
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    StyledText {
                        text: Translation.tr("Workspaces") + "  ·  " + root.count
                        color: GlassColors.textStates.off
                        font.pixelSize: Appearance.font.pixelSize.small
                        Layout.fillWidth: true
                    }
                    Repeater {
                        model: HyprlandData.monitors.slice().sort((a, b) => a.id - b.id)
                        OverviewMonitorTag {
                            required property var modelData
                            monitorName: modelData.name
                            expanded: true
                            current: modelData.name === root.screen?.name
                        }
                    }
                }
                OverviewWidget {
                    id: grid
                    Layout.fillWidth: true
                    screen: root.screen
                    scale: Math.min((width - workspaceSpacing * (root.columns - 1)) / root.columns / Math.max(1,
                        ((monitorRotated ? monitorHeight : monitorWidth) - (monitorData?.reserved?.[0] ?? 0) - (monitorData?.reserved?.[2] ?? 0)) / monitorScale),
                        ((root.screen?.height ?? 900) * 0.60 - root.rows * workspaceHeaderHeight) / Math.max(1, monitorHeight / monitorScale * root.rows))
                    selectedWorkspace: root.selectedIndex < root.count ? root.selectedIndex + 1 : -1
                    onWorkspaceChosen: workspace => root.activateWorkspace(workspace)
                }
            }
            ColumnLayout {
                Layout.preferredWidth: Math.max(260, Math.min(400, root.width * 0.27))
                Layout.fillHeight: true
                spacing: 12
                StyledText {
                    text: Translation.tr("Hidden workspaces") + "  ·  " + root.hiddenWorkspaces.length
                    color: GlassColors.textStates.off
                    font.pixelSize: Appearance.font.pixelSize.small
                }
                ListView {
                    id: hiddenList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: grid.implicitHeight
                    clip: true
                    spacing: 8
                    model: root.hiddenWorkspaces
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: ItemDelegate {
                        id: hiddenEntry
                        required property var modelData
                        required property int index
                        readonly property bool selected: root.selectedIndex === root.count + index
                        readonly property bool current: modelData.name === root.monitor?.specialWorkspace?.name
                        width: hiddenList.width
                        implicitHeight: Math.max(100, workspacePreview.implicitHeight + 20)
                        padding: 10
                        background: Rectangle {
                            radius: 12
                            color: "transparent"
                            border.width: hiddenEntry.selected ? 2 : 1
                            border.color: hiddenEntry.selected ? GlassColors.states.on
                                : Qt.alpha(GlassColors.states.off, hiddenEntry.hovered ? 0.7 : 0.3)
                        }
                        contentItem: RowLayout {
                            spacing: 12
                            OverviewWorkspacePreview {
                                id: workspacePreview
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: implicitHeight
                                workspace: hiddenEntry.modelData
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                StyledText {
                                    Layout.fillWidth: true
                                    text: Navigation.displayName(hiddenEntry.modelData.name)
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    color: hiddenEntry.selected ? GlassColors.textStates.on : GlassColors.foreground
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: hiddenEntry.current ? Translation.tr("Open now")
                                        : hiddenEntry.modelData.windows + " " + Translation.tr(hiddenEntry.modelData.windows === 1 ? "window" : "windows")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: GlassColors.textStates.off
                                }
                            }
                            OverviewMonitorTag {
                                monitorName: hiddenEntry.modelData.monitor ?? ""
                                current: hiddenEntry.current
                            }
                            MaterialSymbol {
                                visible: hiddenEntry.selected
                                text: "keyboard_return"
                                iconSize: 20
                                color: GlassColors.states.on
                            }
                        }
                        onClicked: root.activateHidden(modelData.name)
                    }
                    StyledText {
                        visible: root.hiddenWorkspaces.length === 0
                        anchors { fill: parent; margins: 16 }
                        verticalAlignment: Text.AlignTop
                        text: Translation.tr("No hidden workspaces")
                        color: GlassColors.textStates.off
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: root.searching ? Translation.tr("↑ ↓  Choose result     Enter  Open     Esc  Close")
                : Translation.tr("← ↑ ↓ →  Navigate     Enter  Switch     Tab  Next     • On screen     Type to search")
            color: GlassColors.textStates.off
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }
}
