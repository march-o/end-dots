---
name: hyprland-windows
description: Inspect, open, and focus local application windows on Martins' Hyprland desktop. Use for window management requests; use chrome-automation for Chrome tabs and web pages.
---

# Hyprland windows

Inspect mapped windows and the current focus before acting:

```sh
hyprctl clients -j | jq '[.[] | select(.mapped == true and .hidden == false) | {address, class, title, workspace: .workspace.id}]'
hyprctl activewindow -j
```

If the requested app already has a window, reuse it. Launch a missing app with its normal executable, such as `kitty` or `dolphin`. Do not launch a second copy just to make an existing window visible.

Preserve the user's active window and workspace unless they explicitly ask to bring another app forward. Inspect focus for verification, but do not restore an earlier active window after an asynchronous operation: the user may have moved focus while the task ran. To focus a window when requested, take its address from a fresh `hyprctl clients -j` result and run:

```sh
hyprctl dispatch 'hl.dsp.focus({ window = "address:0x..." })'
```

For browser computer-use focus stealing, inspect `hyprctl getoption misc:focus_on_activate -j` as well as the per-window activation rules. The laptop formerly disabled this setting inside its keyboard-only conditional, leaving the desktop at the upstream `true` default. Keep `focus_on_activate = false` outside that conditional in `custom/general.lua`, alongside Chrome/ChatGPT activation suppression in `custom/rules.lua`. Apply just the changed values through `hyprctl eval`, staging persistent files with autoreload temporarily disabled; avoid a compositor reload. Verify with a disposable browser tab: opening, clicking, and typing through the actual computer-use tool must leave the user's active window and workspace unchanged. Do not use `no_focus`, which would interfere with ordinary manual focus.

On this Hyprland version, dispatchers use Lua syntax. To open a new window directly in a hidden workspace, install a named temporary rule with `workspace = "special:name silent"` and `no_initial_focus = true`. Keep its handle in a global Lua variable, then disable it after the window maps, without reloading or changing focus:

```sh
hyprctl eval 'ash_window_once = hl.window_rule({ name = "ash-window-once", match = { class = "^google-chrome$" }, workspace = "special:fpl silent", no_initial_focus = true })'
# Open the window; verify it is in special:fpl and specialWorkspace is empty.
hyprctl eval 'ash_window_once:set_enabled(false)'
```

Even `hyprctl reload config-only` switched the monitor in this setup. Never toggle the special workspace to inspect it. For a requested background move, use:

```sh
hyprctl dispatch 'hl.dsp.window.move({ workspace = "6", window = "address:0x...", follow = false })'
```

After either operation, verify that the active monitor workspace, special workspace, and active window remain unchanged. Browser page interaction can still steal focus even when its window starts hidden; stop page interaction if the user reports that happening.

If the user explicitly asks to switch to the destination workspace as the last step, wait until the page work and background move are complete. Then use:

```sh
hyprctl dispatch 'hl.dsp.focus({ workspace = "6" })'
hyprctl dispatch 'hl.dsp.focus({ window = "address:0x..." })'
```

Take the address from a fresh client listing and verify the monitor's active workspace and active window afterward. Do not switch early merely to inspect a hidden window.

Use the `chrome-automation` skill and a connected browser tool for Chrome profiles, tabs, and page interaction. Hyprland's window class does not identify a Chrome profile.
