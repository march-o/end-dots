import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    GlassPanelWindow {
        id: panelWindow
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

        exclusionMode: ExclusionMode.Ignore
        panelName: "wallpaperSelector"
        shown: GlobalStates.wallpaperSelectorOpen
        slideFrom: "top"
        onDismissRequested: GlobalStates.wallpaperSelectorOpen = false
        WlrLayershell.layer: WlrLayer.Overlay

        anchors.top: true
        margins {
            top: Config?.options.bar.vertical ? Appearance.sizes.hyprlandGapsOut : Appearance.sizes.barHeight + Appearance.sizes.hyprlandGapsOut
        }

        implicitHeight: Math.min(690, (screen?.height ?? 800) - margins.top - 24)
        implicitWidth: Math.min(1100, (screen?.width ?? 1200) - 32)

        Loader {
            anchors.fill: parent
            active: panelWindow.visible
            sourceComponent: WallpaperSelectorContent {}
        }
    }

    function toggleWallpaperSelector() {
        if (Config.options.wallpaperSelector.useSystemFileDialog) {
            Wallpapers.openFallbackPicker(Appearance.m3colors.darkmode);
            return;
        }
        GlobalStates.wallpaperSelectorOpen = !GlobalStates.wallpaperSelectorOpen
    }

    IpcHandler {
        target: "wallpaperSelector"

        function toggle(): void {
            root.toggleWallpaperSelector();
        }

        function random(): void {
            Wallpapers.randomFromCurrentFolder();
        }
    }

    GlobalShortcut {
        name: "wallpaperSelectorToggle"
        description: "Toggle wallpaper selector"
        onPressed: {
            root.toggleWallpaperSelector();
        }
    }

    GlobalShortcut {
        name: "wallpaperSelectorRandom"
        description: "Select random wallpaper in current folder"
        onPressed: {
            Wallpapers.randomFromCurrentFolder();
        }
    }
}
