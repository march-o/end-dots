-- The upstream rules disable blur globally. Opt Kitty back in for its subtle
-- transparent background; later matching rules take precedence in Hyprland.
hl.window_rule({ match = { class = "^kitty$" }, no_blur = false })

-- Keep Spotify on a hidden special workspace, outside numbered workspace navigation.
hl.window_rule({
    match = { class = "^Spotify$" },
    workspace = "special:spotify silent",
    no_initial_focus = true,
    suppress_event = "activate activatefocus"
})
