#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
mapfile -t pin < <(node -e 'const fs=require("node:fs");const p=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));if(!/^[a-f0-9]{40}$/.test(p.revision)||p.repository!=="git@github.com:march-o/chrome-control.git")throw Error("Invalid Chrome Control pin");console.log(p.repository);console.log(p.revision)' "$repo_root/sdata/dist-arch/chrome-control-pin.json")
[[ ${#pin[@]} == 2 ]] || { echo "Invalid Chrome Control pin" >&2; exit 1; }
source_dir="$HOME/.local/share/chrome-control/checkouts/${pin[1]}"
if [[ ! -d "$source_dir/.git" ]]; then
  mkdir -p "$(dirname -- "$source_dir")"
  git clone --no-checkout "${pin[0]}" "$source_dir"
  git -C "$source_dir" fetch --depth=1 origin "${pin[1]}"
  git -C "$source_dir" checkout --detach "${pin[1]}"
fi
[[ "$(git -C "$source_dir" rev-parse HEAD)" == "${pin[1]}" ]] || { echo "Chrome Control checkout revision mismatch" >&2; exit 1; }
[[ -z "$(git -C "$source_dir" status --porcelain)" ]] || { echo "Chrome Control checkout is dirty; refusing to overwrite" >&2; exit 1; }
node "$source_dir/scripts/install.mjs" "$source_dir"
