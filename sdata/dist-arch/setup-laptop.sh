#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_ROOT="$repo_root"
source "$repo_root/sdata/lib/machine-env.sh"

if [[ "${LAPTOP:-0}" != "1" ]]; then
  exit 0
fi

# Shared laptop UI scale for GTK/Chrome and ChatGPT.
laptop_ui_scale=$(<"$repo_root/sdata/dist-arch/config/laptop-ui-scale")

configure_laptop_fonts() {
  # Keep the desktop layout unchanged while making application text easier to
  # read on the laptop's higher-density display.
  gsettings set org.gnome.desktop.interface text-scaling-factor "$laptop_ui_scale"

  kwriteconfig6 --notify --file kdeglobals --group General --key font \
    'Google Sans Flex,15,-1,5,500,0,0,0,0,0,0,0,0,0,0,1,Medium'
  kwriteconfig6 --notify --file kdeglobals --group General --key fixed \
    'JetBrainsMono Nerd Font,15,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
  kwriteconfig6 --notify --file kdeglobals --group General --key menuFont \
    'Google Sans Flex,14,-1,5,500,0,0,0,0,0,0,0,0,0,0,1,Medium'
  kwriteconfig6 --notify --file kdeglobals --group General --key smallestReadableFont \
    'Google Sans Flex,13,-1,5,500,0,0,0,0,0,0,0,0,0,0,1,Medium'
  kwriteconfig6 --notify --file kdeglobals --group General --key toolBarFont \
    'Google Sans Flex,14,-1,5,500,0,0,0,0,0,0,0,0,0,0,1,Medium'
  kwriteconfig6 --notify --file kdeglobals --group WM --key activeFont \
    'Google Sans Flex,14,-1,5,500,0,0,0,0,0,0,0,0,0,0,1,Medium'
}

configure_laptop_fonts

# These applications use their own sizing instead of the GTK/KDE font roles.
kitty_config="$HOME/.config/kitty/kitty.conf"
if [[ -f "$kitty_config" ]]; then
  sed -i -E 's/^font_size[[:space:]]+[0-9.]+$/font_size 14.0/' "$kitty_config"
fi
chatgpt_launcher="${XDG_DATA_HOME:-$HOME/.local/share}/applications/chatgpt.desktop"
install -Dm644 "$repo_root/sdata/dist-arch/config/chatgpt.desktop.in" \
  "$chatgpt_launcher"
sed -i "s/@LAPTOP_UI_SCALE@/$laptop_ui_scale/" "$chatgpt_launcher"

# Read by custom/general.lua so the Latvian Right Alt layer survives logins.
install -Dm644 "$repo_root/sdata/dist-arch/config/laptop-keyboard" \
  "$HOME/.config/hypr/.laptop-keyboard"

# Boot directly into Hyprland; QuickShell shows its passwordless lock overlay.
# Enable for the next boot without replacing the current live session.
sudo install -Dm644 "$repo_root/sdata/dist-arch/config/sddm-autologin-laptop.conf" \
  /etc/sddm.conf.d/20-laptop-autologin.conf
sudo systemctl enable sddm.service

sudo pacman -S --needed --noconfirm keyd
sudo install -Dm644 \
  "$repo_root/sdata/dist-arch/config/keyd/default.conf" \
  /etc/keyd/default.conf

if [[ -d /run/systemd/system ]]; then
  sudo systemctl enable --now keyd
else
  echo "keyd was installed and configured, but this init system has no automatic keyd service setup." >&2
fi
