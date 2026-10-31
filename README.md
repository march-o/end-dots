# Desktop dotfiles

Personal desktop configuration for Arch Linux.

## Development

Develop directly in `/home/martins/.config/dotfiles` using `workflow.start_in_project` so changes can be tested live; use a worktree only when explicitly requested.

## Spotify widget

Hover the song title to expand the media card. Its volume control uses a thin
straight rail with cross-ribs and a current-level marker. Click or drag to snap
in 5% steps; scrolling moves to the next step. External volume changes remain
accurate, including levels between ribs. Playback controls are unchanged.

For Quickshell changes, run `sdata/dist-arch/bin/quickshell-ci`, inspect its
captures, and commit the tested source. After independent review, apply with
`sdata/dist-arch/bin/quickshell-apply apply --report /path/to/result.json` and
verify the live desktop. See `sdata/dist-arch/QUICKSHELL-CI.md` for the guarded
application procedure and checks.
