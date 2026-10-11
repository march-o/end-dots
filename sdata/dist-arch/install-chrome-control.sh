#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source_dir="$repo_root/sdata/dist-arch/chrome-control"
install_dir="$HOME/.local/share/end-dots-martins/chrome-control"

mkdir -p "$install_dir"
rsync -a --exclude node_modules --exclude extension/config.js --exclude work-extension \
  "$source_dir/" "$install_dir/"
npm ci --omit=dev --ignore-scripts --no-audit --no-fund --prefix "$install_dir" >/dev/null
install -Dm755 "$repo_root/sdata/dist-arch/bin/chrome-control" "$HOME/.local/bin/chrome-control"
install -Dm644 "$source_dir/chrome-control.service" "$HOME/.config/systemd/user/chrome-control.service"
