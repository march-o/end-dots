# Project Instructions

- Keep changes focused on Arch only; do not update Fedora or Nix when making changes.
- Never create backups of files or directories.
- After completing and verifying requested repository changes, commit and push them automatically unless the user says otherwise. Include only the changes for the current task and preserve unrelated work.
- For normal backend/personal UI work, use Ash's native personal Chrome and window-ownership catalogs; preserve existing GUI behavior and focus unless the user requests otherwise.
- For Quickshell changes, read and apply `sdata/dist-arch/skills/quickshell/SKILL.md`; pair UI preference work with the `ui-design` skill without duplicating its guidance. When a Quickshell task reveals a verified, reusable lesson, update that skill in the same change.
- New Quickshell widgets must use the shared glass design from the first implementation: `GlassPanelWindow`, `GlassPanel`, `GlassColors`, `GlassTextField`, and the existing glass buttons. Extend these shared components when a capability is missing instead of creating a widget-specific surface or palette. Follow the shared-widget recipe in the Quickshell skill.
