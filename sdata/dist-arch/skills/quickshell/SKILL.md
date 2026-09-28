---
name: quickshell
description: Edit, deploy, and diagnose this repository's Arch Quickshell configuration, including the bar, workspaces, and lock screen. Use for Quickshell UI or behavior changes in end-dots-martins.
---

# Quickshell in end-dots-martins

The tracked configuration is `dots/.config/quickshell/ii/`; the live Arch configuration is `~/.config/quickshell/ii/`. Edit tracked files first, then deploy the changed files to the same relative paths in the live tree. `sdata/dist-arch/setup-martins.sh` must install any new tracked file that needs to survive `./setup update`.

## Live changes

- Inspect the current instance with `qs list --all` and read recent errors with `qs -c ii log --tail 50`. Confirm `Configuration Loaded` after edits and that no newer `Failed to load configuration` remains.
- When updating an existing live QML file, copy into the existing file with `cp` so Quickshell's file watcher sees the modification. `install` may replace the watched inode; a later edit can then fail to trigger a reload. Use `install -Dm644` for a missing target.
- If a valid correction does not reload after an earlier failed load, modify the live `shell.qml` in place to prompt a reload. Check the log again before concluding that the correction is active.
- Remove temporary logging or IPC probes from tracked and live QML after diagnosis. Do not restart the shell casually: the lock UI runs there. For lock changes, ensure a working recovery path and verify that the shell loaded before trying to lock.

## Workspace data

- `HyprlandData.qml` obtains monitor, workspace, active workspace, and client data from `hyprctl`. Compare it with `hyprctl monitors -j`, `hyprctl workspaces -j`, and `hyprctl clients -j` when the bar disagrees with Hyprland.
- Quickshell's `Hyprland` workspace objects and raw event feed have become stale after sleep on this machine. The current `HyprlandData.qml` periodically refreshes the CLI data so the bar's active and occupied indicators recover. Keep the refresh path when changing event handling unless a replacement is shown to work after resume.
- On reload, the QML screen or monitor may initially be null. Guard those values. An absent special workspace has an empty name; do not display `special` as a fallback label.
- A QML object can have only one `Component.onCompleted` handler. Add diagnostic work to the existing handler or remove it before adding another.

## Keep this skill current

When a Quickshell task demonstrates a reusable behavior or failure mode, record the verified lesson here in the same repository change. Replace obsolete advice instead of accumulating conflicting rules. Keep task-specific temporary observations out of the skill.
