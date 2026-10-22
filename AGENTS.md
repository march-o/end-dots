# Project Instructions

- Keep changes focused on Arch only; do not update Fedora or Nix when making changes.
- Never create backups of files or directories.
- After completing and verifying requested repository changes, commit and push them automatically unless the user says otherwise. Include only the changes for the current task and preserve unrelated work.
- For normal backend/personal UI work, use Ash's native personal Chrome and window-ownership catalogs; preserve existing GUI behavior and focus unless the user requests otherwise.
- For Quickshell changes, read and apply `sdata/dist-arch/skills/quickshell/SKILL.md`; pair UI preference work with the `ui-design` skill without duplicating its guidance. When a Quickshell task reveals a verified, reusable lesson, update that skill in the same change.
- New Quickshell widgets must use the shared glass design from the first implementation: `GlassPanelWindow`, `GlassPanel`, `GlassColors`, `GlassTextField`, and the existing glass buttons. Extend these shared components when a capability is missing instead of creating a widget-specific surface or palette. Follow the shared-widget recipe in the Quickshell skill.

## Codex CLI status bar

- Arch uses a patched Codex 0.160.0 binary. Status-line item selection is in `sdata/dist-arch/config/codex.toml`; custom labels, colors, and Git diff behavior are in `sdata/dist-arch/patches/codex-0.160.0-git-diff-statusline.patch`.
- Run `sdata/dist-arch/bin/build-codex-statusline` to clone the pinned upstream tag, apply the patch, build with the cache at `~/.cache/codex-statusline-target`, and install `~/.local/bin/codex-statusline-0.160.0` with `~/.local/bin/codex` pointing to it. Restart Codex to see changes.
- When changing the patch, edit an upstream checkout with the existing patch applied, then regenerate the complete patch with `git diff`, excluding build-generated `Cargo.lock` version churn. Keep status-line previews and affected tests consistent with the live labels; percentage parsing drives the remaining-limit colors.
- Ash uses Codex 0.163.0 with the matching `codex-0.163.0-git-diff-statusline.patch`. Build with `CODEX_STATUSLINE_INSTALL=0 sdata/dist-arch/bin/build-codex-statusline 0.163.0` to retain the desktop's installed version. Strip a staging copy of `~/.cache/codex-statusline-target/debug/codex` and install it under Ash's `~/.local/lib/codex-statusline/0.163.0/bin/codex`; point `~/.local/bin/codex` there. Retain package metadata and links to the matching stock release's `codex-resources`, `codex-path`, and `bin/codex-code-mode-host` so bundled tools remain available; keep that stock release installed while the patch is in use. Ash's interactive shell prioritizes `~/.local/bin`; non-login SSH can still resolve the older system npm launcher. Use `context-remaining` and enable `status_line_use_colors` in Ash's `~/.codex/config.toml`.
