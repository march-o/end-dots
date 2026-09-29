---
name: quickshell
description: Edit, deploy, and diagnose this repository's Arch Quickshell configuration, including the bar, workspaces, and lock screen. Use for Quickshell UI or behavior changes in end-dots-martins.
---

# Quickshell in end-dots-martins

The tracked configuration is `dots/.config/quickshell/ii/`; the live Arch configuration is `~/.config/quickshell/ii/`. Edit tracked files first, then deploy the changed files to the same relative paths in the live tree. `sdata/dist-arch/setup-martins.sh` has an explicit Quickshell file list; add any newly changed file that needs to survive `./setup update`.

## Live changes

- Inspect the current instance with `qs list --all` and read recent errors with `qs -c ii log --tail 50`. Confirm `Configuration Loaded` after edits and that no newer `Failed to load configuration` remains.
- When updating an existing live QML file, copy into the existing file with `cp` so Quickshell's file watcher sees the modification. `install` may replace the watched inode; a later edit can then fail to trigger a reload. Use `install -Dm644` for a missing target.
- If a valid correction does not reload after an earlier failed load, modify the live `shell.qml` in place to prompt a reload. Check the log again before concluding that the correction is active.
- Remove temporary logging or IPC probes from tracked and live QML after diagnosis. Do not restart the shell casually: the lock UI runs there. For lock changes, ensure a working recovery path and verify that the shell loaded before trying to lock.
- If content changes and an in-place `shell.qml` edit do not reload, check `qs -c ii ipc call lock isActive` before replacing the instance. `qs kill` can report success while the old PID still runs; verify that it exited before launching a replacement, or two bars can appear. After replacement, check `qs list --all`, lock IPC, and a screenshot.

## Workspace data

- `HyprlandData.qml` obtains monitor, workspace, active workspace, and client data from `hyprctl`. Compare it with `hyprctl monitors -j`, `hyprctl workspaces -j`, and `hyprctl clients -j` when the bar disagrees with Hyprland.
- Quickshell's `Hyprland` workspace objects and raw event feed have become stale after sleep on this machine. The current `HyprlandData.qml` periodically refreshes the CLI data so the bar's active and occupied indicators recover. Keep the refresh path when changing event handling unless a replacement is shown to work after resume.
- On reload, the QML screen or monitor may initially be null. Guard those values. An absent special workspace has an empty name; do not display `special` as a fallback label.
- A QML object can have only one `Component.onCompleted` handler. Add diagnostic work to the existing handler or remove it before adding another.

## Media controls

- Check the target MPRIS player and its `volumeSupported`/`canControl` properties before adding a media volume control. A Spotify Connect session can expose writable Spotify MPRIS volume while PipeWire has no local playback stream, so the local sink volume is not a reliable control for that session. Confirm that a small MPRIS volume change reads back, then restore it; this confirms the interface accepts writes but does not alone prove the remote speaker changed loudness.
- For compact media UI inside `BarGroup`, give the media item a fixed preferred height and vertical alignment. `Layout.fillHeight` extended the media item beyond the visible bar here, placing its progress line on the wallpaper. Capture a magnified bar screenshot to catch this kind of overflow.
- In a 40px bar, a playback rail flush with the media container's bottom edge read as an accidental border and crowded the artwork. Keep the media card focused on artwork, text, and the volume slider unless progress has a clearly separated place. A slim slider with a visible dark remainder and a full-height pointer target read more clearly than a filled volume block or stacked icon and percentage. If a speaker glyph is needed, place it after the slider at the far right; use enough contrast to read at bar scale.
- When adding transport buttons to a media card, give each its own full-height mouse target so clicks do not reach the card-wide workspace action. Widen both `Media.qml` and its `BarContent.qml` group together; with a 144px volume slider, a 400px card clipped the artist, while 480px left room for the artwork, metadata, three controls, and volume. Keep a compact layout for shortened bars.

## Bar glass

- The Kitty terminal uses `background_opacity 0.88`; Hyprland supplies blur at size 2 and one pass. The `quickshell:bar` layer already has blur enabled by the Hyprland layer rules. Set the QML bar background color alpha to 0.88 for comparable glass; keep the content groups opaque for legibility. The keyboard tint comes from `Bar.qml`'s `layerBarColor` mix.
- `ColorUtils.mix(first, second, ratio)` weights the first color by `ratio`; check that ordering when using it for subtle tint or contrast.

## Keep this skill current

When a Quickshell task demonstrates a reusable behavior or failure mode, record the verified lesson here in the same repository change. Replace obsolete advice instead of accumulating conflicting rules. Keep task-specific temporary observations out of the skill.
