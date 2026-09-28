-- The upstream rules disable blur globally. Opt Kitty back in for its subtle
-- transparent background; later matching rules take precedence in Hyprland.
hl.window_rule({ match = { class = "^kitty$" }, no_blur = false })

-- Browser tabs opened by Codex should not interrupt the active workspace.
-- Explicit clicks and `deskctl focus chrome` still focus Chrome normally.
if is_file_exists(HOME .. "/.config/hypr/.laptop-keyboard") then
    hl.window_rule({
        match = { class = "^google-chrome$" },
        no_initial_focus = true,
        suppress_event = "activate activatefocus"
    })
end

-- Keep Spotify on a hidden special workspace, outside numbered workspace navigation.
hl.window_rule({
    match = { class = "^Spotify$" },
    workspace = "special:spotify silent",
    no_initial_focus = true,
    suppress_event = "activate activatefocus"
})
