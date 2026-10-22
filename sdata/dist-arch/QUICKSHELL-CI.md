# Arch Quickshell checks

Run from this checkout:

```sh
quickshell-ci
# Inspect the result directory's screenshots and logs, then commit the changes.
quickshell-apply apply --report /path/to/result.json
```

The scripts live in `sdata/dist-arch/bin/`; Arch setup links them into
`~/.local/bin`. Omitting `--report` runs fresh checks automatically. Setup also
uses this deployment path when `ii` is running. Requirements are the installed
Quickshell build, Sway, bubblewrap, D-Bus, grim, Python/Pillow, a C compiler,
Wayland client headers/scanner, and initialized
Git submodules. These are installed by Arch setup.

For the initial release record, use `quickshell-apply adopt --ref <live-commit>`.
Adoption requires an unlocked, awake session, one live shell, visible native bars,
and a successful load newer than all managed files. It stores only the Git
reference and file hashes in `~/.local/state/quickshell-deploy/last-good.json`.
Unrelated live customizations are preserved and included in preflight by hash.
Changed deployment targets must match their Git baseline; unknown drift stops
the operation.

## What is tested

The candidate is frozen into a temporary test fixture. The baseline comes from
the recorded Git release, including pinned submodule contents. The complete
`shell.qml` runs on a real headless Wayland compositor in bubblewrap, with a
private D-Bus session. There is no host display socket, input device, session bus,
network, or writable home. Only render nodes and fonts are exposed. A small virtual-pointer fixture gives the
private compositor a persistent pointer device; cursor commands address only its
private seat. The vendored protocol retains the upstream copyright and license. Temporary
source fixtures are removed; logs, screenshots, and the result remain.

Checks cover:

- Complete baseline load, baseline → candidate hot reload, and independent cold start.
- A fresh generation's IPC, native bar geometry, and nonempty rendered pixels.
- The production deployment health endpoint and stats content on every test output.
- Actual bar expansion/collapse, reversal and pointer travel without stealing focus.
- Same native window, fixed application reservation and stable surface size in both bar positions.
- Local telemetry, Ash offline/data states, and remote sampler shutdown on close.
- Normal and 1.25 font scale with populated bar captures, plus return to the baseline in the same process.
- Content-fitted stats panel height and compact offline layout without unused space.
- Telemetry accounting, deployment failure regressions, and setup shell syntax.

The sandbox provides deterministic read-only `hyprctl` fixtures. It does not
validate Hyprland-specific fullscreen behavior, compositor blur, real remote
reachability, authentication, or every shell interaction. Its missing desktop
services produce baseline diagnostics; those are saved explicitly, and any new
warning/error fails the check. Inspect screenshots for appearance: geometry and
pixel checks cannot judge visual quality.

## Applying and recovering

A passing report binds the source tree, test cases, tooling, binary version,
recorded baseline and invariant live files. It expires after 30 minutes. Changed
source or tests require another check. Deployment requires committed Quickshell
source and rechecks the live state immediately before writing.

File watching is paused while committed files are written in place. The initial
bootstrap, before the deployment IPC exists, briefly stops the process with an
independent resume watchdog. Normal deployments use the IPC watcher control.
Neither path kills the running shell. A fresh generation, native bars and visible
stats content are required before recording a release as good.

On failure the tool restores touched files from the previous Git commit and
checks a fresh restored load. It creates no backups. A failed QML reload can keep
the previous valid generation alive; the tool preserves it. If the process
crashes or lock state becomes unknown, it reports that recovery needs attention
instead of restarting a potentially locked session. This reduces breakage; it
does not make arbitrary runtime bugs impossible.

## Research behind the gate

Qt documents [qmllint's dependence on module/type information](https://doc.qt.io/qt-6/qtqml-tooling-qmllint.html).
Static linting alone cannot verify this complete dynamic shell graph.
[Quickshell exposes reload and file-watching controls](https://quickshell.org/docs/v0.2.0/types/Quickshell/Quickshell/);
the installed revision's root-wrapper source was checked to confirm failed
loads retain the prior generation. Consequently an old working IPC endpoint is
insufficient proof of a successful reload. The gate verifies a new generation.
[wlroots documents the headless backend](https://github.com/swaywm/wlroots/blob/master/docs/env_vars.md),
which allows actual layer-surface tests without opening windows on the desktop.
