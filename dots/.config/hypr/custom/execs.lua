hl.on("hyprland.start", function ()
    -- Start Spotify at login on its own inactive workspace without taking focus.
    -- Filter Spotify's known upstream appindicator deprecation warning; keep other errors visible.
    hl.exec_cmd("spotify 2> >(grep -v 'libayatana-appindicator is deprecated' >&2)")

    -- Cycle through ~/Wallpapers once per Hyprland login, after Quickshell starts.
    hl.exec_cmd("sleep 3 && $HOME/.local/bin/wallpaper-next")
end)
