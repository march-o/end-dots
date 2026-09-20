-- Keep the terminal glass readable without the heavy end-4 blur defaults.
-- Hyprland applies blur strength globally; window and layer rules decide where.
hl.config({
    decoration = {
        blur = {
            size = 2,
            passes = 1
        }
    }
})

-- Make the active window unmistakable while keeping the theme accent.
hl.config({
    general = {
        border_size = 2
    }
})

-- Workspace navigation is vertical to match Super+Up/Down.
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 7,
    bezier = "menu_decel",
    style = "slidevert"
})
