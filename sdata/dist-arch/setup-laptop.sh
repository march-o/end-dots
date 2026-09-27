#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_ROOT="$repo_root"
source "$repo_root/sdata/lib/machine-env.sh"

if [[ "${LAPTOP:-0}" != "1" ]]; then
  exit 0
fi

configure_laptop_fonts() {
  # Keep the desktop layout unchanged while making application text easier to
  # read on the laptop's higher-density display.
  gsettings set org.gnome.desktop.interface text-scaling-factor 1.2

  kwriteconfig6 --notify --file kdeglobals --group General --key font \
    'Google Sans Flex,13,-1,5,500,0,0,0,0,0,0,0,0,0,0,1,Medium'
  kwriteconfig6 --notify --file kdeglobals --group General --key fixed \
    'JetBrainsMono Nerd Font,13,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
  kwriteconfig6 --notify --file kdeglobals --group General --key menuFont \
    'Google Sans Flex,12,-1,5,500,0,0,0,0,0,0,0,0,0,0,1,Medium'
  kwriteconfig6 --notify --file kdeglobals --group General --key smallestReadableFont \
    'Google Sans Flex,11,-1,5,500,0,0,0,0,0,0,0,0,0,0,1,Medium'
  kwriteconfig6 --notify --file kdeglobals --group General --key toolBarFont \
    'Google Sans Flex,12,-1,5,500,0,0,0,0,0,0,0,0,0,0,1,Medium'
  kwriteconfig6 --notify --file kdeglobals --group WM --key activeFont \
    'Google Sans Flex,12,-1,5,500,0,0,0,0,0,0,0,0,0,0,1,Medium'
}

configure_laptop_fonts

sudo pacman -S --needed --noconfirm keyd
sudo install -Dm644 \
  "$repo_root/sdata/dist-arch/config/keyd/default.conf" \
  /etc/keyd/default.conf

if [[ -d /run/systemd/system ]]; then
  sudo systemctl enable --now keyd
else
  echo "keyd was installed and configured, but this init system has no automatic keyd service setup." >&2
fi
