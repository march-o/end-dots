local home_dir = os.getenv("HOME")

-- Wayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Applications
-- Reloads inherit the current environment; append each directory only once.
local xdg_data_dirs, seen_data_dirs = {}, {}
local function add_data_dir(dir)
    if dir ~= "" and not seen_data_dirs[dir] then
        seen_data_dirs[dir] = true
        table.insert(xdg_data_dirs, dir)
    end
end
for _, dir in ipairs({ home_dir .. "/.local/share/flatpak/exports/share",
    "/var/lib/flatpak/exports/share", "/usr/local/share", "/usr/share" }) do
    add_data_dir(dir)
end
for dir in (os.getenv("XDG_DATA_DIRS") or ""):gmatch("[^:]+") do
    add_data_dir(dir)
end
hl.env("XDG_DATA_DIRS", table.concat(xdg_data_dirs, ":"))

-- Themes
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("XDG_MENU_PREFIX", "plasma-")

-- Virtual environment
hl.env("ILLOGICAL_IMPULSE_VIRTUAL_ENV", home_dir .. "/.local/state/quickshell/.venv")
