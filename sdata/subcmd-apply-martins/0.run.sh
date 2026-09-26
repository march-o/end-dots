#!/usr/bin/env bash

case "${1:-}" in
  -h|--help)
    cat <<'HELP'
Usage: ./setup apply-martins

Copy the tracked Arch Hyprland custom files, Chrome launchers, and deskctl
into the current user's config. Reload Hyprland when a session is active.
LAPTOP defaults to 0; LAPTOP=1 also installs and enables the tracked keyd setup.
HELP
    return 0
    ;;
  "") ;;
  *) printf 'Unknown apply-martins option: %s\n' "$1" >&2; exit 2 ;;
esac

if ! command -v pacman >/dev/null 2>&1; then
  printf 'apply-martins requires Arch Linux.\n' >&2
  exit 1
fi

case "${LAPTOP:-0}" in
  0|1) ;;
  *) printf 'LAPTOP must be 0 or 1.\n' >&2; exit 1 ;;
esac

for file in execs.lua rules.lua keybinds.lua; do
  install -Dm644 "$REPO_ROOT/dots/.config/hypr/custom/$file" \
    "$XDG_CONFIG_HOME/hypr/custom/$file"
done

install -Dm755 "$REPO_ROOT/dots/.local/bin/deskctl" "$XDG_BIN_HOME/deskctl"

applications_dir="$XDG_DATA_HOME/applications"
for file in google-chrome.desktop google-chrome-work.desktop; do
  install -Dm644 "$REPO_ROOT/dots/.local/share/applications/$file" \
    "$applications_dir/$file"
done
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$applications_dir"
fi

if [[ "${LAPTOP:-0}" == 1 ]]; then
  bash "$REPO_ROOT/sdata/dist-arch/setup-laptop.sh"
fi

if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
  hyprctl reload
fi

printf 'Applied Martins Arch config (LAPTOP=%s). Spotify autostart takes effect next login.\n' "${LAPTOP:-0}"
