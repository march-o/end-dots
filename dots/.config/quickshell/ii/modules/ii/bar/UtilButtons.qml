import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Item {
    id: root
    readonly property var statePalette: localPalette.statePalette
    readonly property color iconColor: localPalette.iconColor
    WallpaperIconColor { id: localPalette; target: root; rightPadding: 40 }

    property bool borderless: Config.options.bar.borderless
    implicitWidth: rowLayout.implicitWidth
    implicitHeight: BarGeometry.buttonSize

    component UtilityButton: GlassButton {
        statePalette: root.statePalette
    }

    RowLayout {
        id: rowLayout

        spacing: BarGeometry.spacing
        anchors.centerIn: parent

        Loader {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: BarGeometry.buttonSize
            Layout.preferredHeight: BarGeometry.buttonSize
            active: Config.options.bar.utilButtons.showScreenSnip
            visible: Config.options.bar.utilButtons.showScreenSnip
            sourceComponent: UtilityButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"]);
                GlassIcon {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1
                    text: "screenshot_region"
                    iconSize: BarGeometry.iconSize
                }
            }
        }

        Loader {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: BarGeometry.buttonSize
            Layout.preferredHeight: BarGeometry.buttonSize
            active: Config.options.bar.utilButtons.showScreenRecord
            visible: Config.options.bar.utilButtons.showScreenRecord
            sourceComponent: UtilityButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Quickshell.execDetached([Directories.recordScriptPath])
                GlassIcon {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1
                    text: "videocam"
                    iconSize: BarGeometry.iconSize
                }
            }
        }

        Loader {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: BarGeometry.buttonSize
            Layout.preferredHeight: BarGeometry.buttonSize
            active: Config.options.bar.utilButtons.showColorPicker
            visible: Config.options.bar.utilButtons.showColorPicker
            sourceComponent: UtilityButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Quickshell.execDetached(["hyprpicker", "-a"])
                GlassIcon {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1
                    text: "colorize"
                    iconSize: BarGeometry.iconSize
                }
            }
        }

        Item {
            implicitWidth: wireGuardButton.implicitWidth
            implicitHeight: wireGuardButton.implicitHeight
            Layout.alignment: Qt.AlignVCenter

            UtilityButton {
                id: wireGuardButton
                anchors.centerIn: parent
                toggled: WireGuard.active
                onClicked: WireGuard.toggle()
                GlassIcon {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: WireGuard.active ? 1 : 0
                    text: "vpn_lock"
                    iconSize: BarGeometry.iconSize
                    opacity: WireGuard.busy ? 0.5 : 1
                }
            }

            PopupToolTip {
                extraVisibleCondition: wireGuardButton.hovered
                anchorEdges: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
                text: WireGuard.statusText
            }
        }

        Item {
            implicitWidth: lockScreenButton.implicitWidth
            implicitHeight: lockScreenButton.implicitHeight
            Layout.alignment: Qt.AlignVCenter

            UtilityButton {
                id: lockScreenButton
                anchors.centerIn: parent
                onClicked: Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "lock", "activateAndTurnOffScreen"])
                GlassIcon {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: "tv_off"
                    iconSize: BarGeometry.iconSize
                }
            }

            StyledToolTip {
                extraVisibleCondition: lockScreenButton.hovered
                text: Translation.tr("Lock and turn off screen")
            }
        }

        Loader {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: BarGeometry.buttonSize
            Layout.preferredHeight: BarGeometry.buttonSize
            active: Config.options.bar.utilButtons.showMicToggle
            visible: Config.options.bar.utilButtons.showMicToggle
            sourceComponent: UtilityButton {
                Layout.alignment: Qt.AlignVCenter
                toggled: !(Pipewire.defaultAudioSource?.audio?.muted ?? true)
                onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_SOURCE@", "toggle"])
                GlassIcon {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: Pipewire.defaultAudioSource?.audio?.muted ? "mic_off" : "mic"
                    iconSize: BarGeometry.iconSize
                }
            }
        }

        Loader {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: BarGeometry.buttonSize
            Layout.preferredHeight: BarGeometry.buttonSize
            active: Config.options.bar.utilButtons.showDarkModeToggle
            visible: Config.options.bar.utilButtons.showDarkModeToggle
            sourceComponent: UtilityButton {
                Layout.alignment: Qt.AlignVCenter
                toggled: Appearance.m3colors.darkmode
                onClicked: event => {
                    if (Appearance.m3colors.darkmode) {
                        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode light --noswitch`])
                    } else {
                        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode dark --noswitch`])
                    }
                }
                GlassIcon {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: Appearance.m3colors.darkmode ? "light_mode" : "dark_mode"
                    iconSize: BarGeometry.iconSize
                }
            }
        }

        Loader {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: BarGeometry.buttonSize
            Layout.preferredHeight: BarGeometry.buttonSize
            active: Config.options.bar.utilButtons.showPerformanceProfileToggle
            visible: Config.options.bar.utilButtons.showPerformanceProfileToggle
            sourceComponent: UtilityButton {
                Layout.alignment: Qt.AlignVCenter
                toggled: PowerProfiles.profile === PowerProfile.Performance
                onClicked: event => {
                    if (PowerProfiles.hasPerformanceProfile) {
                        switch(PowerProfiles.profile) {
                            case PowerProfile.PowerSaver: PowerProfiles.profile = PowerProfile.Balanced
                            break;
                            case PowerProfile.Balanced: PowerProfiles.profile = PowerProfile.Performance
                            break;
                            case PowerProfile.Performance: PowerProfiles.profile = PowerProfile.PowerSaver
                            break;
                        }
                    } else {
                        PowerProfiles.profile = PowerProfiles.profile == PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced
                    }
                }
                GlassIcon {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: switch(PowerProfiles.profile) {
                        case PowerProfile.PowerSaver: return "energy_savings_leaf"
                        case PowerProfile.Balanced: return "airwave"
                        case PowerProfile.Performance: return "local_fire_department"
                    }
                    iconSize: BarGeometry.iconSize
                }
            }
        }
    }
}
