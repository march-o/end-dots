import qs.services
import qs.modules.ii.bar
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

MouseArea {
    id: root
    required property var fileModelData
    property bool keyboardSelected: false
    property bool isDirectory: fileModelData.fileIsDir
    readonly property bool isCurrent: !isDirectory && fileModelData.filePath === Config.options.background.wallpaperPath
    property bool useThumbnail: !isDirectory && Wallpapers.extensions.some(ext => fileModelData.fileName.toLowerCase().endsWith(`.${ext}`))

    property alias colBackground: background.color
    property alias colText: wallpaperItemName.color
    property alias radius: background.radius
    property alias margins: background.anchors.margins
    property alias padding: wallpaperItemColumnLayout.anchors.margins
    margins: Appearance.sizes.wallpaperSelectorItemMargins
    padding: Appearance.sizes.wallpaperSelectorItemPadding

    Accessible.role: Accessible.Button
    Accessible.name: `${fileModelData.title ?? Wallpapers.displayName(fileModelData.filePath, isDirectory)}${isCurrent ? ", " + Translation.tr("Current wallpaper") : ""}`
    Accessible.onPressAction: root.activated()
    signal activated()

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()

    Rectangle {
        id: background
        anchors.fill: parent
        radius: Appearance.rounding.normal
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6 }
            height: 2
            radius: 1
            color: root.colText
            visible: root.keyboardSelected
        }

        ColumnLayout {
            id: wallpaperItemColumnLayout
            anchors.fill: parent
            spacing: 4

            Item {
                id: wallpaperItemImageContainer
                Layout.fillHeight: true
                Layout.fillWidth: true

                Loader {
                    id: thumbnailImageLoader
                    anchors.fill: parent
                    active: root.useThumbnail
                    sourceComponent: ThumbnailImage {
                        id: thumbnailImage
                        generateThumbnail: false
                        sourcePath: fileModelData.filePath

                        cache: false
                        fillMode: Image.PreserveAspectCrop
                        clip: true

                        Connections {
                            target: Wallpapers
                            function onThumbnailGenerated(directory) {
                                if (thumbnailImage.status !== Image.Error) return;
                                if (FileUtils.parentDirectory(thumbnailImage.sourcePath) !== FileUtils.trimFileProtocol(directory)) return;
                                thumbnailImage.source = "";
                                thumbnailImage.source = thumbnailImage.thumbnailPath;
                            }
                            function onThumbnailGeneratedFile(filePath) {
                                if (thumbnailImage.status !== Image.Error) return;
                                if (Qt.resolvedUrl(thumbnailImage.sourcePath) !== Qt.resolvedUrl(filePath)) return;
                                thumbnailImage.source = "";
                                thumbnailImage.source = thumbnailImage.thumbnailPath;
                            }
                        }

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: wallpaperItemImageContainer.width
                                height: wallpaperItemImageContainer.height
                                radius: Appearance.rounding.small
                            }
                        }
                    }
                }

                Rectangle {
                    z: 1
                    visible: root.isCurrent
                    anchors { right: parent.right; top: parent.top; margins: 8 }
                    width: currentLabel.implicitWidth + 18
                    height: currentLabel.implicitHeight + 10
                    radius: height / 2
                    color: BarGlassPalette.glassTint
                    StyledText {
                        id: currentLabel
                        anchors.centerIn: parent
                        text: Translation.tr("Current")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: BarGlassPalette.glassTextTone
                    }
                }

                Loader {
                    id: iconLoader
                    active: !root.useThumbnail
                    anchors.fill: parent
                    sourceComponent: DirectoryIcon {
                        fileModelData: root.fileModelData
                    }
                }
            }

            StyledText {
                id: wallpaperItemName
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10

                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
                text: fileModelData.title ?? Wallpapers.displayName(fileModelData.filePath, root.isDirectory)
            }
        }
    }
}
