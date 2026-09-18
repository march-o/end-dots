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
