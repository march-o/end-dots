-- The upstream rules disable blur globally. Opt Kitty back in for its subtle
-- transparent background; later matching rules take precedence in Hyprland.
hl.window_rule({ match = { class = "^kitty$" }, no_blur = false })
