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

-- The laptop keeps its Colemak-DH mapping in keyd. Latvian's standard XKB
-- layout preserves the base keys and adds Latvian letters on Right Alt.
local laptop_keyboard = io.open(HOME .. "/.config/hypr/.laptop-keyboard", "r")
if laptop_keyboard then
    laptop_keyboard:close()
    hl.config({
        input = { kb_layout = "lv" }
    })
end

-- Background app activation must not switch the user's window or workspace.
-- This applies to desktop computer use as well as the laptop.
hl.config({ misc = { focus_on_activate = false } })

-- Workspace navigation is vertical to match Super+Up/Down.
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 7,
    bezier = "menu_decel",
    style = "slidevert"
})
