-- The upstream rules disable blur globally. Opt Kitty back in for its subtle
-- transparent background; later matching rules take precedence in Hyprland.
hl.window_rule({ match = { class = "^kitty$" }, no_blur = false })

-- Computer-use activity in Chrome or ChatGPT should not interrupt other windows.
-- Explicit clicks and Hyprland focus commands still focus Chrome normally.
hl.window_rule({
    name = "automation-preserve-focus",
    match = { class = "^(google-chrome|Chatgpt|ChatGPT|chatgpt)$" },
    no_initial_focus = true,
    suppress_event = "activate activatefocus"
})

-- Keep Spotify on a hidden special workspace, outside numbered workspace navigation.
hl.window_rule({
    match = { class = "^Spotify$" },
    workspace = "special:spotify silent",
    no_initial_focus = true,
    suppress_event = "activate activatefocus"
})

-- Blur the nearly transparent glass bar, including its background surface.
hl.layer_rule({ match = { namespace = "^quickshell:bar$" }, blur = true, ignore_alpha = 0.01 })

if is_file_exists(HOME .. "/.config/hypr/custom/glass.lua") then
    require("custom.glass")
end
