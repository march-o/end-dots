#!/usr/bin/env bash
set -euo pipefail

if [[ "${LAPTOP:-}" != "1" ]]; then
  exit 0
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

sudo pacman -S --needed --noconfirm keyd
sudo install -Dm644 \
  "$repo_root/sdata/dist-arch/config/keyd/default.conf" \
  /etc/keyd/default.conf

if [[ -d /run/systemd/system ]]; then
  sudo systemctl enable --now keyd
else
  echo "keyd was installed and configured, but this init system has no automatic keyd service setup." >&2
fi
