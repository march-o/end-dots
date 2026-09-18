# Martins' Arch profile

This fork tracks the personal Arch setup on top of upstream end-4 dots.
Fedora and Nix configurations are intentionally left unchanged.

## Included preferences

- Zsh with Oh My Zsh, Powerlevel10k, fzf-tab, autosuggestions, syntax
  highlighting, zoxide, and direnv.
- `cod` runs `codex --dangerously-bypass-approvals-and-sandbox`. This alias
  intentionally disables Codex approvals and sandboxing.
- An 8 GiB zstd zram swap device at priority 100.
- The `ii-material-sddm` login theme, including access to end-4's generated
  Material colors and wallpaper.

## Apply the personal system profile

The normal Arch dependency installation invokes the profile automatically.
It can also be reapplied independently:

```bash
yay -S --needed ii-material-sddm-git
./sdata/dist-arch/setup-martins.sh
```

The script is idempotent. It updates shell plugins, installs the tracked shell
files, configures zram and SDDM, and sets Zsh as the login shell.

## Update from upstream

```bash
git fetch upstream
git merge upstream/main
```

Keep personal behavior in the files added by this fork or in Hyprland's
`custom/*.lua` files to minimize future merge conflicts.
