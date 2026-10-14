import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.bar
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

GlassPanel {
    id: root
    implicitWidth: 1100
    implicitHeight: 690
    focus: true
    frameInset: Appearance.sizes.elevationMargin
    contentPadding: 16

    function updateThumbnails() {
        const inset = (Appearance.sizes.wallpaperSelectorItemMargins + Appearance.sizes.wallpaperSelectorItemPadding) * 2;
        Wallpapers.generateThumbnail(Images.thumbnailSizeNameForDimensions(grid.cellWidth - inset, grid.cellHeight - inset));
    }

    function activateCurrent() {
        if (grid.currentIndex < 0 || grid.currentIndex >= grid.count) return;
        Wallpapers.select(Wallpapers.galleryModel[grid.currentIndex].filePath);
    }

    function moveSelection(delta) {
        grid.currentIndex = Math.max(0, Math.min(grid.count - 1, grid.currentIndex + delta));
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
        grid.forceActiveFocus();
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            GlobalStates.wallpaperSelectorOpen = false;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activateCurrent();
        } else if (event.key === Qt.Key_Down) {
            root.moveSelection(grid.columns);
        } else if (event.key === Qt.Key_Up) {
            root.moveSelection(-grid.columns);
        } else if (event.key === Qt.Key_Left && !filterField.activeFocus) {
            root.moveSelection(-1);
        } else if (event.key === Qt.Key_Right && !filterField.activeFocus) {
            root.moveSelection(1);
        } else if (event.key === Qt.Key_Slash && !filterField.activeFocus) {
            filterField.forceActiveFocus();
        } else {
            event.accepted = false;
            return;
        }
        event.accepted = true;
    }

    Component.onCompleted: {
        filterField.forceActiveFocus();
        Qt.callLater(root.updateThumbnails);
    }
    Component.onDestruction: Wallpapers.searchQuery = ""

    Connections {
        target: Wallpapers
        function onDirectoryChanged() {
            filterField.text = "";
            grid.currentIndex = 0;
            root.updateThumbnails();
        }
        function onChanged() { GlobalStates.wallpaperSelectorOpen = false; }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            Layout.maximumHeight: 44
            spacing: 12
            MaterialSymbol {
                text: "wallpaper"
                iconSize: 28
                color: root.statePalette.off
            }
            StyledText {
                text: Translation.tr("Wallpapers")
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.DemiBold
            }
            StyledText {
                text: grid.count
                color: root.textStatePalette.off
            }
            Item { Layout.fillWidth: true }
            GlassTextField {
                id: filterField
                Layout.fillHeight: false
                Layout.preferredWidth: Math.min(280, root.contentItem.width * 0.35)
                placeholderText: Translation.tr("Search wallpapers")
                onTextChanged: {
                    Wallpapers.searchQuery = text;
                    grid.currentIndex = 0;
                    grid.positionViewAtBeginning();
                }
            }
            GlassButton {
                implicitWidth: 40
                implicitHeight: 40
                statePalette: root.statePalette
                Accessible.name: Translation.tr("Close wallpaper picker")
                onClicked: GlobalStates.wallpaperSelectorOpen = false
                GlassIcon { text: "close"; iconSize: 24 }
            }
        }

        RowLayout {
            visible: Wallpapers.directory.toString() !== Wallpapers.defaultFolder.toString()
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            Layout.maximumHeight: 40
            GlassButton {
                implicitWidth: 40
                implicitHeight: 40
                statePalette: root.statePalette
                Accessible.name: Translation.tr("Parent folder")
                onClicked: Wallpapers.navigateUp()
                GlassIcon { text: "arrow_back"; iconSize: 24 }
            }
            StyledText {
                Layout.fillWidth: true
                text: Wallpapers.effectiveDirectory
                elide: Text.ElideMiddle
                color: root.textStatePalette.off
            }
            RippleButton {
                text: Translation.tr("All wallpapers")
                onClicked: Wallpapers.setDirectory(Wallpapers.defaultFolder.toString())
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            GridView {
                id: grid
                anchors.fill: parent
                readonly property int columns: Math.max(1, Math.floor(width / 240))
                cellWidth: width / columns
                cellHeight: cellWidth * 9 / 16 + 28
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: false
                currentIndex: 0
                model: Wallpapers.galleryModel
                ScrollBar.vertical: ScrollBar {
                    id: galleryScrollBar
                    policy: ScrollBar.AsNeeded
                    visible: size < 1
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: root.statePalette.off
                        opacity: galleryScrollBar.active ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                }
                onCountChanged: currentIndex = count > 0 ? Math.max(0, Math.min(currentIndex, count - 1)) : -1
                delegate: WallpaperDirectoryItem {
                    required property var modelData
                    required property int index
                    fileModelData: modelData
                    width: grid.cellWidth
                    height: grid.cellHeight
                    colBackground: "transparent"
                    colText: isCurrent
                        ? (containsMouse ? root.textStatePalette.onHover : root.textStatePalette.on)
                        : (containsMouse || (grid.activeFocus && index === grid.currentIndex)
                            ? root.textStatePalette.offHover : root.textStatePalette.off)
                    keyboardSelected: grid.activeFocus && index === grid.currentIndex
                    onActivated: {
                        grid.currentIndex = index;
                        root.activateCurrent();
                    }
                }
            }
            StyledText {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: filterField.text.length > 0
                    ? Translation.tr("No matching wallpapers")
                    : Translation.tr("No wallpapers in this folder")
                color: root.textStatePalette.off
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Click a wallpaper to apply  ·  Arrow keys to browse  ·  Enter to choose  ·  Esc to close")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: root.textStatePalette.off
            wrapMode: Text.WordWrap
        }
    }
}
