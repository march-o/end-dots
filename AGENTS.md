# Project Instructions

- Keep changes focused on Arch only; do not update Fedora or Nix when making changes.
- Never create backups of files or directories.
- For local GUI automation, inspect `deskctl capabilities` and use `deskctl open` instead of launching duplicate applications directly.
- `deskctl open` preserves the active window; use `deskctl focus` only when focus is explicitly requested.
