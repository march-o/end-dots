#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ ! -x "$HOME/.local/bin/codex" ]]; then
  printf 'Install Codex at ~/.local/bin/codex and sign in before enabling remote control.\n' >&2
  exit 1
fi

install -Dm644 "$repo_root/sdata/dist-arch/config/codex-remote-control.service" \
  "$HOME/.config/systemd/user/codex-remote-control.service"
# Start the user service at boot and retain it after logout.
if [[ "$(loginctl show-user "$USER" -p Linger --value)" != yes ]]; then
  sudo loginctl enable-linger "$USER"
fi
systemctl --user daemon-reload
systemctl --user enable --now codex-remote-control.service
