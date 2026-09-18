hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )

-- Replace end-4's folder-relative random choice with a deterministic cycle
-- through the wallpapers in ~/Wallpapers.
hl.unbind("CTRL + SUPER + ALT + T")
hl.bind("CTRL + SUPER + ALT + T", hl.dsp.exec_cmd("$HOME/.local/bin/wallpaper-next"),
    { description = "Shell: Next wallpaper" })
