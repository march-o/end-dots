---
name: quickshell
description: Edit, deploy, and diagnose this repository's Arch Quickshell configuration, including the bar, workspaces, and lock screen. Use for Quickshell UI or behavior changes in end-dots-martins.
---

# Quickshell in end-dots-martins

The tracked configuration is `dots/.config/quickshell/ii/`; the live Arch configuration is `~/.config/quickshell/ii/`. Edit tracked files first, then deploy the changed files to the same relative paths in the live tree. `sdata/dist-arch/setup-martins.sh` has an explicit Quickshell file list; add any newly changed file that needs to survive `./setup update`.

## Live changes

- Before any live copy, edit, or reload, check the lock state with `qs -c ii ipc call lock isActive` and monitor `dpmsStatus` with `hyprctl monitors -j`. If locked, displays are off, or the lock state cannot be confirmed, finish changes in the tracked tree and defer live deployment until the user unlocks and wakes the displays. The passwordless overlay's `GlobalStates.screenLocked` resets on reload, which can expose the desktop and wake an off display. Never use a reload as a way to wake or unlock the user's session.
- Inspect the current instance with `qs list --all` and read recent errors with `qs -c ii log --tail 50`. Confirm `Configuration Loaded` after edits and that no newer `Failed to load configuration` remains.
- If the lock screen has no wallpaper to blur, check `~/.config/illogical-impulse/config.json` at `.background.wallpaperPath` and confirm the referenced image exists. The background QML uses that setting as its image source, and the lock blur operates on that image; a generated `wallpaper/path.txt` alone does not select the live Quickshell background.
- The wallpaper `StyledImage` has `retainWhileLoading: true`, but an opacity binding to `status === Image.Ready` hides the retained frame during each async image load. Keep opacity independent of loading status for an uninterrupted switch.
- When updating an existing live QML file, copy into the existing file with `cp` so Quickshell's file watcher sees the modification. `install` may replace the watched inode; a later edit can then fail to trigger a reload. Use `install -Dm644` for a missing target.
- During visual iteration, confirm a fresh `Configuration Loaded` after the last copied file and check that the changed element is visible before judging a screenshot. Reloads can lag by tens of seconds; old log entries and a screenshot taken after a fixed delay can still reflect the previous bar. Save each review capture to a new path so image viewers do not reuse an earlier rendering.
- Keep `import Quickshell.Hyprland` in a panel that declares `GlobalShortcut`; removing it makes the entire shell configuration fail to load. After a failed reload, check for the newest `Configuration Loaded` before trusting older errors in the log.
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
- `CircleUtilButton` accepts one `Item` as its default content. Putting a `StyledToolTip` alongside the icon inside it prevents the entire bar from loading; place any tooltip outside that default content slot.

## Bar glass

- The Kitty terminal uses `background_opacity 0.88`; Hyprland supplies blur at size 2 and one pass. The `quickshell:bar` layer already has blur enabled by the Hyprland layer rules. Set the QML bar background color alpha to 0.88 for comparable glass; keep the content groups opaque for legibility. The keyboard tint comes from `Bar.qml`'s `layerBarColor` mix.
- `ColorUtils.mix(first, second, ratio)` weights the first color by `ratio`; check that ordering when using it for subtle tint or contrast.
- On Arch, keep the floating bar style (`cornerStyle: 1`) in `Config.qml` and normalize existing `config.json` in `setup-martins.sh`; a missing laptop bar entry otherwise falls back to Hug. The laptop's 1.5 GTK/Chrome scale is separate from its 1.25 Quickshell font scale, which kept the 2880×1800 bar more compact in a live visual comparison. Keep the style pickers out of welcome and settings when this style is fixed by the repo.
- Gate the keyboard-layer bar hue by the Planck's serial-specific `/dev/input/by-id/...-event-kbd` symlink, not the `LAPTOP` setting. `test -e` follows the symlink and reports unplugging; polling it updates the tint on hotplug while the plain glass color stays at the same alpha on machines without that keyboard.

## Horizontal bar layout

- In the 40px bar, put the time, month, and day on one line in a single `StyledText` to keep their baselines aligned. The left side contains only this clock; leave out the weekday, current-window title, and trailing divider.
- Use explicit spacing for compact left-side content. A `RowLayout` stretched across the whole left region centered an implicit-width item in unused space, leaving an unintended gap of about 80px.
- Keep passive metrics and utility controls on a quieter layer surface, leaving stronger accent color for media and active controls. A single-line media title leaves room for transport and volume; expose the full title and artist on hover when the title elides.
- `Workspaces.qml` has no `widgetPadding` property. Let its `BarGroup` use the default 5px padding; binding to `workspacesWidget.widgetPadding` logs an undefined-to-double warning on every reload.
- The bar's lock button calls the native lock IPC `activateAndTurnOffScreen`. It uses the lock page's DPMS-disable action after locking: wait for `WlSessionLock.secure` in password-protected mode, or allow the passwordless overlay to render before disabling displays. Cancel pending screen-off on unlock; do not blank the desktop immediately after merely requesting a secure lock.
- Check that new Material Symbol names form a glyph in the installed font. `screen_lock_desktop` is missing from this font and renders as overflowing text; `lock` and `tv_off` are supported.

## Keep this skill current

When a Quickshell task demonstrates a reusable behavior or failure mode, record the verified lesson here in the same repository change. Replace obsolete advice instead of accumulating conflicting rules. Keep task-specific temporary observations out of the skill.
