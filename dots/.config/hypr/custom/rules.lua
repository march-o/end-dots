-- The upstream rules disable blur globally. Opt Kitty back in for its subtle
-- transparent background; later matching rules take precedence in Hyprland.
hl.window_rule({ match = { class = "^kitty$" }, no_blur = false })

-- Keep Spotify running on its own inactive workspace without changing focus.
hl.window_rule({
    match = { class = "^Spotify$" },
    workspace = "name:Spotify silent",
    no_initial_focus = true,
    suppress_event = "activate activatefocus"
})
