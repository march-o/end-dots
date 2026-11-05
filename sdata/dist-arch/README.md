# Install scripts for Arch Linux

- See also [Install scripts | illogical-impulse](https://ii.clsty.link/en/dev/inst-script/)

## Old Dependency Installation Method
The old deps install method mainly involved `./sdata/dependencies.conf` (which has been removed now).

## Current Dependency Installation
Local PKGBUILDs under `./sdata/dist-arch/` are used to install dependencies.

The mechanism is introduced by [Makrennel](https://github.com/Makrennel) in [PR#570](https://github.com/end-4/dots-hyprland/pull/570).

Why is this awesome?
- It makes it possible to control version since some packages may involve breaking changes from time to time.
- It makes the dependency trackable for package manager, so that you always know why you have installed some package.
- As a result, it enables a workable uninstall process.

The PKGBUILDs contains two forms of dependencies:
- Package name written in dependencies, like a "meta" package.
- Normal PKGBUILD content to build dependencies, e.g. AGS, which is often for version controlling.

## Note
- `pkgver()` should be removed from `PKGBUILD` cuz it will modify the `PKGBUILD` which is tracked by Git and should not be modified during building.

## Laptop keyd setup
Set `LAPTOP=1` when running the setup to install keyd, deploy the Colemak-DH configuration, and enable its service on systemd:

```sh
LAPTOP=1 ./setup install
```

## Apply repository updates

After creating or pulling changes, create the repo-local `.env` and apply the
current checkout with:

```sh
cp -n .env.example .env
# Set LAPTOP=0 on the PC or LAPTOP=1 on the laptop.
./setup update
```

The command requires `.env` with a valid `LAPTOP` setting. An explicit
environment value takes precedence, but `.env` must still exist.

## Codex remote control

`setup-martins.sh` enables the managed Codex daemon's persistent remote-control
preference and installs a user service to start it at boot. User lingering keeps
it available after logout while the machine is awake and online. Codex must be
installed at `~/.local/bin/codex` and signed in with ChatGPT.

Apply only this configuration, without running the full desktop setup:

```sh
bash sdata/dist-arch/install-codex-remote-control.sh
systemctl --user status codex-remote-control.service
```

The service uses `codex remote-control start --json`; a bare
`codex remote-control --json` runs a separate foreground server. Remote-control
preferences live in Codex's managed daemon settings, not the retired
`features.remote_control` config flag. Pair a new controlling device with
`codex remote-control pair` when needed. Stopping the startup service leaves
active chats running; use `codex app-server daemon disable-remote-control` to
turn off remote access.

## Workspace alignment

Super+Space closes gaps between occupied numbered workspaces across all monitors:
windows on 1, 3, and 7 become workspaces 1, 2, and 3. Bare Super opens the overview.
Alignment changes workspace IDs in place, preserving layouts, fullscreen, monitor
placement, and focus. Special and named workspaces with managed negative IDs stay
untouched; retained empty workspaces swap into the vacated slots.

Run the desktop-independent regression scenarios from the repository root:

```sh
lua sdata/dist-arch/tests/test_workspace_alignment.lua
```
