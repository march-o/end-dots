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
- Static IPv4 `192.168.8.33/24` on `Wired connection 1`, with gateway and DNS
  at `192.168.8.1`.
- OpenSSH server enabled at boot on the standard SSH port.
- Codex always uses the alternate-screen TUI so its input composer stays
  docked while scrolling through the conversation.
- Wallpapers cycle through `~/Wallpapers` at each Hyprland login and with
  `Ctrl+Super+Alt+T`.
- The end-4 lock screen is passwordless (`Enter` unlocks it), while SDDM login
  and `sudo` still require normal authentication. Idle displays turn off after
  10 minutes and the machine suspends after 15 minutes.

## Apply the personal system profile

The normal Arch dependency installation invokes the profile automatically.
It can also be reapplied independently:

```bash
yay -S --needed ii-material-sddm-git
./sdata/dist-arch/setup-martins.sh
```

The script is idempotent. It updates shell plugins, installs the tracked shell
files, configures zram and SDDM, and sets Zsh as the login shell.

Apply the machine-specific static address separately:

```bash
./sdata/dist-arch/setup-static-ip.sh
```

Return the connection to DHCP if the network changes:

```bash
./sdata/dist-arch/setup-static-ip.sh dhcp
```

## Update from upstream

```bash
git fetch upstream
git merge upstream/main
```

Apply the current checkout after creating or pulling changes:

```bash
./setup update
```

Use the laptop role to also apply keyd configuration:

```bash
LAPTOP=1 ./setup update
```

Keep personal behavior in the files added by this fork or in Hyprland's
`custom/*.lua` files to minimize future merge conflicts.
