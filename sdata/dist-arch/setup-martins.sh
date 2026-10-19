#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_ROOT="$repo_root"
source "$repo_root/sdata/lib/machine-env.sh"
source "$repo_root/sdata/dist-arch/lib/device-profile.sh"
omz_dir="${XDG_DATA_HOME:-$HOME/.local/share}/oh-my-zsh"

sync_git_repo() {
  local url=$1 destination=$2
  if [[ -d "$destination/.git" ]]; then
    if [[ -n "$(git -C "$destination" status --porcelain)" ]]; then
      printf 'Keeping local changes in %s; skipping its update.\n' "$destination" >&2
    else
      git -C "$destination" pull --ff-only
    fi
  else
    git clone --depth 1 "$url" "$destination"
  fi
}

install_zsh_plugins() {
  mkdir -p "$(dirname "$omz_dir")"
  sync_git_repo https://github.com/ohmyzsh/ohmyzsh.git "$omz_dir"
  sync_git_repo https://github.com/romkatv/powerlevel10k.git "$omz_dir/custom/themes/powerlevel10k"
  sync_git_repo https://github.com/Aloxaf/fzf-tab.git "$omz_dir/custom/plugins/fzf-tab"
  sync_git_repo https://github.com/zsh-users/zsh-autosuggestions.git "$omz_dir/custom/plugins/zsh-autosuggestions"
  sync_git_repo https://github.com/zsh-users/zsh-syntax-highlighting.git "$omz_dir/custom/plugins/zsh-syntax-highlighting"
}

install_user_config() {
  install -Dm644 "$repo_root/dots/.zshrc" "$HOME/.zshrc"
  install -Dm644 "$repo_root/dots/.p10k.zsh" "$HOME/.p10k.zsh"
  install -Dm644 "$repo_root/dots/.config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
  install -Dm644 "$repo_root/dots/.config/kitty/ssh.conf" "$HOME/.config/kitty/ssh.conf"
  sed -i -E "s/^font_size[[:space:]]+[0-9.]+$/font_size $DEVICE_KITTY_FONT_SIZE/" "$HOME/.config/kitty/kitty.conf"
  install -Dm644 "$repo_root/sdata/dist-arch/config/swappy.conf" "$HOME/.config/swappy/config"
  install -Dm755 "$repo_root/sdata/dist-arch/bin/laptop-monitor" "$HOME/.local/bin/laptop-monitor"
  if [[ ! -f "$HOME/.config/laptop-monitor/config.json" ]]; then
    install -Dm644 "$repo_root/sdata/dist-arch/config/laptop-monitor.json" "$HOME/.config/laptop-monitor/config.json"
  fi
  "$HOME/.local/bin/laptop-monitor" configure-host
  install -Dm755 "$repo_root/sdata/dist-arch/bin/wallpaper-next" "$HOME/.local/bin/wallpaper-next"
  install -Dm755 "$repo_root/sdata/dist-arch/bin/ash-desktop-state" "$HOME/.local/bin/ash-desktop-state"
  install -Dm644 "$repo_root/dots/.config/hypr/custom/execs.lua" "$HOME/.config/hypr/custom/execs.lua"
  install -Dm644 "$repo_root/dots/.config/hypr/custom/general.lua" "$HOME/.config/hypr/custom/general.lua"
  install -Dm644 "$repo_root/dots/.config/hypr/custom/keybinds.lua" "$HOME/.config/hypr/custom/keybinds.lua"
  install -Dm644 "$repo_root/dots/.config/hypr/custom/rules.lua" "$HOME/.config/hypr/custom/rules.lua"
  install -Dm644 "$repo_root/dots/.config/hypr/custom/glass.lua" "$HOME/.config/hypr/custom/glass.lua"
  install -Dm644 "$repo_root/dots/.config/hypr/hyprland/variables.lua" "$HOME/.config/hypr/hyprland/variables.lua"
  install -Dm644 "$repo_root/dots/.config/hypr/hyprland/env.lua" "$HOME/.config/hypr/hyprland/env.lua"
  if [[ "${LAPTOP:-0}" == "0" ]]; then
    install -Dm644 "$repo_root/sdata/dist-arch/config/hypridle-pc.conf" "$HOME/.config/hypr/hypridle.conf"
  else
    install -Dm644 "$repo_root/dots/.config/hypr/hypridle.conf" "$HOME/.config/hypr/hypridle.conf"
    install -Dm755 "$repo_root/dots/.config/hypr/custom/scripts/reset-touchpad.sh" \
      "$HOME/.config/hypr/custom/scripts/reset-touchpad.sh"
  fi
  mkdir -p "$HOME/.config/zshrc.d"
  rsync -a --delete "$repo_root/dots/.config/zshrc.d/" "$HOME/.config/zshrc.d/"
}

