#!/usr/bin/env bash

QUICKSHELL_CONFIG_NAME="ii"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

term_alpha=100 #Set this to < 100 make all your terminals transparent
# sleep 0 # idk i wanted some delay or colors dont get applied properly
if [ ! -d "$STATE_DIR"/user/generated ]; then
  mkdir -p "$STATE_DIR"/user/generated
fi
cd "$CONFIG_DIR" || exit

# Render privately and publish only a complete theme. Concurrent wallpaper
# changes must never expose template placeholders to a newly launched Kitty.
render_terminal_theme() {
  python3 - "$STATE_DIR/user/generated/material_colors.scss" "$1" "$2" "$term_alpha" <<'PYTHON'
import os
from pathlib import Path
import re
import sys
import tempfile

palette, template, target, alpha = sys.argv[1:]
colors = dict(re.findall(r"\$(\w+):\s*(#[0-9a-fA-F]{6});", Path(palette).read_text()))
text = Path(template).read_text()
def replace(match):
    name = match.group(1)
    if name not in colors:
        raise ValueError(f"Missing terminal theme color: {name}")
    return colors[name]
text = re.sub(r"#\$(\w+) #", replace, text).replace("$alpha", alpha)
destination = Path(target)
destination.parent.mkdir(parents=True, exist_ok=True)
fd, temporary = tempfile.mkstemp(prefix=".theme-", dir=destination.parent)
try:
    with os.fdopen(fd, "w") as output:
        output.write(text)
    os.chmod(temporary, 0o644)
    os.replace(temporary, destination)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
PYTHON
}

apply_kitty() {  
  # Check if terminal escape sequence template exists
  if [ ! -f "$SCRIPT_DIR/terminal/kitty-theme.conf" ]; then
    echo "Template file not found for Kitty theme. Skipping that."
    return
  fi
  render_terminal_theme "$SCRIPT_DIR/terminal/kitty-theme.conf" \
    "$STATE_DIR/user/generated/terminal/kitty-theme.conf" || return

  # Reload
  if ! pgrep -x kitty >/dev/null; then
    return
  fi
  # Kitty reloads kitty.conf (including the generated theme) on SIGUSR1.
  pkill -USR1 -x kitty || true
}

apply_anyterm() {
  # Check if terminal escape sequence template exists
  if [ ! -f "$SCRIPT_DIR/terminal/sequences.txt" ]; then
    echo "Template file not found for Terminal. Skipping that."
    return
  fi
  render_terminal_theme "$SCRIPT_DIR/terminal/sequences.txt" \
    "$STATE_DIR/user/generated/terminal/sequences.txt" || return

  for file in /dev/pts/*; do
    if [[ $file =~ ^/dev/pts/[0-9]+$ ]]; then
      {
      cat "$STATE_DIR"/user/generated/terminal/sequences.txt >"$file"
      } & disown || true
    fi
  done
}

apply_term() {
  apply_anyterm &
  apply_kitty &
}

# Check if terminal theming is enabled in config
CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
if [ -f "$CONFIG_FILE" ]; then
  enable_terminal=$(jq -r '.appearance.wallpaperTheming.enableTerminal' "$CONFIG_FILE")
  if [ "$enable_terminal" = "true" ]; then
    apply_term &
  fi
else
  echo "Config file not found at $CONFIG_FILE. Applying terminal theming by default."
  apply_term &
fi

# apply_qt & # Qt theming is already handled by kde-material-colors
