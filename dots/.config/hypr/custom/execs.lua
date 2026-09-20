hl.on("hyprland.start", function ()
    -- Start Spotify at login without opening it in the foreground.
    hl.exec_cmd("spotify --minimized")

    -- Cycle through ~/Wallpapers once per Hyprland login, after Quickshell starts.
    hl.exec_cmd("sleep 3 && $HOME/.local/bin/wallpaper-next")
end)
