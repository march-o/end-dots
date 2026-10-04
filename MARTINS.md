# Martins' Arch profile

This fork tracks the personal Arch setup on top of upstream end-4 dots.
Fedora and Nix configurations are intentionally left unchanged.

## Included preferences

- Zsh with Oh My Zsh, Powerlevel10k, fzf-tab, autosuggestions, syntax
  highlighting, zoxide, and direnv.
- `cod` runs `codex --dangerously-bypass-approvals-and-sandbox`. This alias
  intentionally disables Codex approvals and sandboxing.
- `dot` starts Codex in `~/.config/dotfiles`; `dotr` resumes the latest
  session there. Both use the same Codex options as `cod` and `codr`.
- An 8 GiB zstd zram swap device at priority 100.
- The `ii-material-sddm` login theme, including access to end-4's generated
  Material colors and wallpaper.
- Static IPv4 `192.168.8.33/24` on `Wired connection 1`, with gateway and DNS
  at `192.168.8.1`.
- OpenSSH server enabled at boot on the standard SSH port.
- Codex always uses the alternate-screen TUI so its input composer stays
  docked while scrolling through the conversation.
- Wallpapers in the ignored `~/.config/dotfiles/wallpapers/` directory cycle
  at each Hyprland login, with `Ctrl+Super+Alt+T`, and with the button beside
  the bar clock. Copy the images separately when setting up another machine.
- On the PC, inactivity locks the screen after 10 minutes without suspending.
  The passwordless lock screen (`Enter` unlocks it) dims visually after five
  minutes; only keyboard activity clears the dimming. It has a button to turn
  the monitor off, which mouse or keyboard activity wakes. It uses a removable
  overlay, so a QuickShell crash cannot leave the
  compositor locked. If the overlay stops responding, `Ctrl+Alt+Super+Esc`
  restarts QuickShell and dismisses it. SDDM login and `sudo` still require
  normal authentication.
- On the laptop, hold right Alt for Latvian letters while keeping the normal
  Colemak-DH typing layout. For example, right Alt+A types `ā`.
- Browser activation requests do not move focus away from the current app on
  the laptop; Codex is also instructed to keep browser work in the background.
- On the laptop, SDDM automatically starts the Hyprland session at boot and
  QuickShell opens its passwordless lock overlay. SDDM is only enabled for the
  next boot; applying these settings does not restart the live session.

## Apply the personal system profile

Clone this Arch setup into the same path on the PC and laptop:

```bash
git clone git@github.com:march-o/end-dots.git "$HOME/.config/dotfiles"
cd "$HOME/.config/dotfiles"
```

On the PC, run `cp .env.example .env`. On the laptop, run
`printf 'LAPTOP=1\n' > .env`. Then install with `./setup install`.
The tracked Zsh configuration provides `dot` and `dotr` on both machines.

The normal Arch dependency installation invokes the profile automatically.
It can also be reapplied independently:

```bash
yay -S --needed ii-material-sddm-git
./sdata/dist-arch/setup-martins.sh
```

The script is idempotent. It updates shell plugins, installs the tracked shell
files, configures zram and SDDM, and sets Zsh as the login shell.

To apply the current checkout on either machine:

```bash
git pull --ff-only origin main
cp -n .env.example .env
# Set LAPTOP=1 in .env on the laptop; use LAPTOP=0 on the PC.
./setup update
```

The local `.env` is ignored by Git and required by `./setup update`. The command
applies all tracked dotfiles and the personal Arch system profile. `LAPTOP=1`
also installs the tracked keyd configuration and enables its service. An exported
`LAPTOP` value overrides the value in `.env` for one run, but `.env` must still
exist and contain a valid setting. The command reloads Hyprland when a session
is active; Spotify autostart runs at the next login. The tracked
`sdata/dist-arch/config/devices/{desktop,laptop}.env` files select sizes for
Kitty, QuickShell, and GTK/Chrome based on `.env`'s `LAPTOP` toggle. The laptop
uses 16 pt Kitty, 1.25 QuickShell font scale, and 1.5 GTK/Chrome scale; both
machines use the floating bar style. The Chrome launchers select personal and
work profiles by signed-in email, since profile directory names differ between
machines.
KDE/Qt font roles and Kitty's 14 pt font remain separately configured. The PC
defaults are unchanged.

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

Keep personal behavior in the files added by this fork or in Hyprland's
`custom/*.lua` files to minimize future merge conflicts.
