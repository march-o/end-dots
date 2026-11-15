# Desktop dotfiles

Personal desktop configuration for Arch Linux.

## Development

Develop directly in `/home/martins/.config/dotfiles` using `workflow.start_in_project` so changes can be tested live; use a worktree only when explicitly requested.

## Spotify widget

Hover the song title to expand the media card. Its volume control uses a
rounded rail with a wide current-level marker, restoring the pre-ribs design.
Click or drag to snap in 5% steps; scrolling moves to the next step. External
volume changes remain accurate, including levels between steps. Playback controls are unchanged.

For Quickshell changes, run `sdata/dist-arch/bin/quickshell-ci`, inspect its
captures, and commit the tested source. After independent review, apply with
`sdata/dist-arch/bin/quickshell-apply apply --report /path/to/result.json` and
verify the live desktop. See `sdata/dist-arch/QUICKSHELL-CI.md` for the guarded
application procedure and checks.

## Home lighting

The icon pill beside CPU/RAM discovers every saved preset from the existing Home
lighting owner on Ash, with an explicit all-lights Off action. Hover for names;
click to dispatch once. Icons use the bar's shared hover palette. A command receipt
is not an observed active scene, so the selector does not claim a persistent active
preset. Credentials remain on Ash; unavailable discovery and uncertain commands
are surfaced without automatic write retries. CPU/RAM now uses a 148px content
width instead of 284px (scaled with the configured font size).

Run `python3 sdata/dist-arch/tests/test_home_lighting.py` for the adapter contract.
The full Quickshell CI also exercises each production preset button with real
private-compositor hover/click input; its fixture never changes household lights.
