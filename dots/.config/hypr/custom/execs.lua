hl.on("hyprland.start", function ()
    -- Cycle through ~/Wallpapers once per Hyprland login, after Quickshell starts.
    hl.exec_cmd("sleep 3 && $HOME/.local/bin/wallpaper-next")
end)
