#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
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
  mkdir -p "$HOME/.config/zshrc.d"
  rsync -a --delete "$repo_root/dots/.config/zshrc.d/" "$HOME/.config/zshrc.d/"
}

configure_quickshell_shell() {
  local config="$HOME/.config/illogical-impulse/config.json"
  [[ -f "$config" ]] || return 0
  local updated
  updated=$(mktemp)
  jq '.apps.changePassword = "kitty -1 --hold=yes zsh -ic '\''passwd'\''" |
      .apps.update = "kitty -1 --hold=yes zsh -ic '\''pkexec pacman -Syu'\''"' \
    "$config" > "$updated"
  install -m600 "$updated" "$config"
  rm -f "$updated"
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
configure_quickshell_shell
install_zram
install_sddm_config
enable_services

zsh_path=$(command -v zsh)
if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]]; then
  sudo chsh -s "$zsh_path" "$USER"
fi
