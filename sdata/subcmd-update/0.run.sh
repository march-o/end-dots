# This script is meant to be sourced.
# shellcheck shell=bash

set -euo pipefail

if ! command -v pacman >/dev/null 2>&1; then
  log_die "The update command only supports Arch Linux."
fi

require_command rsync

printf "${STY_CYAN}[$0]: Applying the current checkout${STY_RST}\n"

# Copy every tracked user file into place without deleting unrelated local files.
x rsync -a "$REPO_ROOT/dots/" "$HOME/"

# Apply this fork's Arch system settings and files stored outside dots/.
x bash "$REPO_ROOT/sdata/dist-arch/setup-martins.sh"

if [[ "${LAPTOP:-}" == "1" ]]; then
  x bash "$REPO_ROOT/sdata/dist-arch/setup-laptop.sh"
fi

if command -v update-desktop-database >/dev/null 2>&1; then
  x update-desktop-database "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
fi

if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  x hyprctl reload
fi

log_success "Applied the current checkout."
