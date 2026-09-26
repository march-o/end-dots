hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )

hl.bind("CTRL + SUPER + SHIFT + S", hl.dsp.workspace.toggle_special("spotify"),
    { description = "Spotify: Toggle window" })

-- Treat Super+arrows as a 2D canvas. First focus a window in the requested
-- direction on the current workspace; only at that edge fall back to the
-- neighboring monitor or workspace.
local function canvas_window(direction)
    local active = hl.get_active_window()
    local workspace = hl.get_active_workspace()
    local candidates = workspace and hl.get_workspace_windows(workspace) or {}
    local best_window = nil
    local best_score = math.huge

    if active then
        local active_x = active.at.x + active.size.x / 2
        local active_y = active.at.y + active.size.y / 2

        for _, candidate in ipairs(candidates) do
            if candidate ~= active and candidate.mapped and candidate.visible
                and candidate.monitor and active.monitor
                and candidate.monitor.id == active.monitor.id then
                local candidate_x = candidate.at.x + candidate.size.x / 2
                local candidate_y = candidate.at.y + candidate.size.y / 2
                local primary, secondary

                if direction == "l" and candidate_x < active_x then
                    primary = active_x - candidate_x
                    secondary = math.abs(active_y - candidate_y)
                elseif direction == "r" and candidate_x > active_x then
                    primary = candidate_x - active_x
                    secondary = math.abs(active_y - candidate_y)
                elseif direction == "u" and candidate_y < active_y then
                    primary = active_y - candidate_y
                    secondary = math.abs(active_x - candidate_x)
                elseif direction == "d" and candidate_y > active_y then
                    primary = candidate_y - active_y
                    secondary = math.abs(active_x - candidate_x)
                end

                if primary then
                    local score = primary + secondary * 2
                    if score < best_score then
                        best_score = score
                        best_window = candidate
                    end
                end
            end
        end
    end

    return active, best_window
end

local function focus_canvas(direction)
    local _, best_window = canvas_window(direction)

    if best_window then
        hl.dispatch(hl.dsp.focus({ window = best_window }))
    elseif direction == "u" then
        hl.dispatch(hl.dsp.focus({ workspace = "r-1" }))
    elseif direction == "d" then
        hl.dispatch(hl.dsp.focus({ workspace = "r+1" }))
    elseif #hl.get_monitors() > 1 then
        hl.dispatch(hl.dsp.focus({ monitor = direction }))
    end
end

local function move_canvas(direction)
    local active, best_window = canvas_window(direction)
    if not active then
        return
    end

    if best_window then
        hl.dispatch(hl.dsp.window.move({ direction = direction, window = active }))
    elseif direction == "u" then
        hl.dispatch(hl.dsp.window.move({ workspace = "r-1", window = active, follow = true }))
    elseif direction == "d" then
        hl.dispatch(hl.dsp.window.move({ workspace = "r+1", window = active, follow = true }))
    elseif #hl.get_monitors() > 1 then
        hl.dispatch(hl.dsp.window.move({ monitor = direction, window = active, follow = true }))
    end
end

for _, direction in ipairs({
    { key = "Left", direction = "l", description = "Canvas: Focus left" },
    { key = "Right", direction = "r", description = "Canvas: Focus right" },
    { key = "Up", direction = "u", description = "Canvas: Focus up" },
    { key = "Down", direction = "d", description = "Canvas: Focus down" }
}) do
    hl.unbind("SUPER + " .. direction.key)
    hl.bind("SUPER + " .. direction.key, function()
        focus_canvas(direction.direction)
    end, { description = direction.description })

    local move_description = direction.description:gsub("Focus", "Move")
    hl.unbind("SUPER + SHIFT + " .. direction.key)
    hl.bind("SUPER + SHIFT + " .. direction.key, function()
        move_canvas(direction.direction)
    end, { description = move_description })
end

-- Replace end-4's folder-relative random choice with a deterministic cycle
-- through the wallpapers in ~/Wallpapers.
hl.unbind("CTRL + SUPER + ALT + T")
hl.bind("CTRL + SUPER + ALT + T", hl.dsp.exec_cmd("$HOME/.local/bin/wallpaper-next"),
    { description = "Shell: Next wallpaper" })
