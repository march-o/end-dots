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
