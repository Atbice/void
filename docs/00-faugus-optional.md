# 00 — Faugus Launcher (OPTIONAL, fragile, not recommended)

> Read this before running `faugus.sh`. The clean answer for your goal is
> **Lutris** (`docs/03`). Faugus on Void-without-Flatpak is a hand-assembled
> source build with dependencies outside xbps that **will rot on Python
> upgrades**. Rated ~4/10 for "clean / instant". Use only if you specifically
> want Faugus's UI; it offers no capability Lutris lacks.

## Why it's fragile on Void

- Not in xbps (no `srcpkgs/faugus-launcher`) — source build via meson/ninja.
- `umu-launcher` (its runtime) is also **not** in xbps — separate source build
  (needs the Rust toolchain + git submodules).
- Two Python deps, `vdf` and `icoextract`, are **not in xbps at all** — must be
  installed with `pipx`/`pip`, i.e. outside the package manager. These break
  silently when Void rolls Python forward; you must remember to reinstall them.

## The upside (only one)

UMU/Faugus **auto-download GE-Proton** (set `PROTONPATH=GE-Proton`). So no
ProtonUp-Qt and no Flatpak are needed for Proton management. (Lutris does this
too, via its built-in downloader.)

## What `faugus.sh` does

1. `xbps-install` the available deps:
   `meson ninja git python3-gobject python3-cairo python3-Pillow python3-psutil
   python3-requests python3-pygame gtk+3 libayatana-appindicator libcanberra
   ImageMagick vulkan-tools rust cargo scdoc`
2. `pipx install vdf icoextract` (the xbps gap — outside the package manager).
3. Build + install **umu-launcher** from
   `github.com/Open-Wine-Components/umu-launcher` (`./configure.sh && make &&
   make install`).
4. Build + install **faugus-launcher** from `github.com/Faugus/faugus-launcher`
   (`meson setup builddir --prefix=/usr && ninja -C builddir && ninja install`).

## Maintenance you own forever

- After any Void Python major bump: `pipx reinstall-all` (or the `vdf`/
  `icoextract` import fails and Faugus won't start).
- Faugus/umu updates are manual `git pull` + rebuild — not `xbps-install -Su`.
- Nothing here is tracked by xbps; this repo's package list will not capture it.

## Sources

- <https://github.com/Faugus/faugus-launcher>
- <https://aur.archlinux.org/packages/faugus-launcher> (dependency truth)
- <https://github.com/Open-Wine-Components/umu-launcher>
