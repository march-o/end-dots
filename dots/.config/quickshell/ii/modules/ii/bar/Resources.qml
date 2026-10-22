import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell
import QtQuick.Layouts

MouseArea {
    id: root
    objectName: "systemStats"
    property bool alwaysShowAllResources: false // Kept for compact-screen callers.
    property bool morphEnabled: false
    property bool expanded: false
    property bool keyboardMode: false
    property real expansionProgress: expanded ? 1 : 0
    readonly property bool presented: morphEnabled && (expanded || expansionProgress > 0)
    readonly property real compactWidth: 284 * Math.max(1, Config.options.appearance.fontScale)
    readonly property real expandedWidth: Math.min(610 * Math.max(1, Config.options.appearance.fontScale),
        (root.QsWindow.window?.screen?.width ?? 800) - 16)
    readonly property real maximumExpandedHeight: Math.max(Appearance.sizes.baseBarHeight,
        Math.min(760 * Math.max(1, Config.options.appearance.fontScale),
            (root.QsWindow.window?.screen?.height ?? 900) - Appearance.sizes.barHeight - 24))
    property real expandedHeight: Math.min(maximumExpandedHeight, detailsLoader.item?.implicitHeight ?? 240)
    readonly property var expandedContent: detailsLoader.item
    property bool samplingRegistered: false
    property var focusWindow: null
    implicitWidth: compactWidth
    implicitHeight: Appearance.sizes.baseBarHeight
    clip: morphEnabled
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "CPU and memory. Expand system statistics"
    Accessible.onPressAction: root.toggle(true)
    onClicked: { if (!morphEnabled) root.toggle(); else if (!expanded) root.openCard(); }
    Keys.onReturnPressed: root.toggle(true)
    Keys.onSpacePressed: root.toggle(true)
    Keys.onEscapePressed: root.dismiss()
    Behavior on expansionProgress { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    Behavior on expandedHeight { enabled: root.presented; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    function updateFocusGrab() {
        if (morphEnabled && keyboardMode && expanded && root.QsWindow.window?.backingWindowVisible) {
            focusWindow = root.QsWindow.window;
            GlobalFocusGrab.addDismissable(focusWindow);
        } else if (focusWindow) {
            GlobalFocusGrab.removeDismissable(focusWindow);
            focusWindow = null;
        }
    }
    function openCard(useKeyboard = false) {
        if (!morphEnabled) { if (!popupLoader.item?.opened) popupLoader.item?.toggle(useKeyboard); return; }
        openDelay.stop(); closeDelay.stop();
        keyboardMode = useKeyboard;
        expanded = true;
        if (useKeyboard) Qt.callLater(() => { if (root.expanded) detailsLoader.item?.forceActiveFocus(); });
    }
    function dismiss() {
        if (!morphEnabled) { popupLoader.item?.dismiss(); return; }
        openDelay.stop(); closeDelay.stop();
        expanded = false;
        keyboardMode = false;
    }
    function toggle(useKeyboard = false) {
        if (!morphEnabled) { popupLoader.item?.toggle(useKeyboard); return; }
        if (expanded) dismiss(); else openCard(useKeyboard);
    }
    onExpandedChanged: { if (!expanded) keyboardMode = false; updateFocusGrab(); }
    onKeyboardModeChanged: updateFocusGrab()
    onContainsMouseChanged: {
        if (!morphEnabled) return;
        if (containsMouse) { closeDelay.stop(); if (!expanded) openDelay.restart(); }
        else { openDelay.stop(); closeDelay.restart(); }
    }
    onPresentedChanged: {
        if (presented === samplingRegistered) return;
        samplingRegistered = presented;
        SystemStats.hoverUsers = Math.max(0, SystemStats.hoverUsers + (presented ? 1 : -1));
    }
    Component.onDestruction: {
        if (samplingRegistered) SystemStats.hoverUsers = Math.max(0, SystemStats.hoverUsers - 1);
        if (focusWindow) GlobalFocusGrab.removeDismissable(focusWindow);
    }
    Connections { target: GlobalFocusGrab; function onDismissed() { if (root.morphEnabled) root.dismiss(); } }
    Timer { id: openDelay; interval: 180; onTriggered: if (root.containsMouse) root.openCard() }
    Timer { id: closeDelay; interval: 350; onTriggered: if (!root.containsMouse && !expandedHover.hovered && !root.keyboardMode) root.dismiss() }
    HoverHandler {
        id: expandedHover
        enabled: root.presented
        onHoveredChanged: {
            if (hovered) { closeDelay.stop(); root.expanded = true; }
            else closeDelay.restart();
        }
    }

    Item {
        id: compactFace
        width: root.compactWidth
        height: Appearance.sizes.baseBarHeight
        x: (root.width - width) / 2
        y: Config.options.bar.bottom && root.morphEnabled ? root.height - height : 0
        opacity: Math.max(0, 1 - root.expansionProgress * 2)

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
                    width: compactFace.width / 2
                    height: compactFace.height
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
    }
    Loader {
        id: detailsLoader
        active: root.presented
        width: root.expandedWidth
        height: root.expandedHeight
        x: (root.width - width) / 2
        y: Config.options.bar.bottom ? root.height - height : 0
        opacity: Math.max(0, (root.expansionProgress - 0.35) / 0.65)
        scale: Math.min(1, root.width / root.expandedWidth)
        transformOrigin: Config.options.bar.bottom ? Item.Bottom : Item.Top
        enabled: root.expanded
        onLoaded: if (root.keyboardMode) Qt.callLater(() => { if (root.expanded) detailsLoader.item?.forceActiveFocus(); })
        sourceComponent: SystemStatsContent {
            drawSurface: false
            layerNamespace: "quickshell:bar"
            Keys.onEscapePressed: root.dismiss()
        }
    }
    Loader {
        id: popupLoader
        active: !root.morphEnabled
        sourceComponent: ResourcesPopup { hoverTarget: root }
    }
}
