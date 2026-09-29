#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_ROOT="$repo_root"
source "$repo_root/sdata/lib/machine-env.sh"
omz_dir="${XDG_DATA_HOME:-$HOME/.local/share}/oh-my-zsh"

sync_git_repo() {
  local url=$1 destination=$2
  if [[ -d "$destination/.git" ]]; then
    git -C "$destination" pull --ff-only
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
  install -Dm755 "$repo_root/sdata/dist-arch/bin/wallpaper-next" "$HOME/.local/bin/wallpaper-next"
  install -Dm755 "$repo_root/sdata/dist-arch/bin/ash-desktop-state" "$HOME/.local/bin/ash-desktop-state"
  install -Dm644 "$repo_root/dots/.config/hypr/custom/execs.lua" "$HOME/.config/hypr/custom/execs.lua"
  install -Dm644 "$repo_root/dots/.config/hypr/custom/general.lua" "$HOME/.config/hypr/custom/general.lua"
  install -Dm644 "$repo_root/dots/.config/hypr/custom/keybinds.lua" "$HOME/.config/hypr/custom/keybinds.lua"
  install -Dm644 "$repo_root/dots/.config/hypr/custom/rules.lua" "$HOME/.config/hypr/custom/rules.lua"
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
  install -Dm644 "$repo_root/dots/.local/share/applications/google-chrome.desktop" \
    "$applications_dir/google-chrome.desktop"
  install -Dm644 "$repo_root/dots/.local/share/applications/google-chrome-work.desktop" \
    "$applications_dir/google-chrome-work.desktop"
  command -v update-desktop-database >/dev/null && update-desktop-database "$applications_dir"
}

install_user_skills() {
  local skills_dir="$HOME/.agents/skills"
  mkdir -p "$skills_dir/quickshell"
  rsync -a --delete "$repo_root/sdata/dist-arch/skills/quickshell/" "$skills_dir/quickshell/"
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
      modules/common/Appearance.qml \
      modules/common/Config.qml \
      modules/common/models/WorkspaceModel.qml \
      modules/common/panels/lock/LockScreen.qml \
      modules/common/panels/lock/LockContext.qml \
      modules/ii/bar/Bar.qml \
      modules/ii/bar/BarContent.qml \
      modules/ii/bar/BarGroup.qml \
      modules/ii/bar/Media.qml \
      modules/ii/bar/Workspaces.qml \
      modules/ii/background/Background.qml \
      modules/ii/lock/Lock.qml \
      modules/ii/lock/LockSurface.qml \
      modules/waffle/lock/WaffleLock.qml \
      services/HyprlandData.qml \
      scripts/colors/applycolor.sh; do
      source="$repo_root/dots/.config/quickshell/ii/$relative"
      target="$quickshell/$relative"
      mode=644
      [[ "$relative" == scripts/* ]] && mode=755
      if [[ -f "$target" ]]; then
        cp "$source" "$target"
        chmod "$mode" "$target"
      else
        install -Dm"$mode" "$source" "$target"
      fi
    done
  fi
  local updated input_file="$config" launch_on_startup=false quickshell_font_scale=1
  [[ -f "$input_file" ]] || input_file=/dev/null
  if [[ "${LAPTOP:-0}" == "1" ]]; then
    launch_on_startup=true
    quickshell_font_scale=1.25
  fi
  updated=$(mktemp)
  jq -n --slurpfile existing "$input_file" \
    --argjson launch_on_startup "$launch_on_startup" \
    --argjson quickshell_font_scale "$quickshell_font_scale" \
    '($existing[0] // {}) |
      .apps.changePassword = "kitty -1 --hold=yes zsh -ic '\''passwd'\''" |
      .apps.update = "kitty -1 --hold=yes zsh -ic '\''pkexec pacman -Syu'\''" |
      .lock.security.passwordless = true |
      .lock.security.unlockKeyring = false |
      .lock.blur.radius = 50 |
      .bar.cornerStyle = 1 |
      if $launch_on_startup then
        .lock.launchOnStartup = true |
        .appearance.fontScale = $quickshell_font_scale
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
      '.tui.alternate_screen = "always" |
       .tui.status_line = ["model-with-reasoning", "context-remaining", "five-hour-limit", "weekly-limit", "git-branch", "task-progress"] |
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

install_zsh_plugins
install_user_config
install_app_launchers
install_user_skills
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
