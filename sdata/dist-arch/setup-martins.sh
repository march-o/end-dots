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
  install -Dm755 "$repo_root/dots/.local/bin/deskctl" "$HOME/.local/bin/deskctl"
  install -Dm755 "$repo_root/sdata/dist-arch/bin/wallpaper-next" "$HOME/.local/bin/wallpaper-next"
  install -Dm644 "$repo_root/dots/.config/hypr/custom/execs.lua" "$HOME/.config/hypr/custom/execs.lua"
  install -Dm644 "$repo_root/dots/.config/hypr/custom/general.lua" "$HOME/.config/hypr/custom/general.lua"
  install -Dm644 "$repo_root/dots/.config/hypr/custom/keybinds.lua" "$HOME/.config/hypr/custom/keybinds.lua"
  install -Dm644 "$repo_root/dots/.config/hypr/custom/rules.lua" "$HOME/.config/hypr/custom/rules.lua"
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
  local skill_dir="$HOME/.agents/skills/desktop-control"
  mkdir -p "$skill_dir"
  rsync -a --delete "$repo_root/sdata/dist-arch/skills/desktop-control/" "$skill_dir/"
}

configure_quickshell_shell() {
  local config="$HOME/.config/illogical-impulse/config.json"
  [[ -f "$config" ]] || return 0
  local quickshell="$HOME/.config/quickshell/ii"
  if [[ -d "$quickshell" ]]; then
    install -Dm644 "$repo_root/dots/.config/quickshell/ii/modules/common/Config.qml" \
      "$quickshell/modules/common/Config.qml"
    install -Dm644 "$repo_root/dots/.config/quickshell/ii/modules/common/panels/lock/LockContext.qml" \
      "$quickshell/modules/common/panels/lock/LockContext.qml"
    install -Dm644 "$repo_root/dots/.config/quickshell/ii/modules/ii/lock/LockSurface.qml" \
      "$quickshell/modules/ii/lock/LockSurface.qml"
    install -Dm644 "$repo_root/dots/.config/quickshell/ii/modules/waffle/lock/WaffleLock.qml" \
      "$quickshell/modules/waffle/lock/WaffleLock.qml"
    install -Dm755 "$repo_root/dots/.config/quickshell/ii/scripts/colors/applycolor.sh" \
      "$quickshell/scripts/colors/applycolor.sh"
  fi
  local updated
  updated=$(mktemp)
  jq '.apps.changePassword = "kitty -1 --hold=yes zsh -ic '\''passwd'\''" |
      .apps.update = "kitty -1 --hold=yes zsh -ic '\''pkexec pacman -Syu'\''" |
      .lock.security.passwordless = true |
      .lock.security.unlockKeyring = false' \
    "$config" > "$updated"
  install -m600 "$updated" "$config"
  rm -f "$updated"
}

configure_codex() {
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  local config="$codex_home/config.toml"
  mkdir -p "$codex_home"
  install -Dm644 "$repo_root/sdata/dist-arch/config/codex-AGENTS.md" "$codex_home/AGENTS.md"
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
configure_quickshell_shell
configure_codex
install_zram
install_sddm_config
enable_services

zsh_path=$(command -v zsh)
if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]]; then
  sudo chsh -s "$zsh_path" "$USER"
fi
