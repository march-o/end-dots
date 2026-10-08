-- Optional HyprGlass v0.9.1, built against Hyprland 0.56.2. A missing or
-- incompatible plugin leaves the bar's native blur rule in place.
local plugin = HOME .. "/.local/share/hyprglass/hyprglass.so"
if not hl.version():find("0.56.2", 1, true) then return end
-- Declare it on every parse, even when loaded: Hyprland unloads config plugins
-- omitted from the next parse, which would otherwise cause a reload loop.
if is_file_exists(plugin) then hl.plugin.load(plugin) end
if not hl.plugin.hyprglass then return end

local hg = hl.plugin.hyprglass
hg.config({
    enabled = false,
    manage_window_blur = false,
    default_preset = "default",
    -- A light softening preserves wallpaper detail; refraction and highlights
    -- provide the glass character instead of heavy frosting.
    blur_strength = 0.34,
    blur_iterations = 1,
    refraction_strength = 0.50,
    refraction_flow = 0.7,
    refraction_spread = 0.20,
    lens_distortion = 0.13,
    chromatic_aberration = 0.025,
    fresnel_strength = 0.18,
    fresnel_tint = 0.65,
    specular_strength = 0.30,
    glass_opacity = 1.0,
    tint_color = 0x00000000,
    dark = { brightness = 1.0, contrast = 1.04, saturation = 1.08,
        vibrancy = 0.08, adaptive_dim = 0.0, adaptive_boost = 0.0 },
    light = { brightness = 1.0, contrast = 1.04, saturation = 1.08,
        vibrancy = 0.08, adaptive_dim = 0.0, adaptive_boost = 0.0 },
    layers = {
        enabled = true,
        namespaces = "quickshell:bar",
        mask_mode = "alpha",
        manage_blur = true,
        live_resample = true,
        live_resample_fps = 30,
    },
})
hg.layer("quickshell:bar", { mask_threshold = 0.01, mask_mode = "alpha" })
