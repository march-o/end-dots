#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source_dir="$repo_root/sdata/dist-arch/chrome-control"
install_dir="$HOME/.local/share/end-dots-martins/chrome-control"
skills_dir="$HOME/.agents/skills"

for skill_name in hyprland-windows chrome-automation; do
  mkdir -p "$skills_dir/$skill_name"
  rsync -a --delete "$repo_root/dots/.agents/skills/$skill_name/" "$skills_dir/$skill_name/"
done

opencode_config="$HOME/.config/opencode/opencode.json"
mkdir -p "$(dirname "$opencode_config")"
node - "$opencode_config" <<'JS'
const fs = require('node:fs');
const file = process.argv[2];
const config = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : {};
const rules = config.permissions ?? [];
const path = '$HOME/.local/share/end-dots-martins/chrome-control/*';
for (const rule of [
  { action: 'external_directory', resource: path, effect: 'allow' },
  { action: 'edit', resource: path, effect: 'deny' },
]) {
  if (!rules.some(existing => existing.action === rule.action && existing.resource === path)) rules.push(rule);
}
config.permissions = rules;
fs.writeFileSync(file, JSON.stringify(config, null, 2) + '\n');
JS

mkdir -p "$install_dir"
rsync -a --delete --exclude node_modules --exclude extension/config.js \
  "$source_dir/" "$install_dir/"
npm ci --omit=dev --ignore-scripts --no-audit --no-fund --prefix "$install_dir" >/dev/null
install -Dm755 "$repo_root/sdata/dist-arch/bin/chrome-control" "$HOME/.local/bin/chrome-control"
install -Dm644 "$source_dir/chrome-control.service" \
  "$HOME/.config/systemd/user/chrome-control.service"
systemctl --user daemon-reload
systemctl --user enable chrome-control.service >/dev/null
systemctl --user restart chrome-control.service
for attempt in {1..25}; do
  if "$HOME/.local/bin/chrome-control" '{"action":"status"}' >/dev/null 2>&1; then
    exit 0
  fi
  sleep 0.2
done
echo 'chrome-control did not create its local socket' >&2
exit 1