install_app_launchers() {
  local applications_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  install -Dm755 "$repo_root/dots/.local/bin/chrome-profile-launch" "$HOME/.local/bin/chrome-profile-launch"
  install -Dm644 "$repo_root/dots/.local/share/applications/google-chrome.desktop" \
    "$applications_dir/google-chrome.desktop"
  install -Dm644 "$repo_root/dots/.local/share/applications/google-chrome-work.desktop" \
    "$applications_dir/google-chrome-work.desktop"
  command -v update-desktop-database >/dev/null && update-desktop-database "$applications_dir"
}

configure_quickshell_shell() {
  local config="$HOME/.config/illogical-impulse/config.json"
  if [[ ! -f "$config" && "${LAPTOP:-0}" != "1" ]]; then
    return 0
  fi
  local quickshell="$HOME/.config/quickshell/ii"
  if [[ -d "$quickshell" ]]; then
    local relative mode source target
    for relative in \
      modules/common/GlassColors.qml \
      modules/common/widgets/GlassPanel.qml \
      modules/common/widgets/GlassPanelWindow.qml \
      modules/common/widgets/PanelSlide.qml \
      modules/common/widgets/GlassTextField.qml \
      assets/wallpaper-titles.json \
      modules/common/Appearance.qml \
      modules/common/Config.qml \
      modules/common/utils/TempScreenshotProcess.qml \
      modules/common/utils/ScreenshotAction.qml \
      modules/common/models/WorkspaceModel.qml \
      modules/common/panels/lock/LockScreen.qml \
      modules/common/panels/lock/LockContext.qml \
      modules/common/widgets/DialogButton.qml \
      modules/common/widgets/GroupButton.qml \
      modules/common/widgets/MaterialShapeWrappedMaterialSymbol.qml \
      modules/common/widgets/NotificationItem.qml \
      modules/common/widgets/PagePlaceholder.qml \
      modules/common/widgets/RippleButton.qml \
      modules/common/widgets/StyledSlider.qml \
      modules/common/widgets/StyledText.qml \
      modules/common/widgets/StyledTextArea.qml \
      modules/common/widgets/WindowDialog.qml \
      modules/common/widgets/WindowDialogTitle.qml \
      modules/ii/sidebarRight/BottomWidgetGroup.qml \
      modules/ii/sidebarRight/CenterWidgetGroup.qml \
      modules/ii/sidebarRight/QuickSliders.qml \
      modules/ii/sidebarRight/SidebarRightContent.qml \
      modules/ii/sidebarRight/SidebarRight.qml \
      modules/ii/sidebarRight/bluetoothDevices/BluetoothDeviceItem.qml \
      modules/ii/sidebarRight/calendar/CalendarDayButton.qml \
      modules/ii/sidebarRight/calendar/CalendarHeaderButton.qml \
      modules/ii/sidebarRight/calendar/CalendarWidget.qml \
      modules/ii/sidebarRight/notifications/NotificationStatusButton.qml \
      modules/ii/sidebarRight/pomodoro/PomodoroTimer.qml \
      modules/ii/sidebarRight/pomodoro/Stopwatch.qml \
      modules/ii/sidebarRight/quickToggles/AbstractQuickPanel.qml \
      modules/ii/sidebarRight/quickToggles/AndroidQuickPanel.qml \
      modules/ii/sidebarRight/quickToggles/ClassicQuickPanel.qml \
      modules/ii/sidebarRight/quickToggles/androidStyle/AndroidQuickToggleButton.qml \
      modules/ii/sidebarRight/quickToggles/classicStyle/CloudflareWarp.qml \
      modules/ii/sidebarRight/quickToggles/classicStyle/QuickToggleButton.qml \
      modules/ii/sidebarRight/todo/TaskList.qml \
      modules/ii/sidebarRight/todo/TodoItemActionButton.qml \
      modules/ii/sidebarRight/todo/TodoWidget.qml \
      modules/ii/sidebarRight/volumeMixer/AudioDeviceSelectorButton.qml \
      modules/ii/sidebarRight/volumeMixer/VolumeMixerEntry.qml \
      modules/ii/sidebarRight/wifiNetworks/WifiNetworkItem.qml \
      modules/common/ScopedColors.qml \
      modules/common/widgets/NotificationAppIcon.qml \
      modules/common/widgets/NotificationActionButton.qml \
      modules/common/widgets/NotificationGroupExpandButton.qml \
      modules/common/widgets/NotificationGroup.qml \
      modules/ii/bar/Bar.qml \
      modules/ii/bar/BarContent.qml \
      modules/ii/bar/BarGroup.qml \
      modules/ii/bar/BarGeometry.qml \
      modules/ii/bar/GlassWallpaperBackdrop.qml \
      modules/ii/bar/BarGlassIsland.qml \
      modules/ii/bar/BarGlassPalette.qml \
      modules/ii/bar/GlassIcon.qml \
      modules/ii/bar/GlassButton.qml \
      modules/ii/bar/LaptopMonitorButton.qml \
      modules/ii/bar/WallpaperIconColor.qml \
      modules/ii/bar/ActiveWindow.qml \
      modules/ii/bar/LeftTimeWidget.qml \
      modules/ii/bar/Media.qml \
      modules/ii/bar/MediaCard.qml \
      modules/ii/bar/MediaProgress.qml \
      modules/ii/bar/MediaVolumeSlider.qml \
      modules/ii/bar/MediaVolumeControl.qml \
      modules/ii/overview/Overview.qml \
      modules/ii/overview/OverviewContent.qml \
      modules/ii/overview/OverviewMonitorTag.qml \
      modules/ii/overview/OverviewWorkspacePreview.qml \
      modules/ii/overview/OverviewWidget.qml \
      modules/ii/overview/OverviewWindow.qml \
      modules/ii/overview/OverviewNavigation.js \
      modules/ii/overview/SearchWidget.qml \
      modules/ii/overview/SearchBar.qml \
      modules/ii/overview/SearchItem.qml \
      scripts/cava/media_card_config.txt \
      scripts/media/spotify-connect.py \
      scripts/media/spotify-authorize.py \
      scripts/media/sample-card-backdrop.py \
      modules/ii/bar/Resource.qml \
      modules/ii/bar/Resources.qml \
      modules/ii/bar/SysTray.qml \
      modules/ii/bar/SysTrayItem.qml \
      modules/ii/bar/ScrollHint.qml \
      modules/ii/bar/NotificationUnreadCount.qml \
      modules/ii/bar/BatteryIndicator.qml \
      modules/ii/bar/weather/WeatherBar.qml \
      modules/ii/bar/UtilButtons.qml \
      modules/ii/bar/Workspaces.qml \
      modules/ii/background/Background.qml \
      modules/ii/notificationPopup/NotificationPopup.qml \
      modules/ii/regionSelector/RegionSelection.qml \
      modules/ii/regionSelector/CursorGuide.qml \
      modules/ii/sidebarLeft/SidebarLeft.qml \
      modules/ii/sidebarLeft/AiChat.qml \
      modules/ii/sidebarLeft/aiChat/MessageTextBlock.qml \
      modules/settings/BarConfig.qml \
      modules/ii/lock/Lock.qml \
      modules/ii/lock/LockSurface.qml \
      modules/ii/wallpaperSelector/WallpaperSelector.qml \
      modules/ii/wallpaperSelector/WallpaperSelectorContent.qml \
      modules/ii/wallpaperSelector/WallpaperDirectoryItem.qml \
      modules/waffle/lock/WaffleLock.qml \
      services/WallpaperScene.qml \
      services/HyprlandData.qml \
      services/Ai.qml \
      services/ai/GeminiApiStrategy.qml \
      services/ai/MistralApiStrategy.qml \
      services/Wallpapers.qml \
      services/WireGuard.qml \
      scripts/images/sample-bar-wallpaper.py \
      scripts/colors/applycolor.sh \
      scripts/colors/terminal/sequences.txt; do
      source="$repo_root/dots/.config/quickshell/ii/$relative"
      target="$quickshell/$relative"
      mode=644
      [[ "$relative" == scripts/* && "$relative" != *.txt ]] && mode=755
      if [[ -f "$target" ]]; then
        cp "$source" "$target"
        chmod "$mode" "$target"
      else
        install -Dm"$mode" "$source" "$target"
      fi
    done
    # Palette consumers now share modules/common/GlassColors.qml.
    rm -f "$quickshell/modules/ii/sidebarRight/SidebarColors.qml"
  fi
  local updated input_file="$config" launch_on_startup=false
  [[ -f "$input_file" ]] || input_file=/dev/null
  if [[ "${LAPTOP:-0}" == "1" ]]; then
    launch_on_startup=true
  fi
  updated=$(mktemp)
  jq -n --slurpfile existing "$input_file" \
    --argjson launch_on_startup "$launch_on_startup" \
    --argjson quickshell_font_scale "$DEVICE_QUICKSHELL_FONT_SCALE" \
    '($existing[0] // {}) |
      .apps.changePassword = "kitty -1 --hold=yes zsh -ic '\''passwd'\''" |
      .apps.update = "kitty -1 --hold=yes zsh -ic '\''pkexec pacman -Syu'\''" |
      .lock.security.passwordless = true |
      .lock.security.unlockKeyring = false |
      .lock.blur.radius = 50 |
      .bar.cornerStyle = 1 |
      .bar.workspaces.shown = 12 |
      .overview.rows = 3 |
      .overview.columns = 4 |
      .overview.orderRightLeft = false |
      .overview.orderBottomUp = false |
      .background.widgets.clock.style = "digital" |
      .background.widgets.clock.styleLocked = "digital" |
      .appearance.fontScale = $quickshell_font_scale |
      if $launch_on_startup then
        .lock.launchOnStartup = true
      else . end' \
    > "$updated"
  install -Dm600 "$updated" "$config"
  rm -f "$updated"
}

configure_codex() {
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  local config="$codex_home/config.toml"
  mkdir -p "$codex_home"
  local codex_agents="$repo_root/sdata/dist-arch/config/codex-AGENTS.md"
  if [[ "${LAPTOP:-0}" == "1" ]]; then
    codex_agents="$repo_root/sdata/dist-arch/config/codex-AGENTS-laptop.md"
  fi
  install -Dm644 "$codex_agents" "$codex_home/AGENTS.md"
  if [[ -f "$config" ]]; then
    yq -p=toml -o=toml -i \
      '.model = "gpt-6.1-sol" |
       .model_reasoning_effort = "high" |
       .tui.alternate_screen = "always" |
       .tui.status_line = ["model-with-reasoning", "current-dir", "git-branch", "git-diff", "context-remaining", "five-hour-limit", "weekly-limit", "task-progress"] |
       .tui.status_line_use_colors = true |
       .tui.keymap.global.open_transcript = ["ctrl-t", "page-up"]' "$config"
  else
    install -m600 "$repo_root/sdata/dist-arch/config/codex.toml" "$config"
  fi
}

install_zram() {
  sudo install -Dm644 "$repo_root/sdata/dist-arch/config/zram-generator.conf" \
    /etc/systemd/zram-generator.conf
  sudo systemctl daemon-reload
  local expected_bytes=$((8 * 1024 * 1024 * 1024))
  local current_bytes=0
  [[ -e /sys/block/zram0/disksize ]] && current_bytes=$(</sys/block/zram0/disksize)
  if (( current_bytes != 0 && current_bytes != expected_bytes )); then
    if [[ "$(swapon --show=NAME,USED --bytes --noheadings | awk '$1 == "/dev/zram0" {print $2}')" == 0 ]]; then
      sudo systemctl restart systemd-zram-setup@zram0.service
    else
      echo "zram0 is in use; the new 8 GiB size will apply after reboot." >&2
    fi
  elif ! swapon --show=NAME --noheadings | grep -qx '/dev/zram0'; then
    sudo systemctl start systemd-zram-setup@zram0.service
  fi
}

install_sddm_config() {
  sudo install -Dm644 "$repo_root/sdata/dist-arch/config/sddm-theme.conf" \
    /etc/sddm.conf.d/10-ii-material.conf

  # The greeter needs traversal access to the Material colors and wallpaper path.
  local generated="$HOME/.local/state/quickshell/user/generated"
  sudo setfacl -m "u:sddm:x" "$HOME"
  if [[ -d "$generated" ]]; then
    sudo setfacl -m "u:sddm:x" "$HOME/.local" "$HOME/.local/state" \
      "$HOME/.local/state/quickshell" "$HOME/.local/state/quickshell/user" "$generated"
    [[ -f "$generated/colors.json" ]] && sudo setfacl -m "u:sddm:r" "$generated/colors.json"
    if [[ -f "$generated/wallpaper/path.txt" ]]; then
      sudo setfacl -m "u:sddm:x" "$generated/wallpaper"
      sudo setfacl -m "u:sddm:r" "$generated/wallpaper/path.txt"
      local wallpaper
      wallpaper=$(<"$generated/wallpaper/path.txt")
      if [[ -f "$wallpaper" ]]; then
        sudo setfacl -m "u:sddm:x" "$(dirname "$wallpaper")"
        sudo setfacl -m "u:sddm:r" "$wallpaper"
      fi
    fi
  fi
}

enable_services() {
  sudo systemctl enable --now sshd.service
}

sudo pacman -S --needed --noconfirm wireguard-tools python-pillow

install_zsh_plugins
install_user_config
install_app_launchers
bash "$repo_root/sdata/dist-arch/install-chrome-control.sh"
configure_quickshell_shell
configure_codex
install_zram
install_sddm_config
enable_services

zsh_path=$(command -v zsh)
if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]]; then
  sudo chsh -s "$zsh_path" "$USER"
fi
