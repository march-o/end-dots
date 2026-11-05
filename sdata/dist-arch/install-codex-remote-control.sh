#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ ! -x "$HOME/.local/bin/codex" ]]; then
  printf 'Install Codex at ~/.local/bin/codex and sign in before enabling remote control.\n' >&2
  exit 1
fi

install -Dm644 "$repo_root/sdata/dist-arch/config/codex-remote-control.service" \
  "$HOME/.config/systemd/user/codex-remote-control.service"
install -Dm755 "$repo_root/sdata/dist-arch/bin/chatgpt" "$HOME/.local/bin/chatgpt"
if [[ -f /usr/share/applications/chatgpt.desktop ]]; then
  applications_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  launcher="$applications_dir/chatgpt.desktop"
  if [[ ! -f "$launcher" ]]; then
    install -Dm644 /usr/share/applications/chatgpt.desktop "$launcher"
  fi
  # Keep existing launcher options, including the laptop's UI scale.
  python - "$launcher" "$HOME/.local/bin/chatgpt" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
executable = '"' + sys.argv[2].replace('\\', '\\\\').replace('"', '\\"') + '"'
text = path.read_text()
text = re.sub(r'^Exec=(?:"[^"]*chatgpt"|\S*chatgpt)(?=\s|$)',
              lambda match: 'Exec=' + executable, text, flags=re.MULTILINE)
path.write_text(text)
PY
  if command -v update-desktop-database >/dev/null; then
    update-desktop-database "$applications_dir"
  fi
fi
# Start the user service at boot and retain it after logout.
if [[ "$(loginctl show-user "$USER" -p Linger --value)" != yes ]]; then
  sudo loginctl enable-linger "$USER"
fi
systemctl --user daemon-reload
systemctl --user enable --now codex-remote-control.service
