# 00 — Faugus from SOURCE (no-Flatpak fallback ONLY)

> **You almost certainly don't need this.** Flatpak is in the stack, so the
> clean way to run Faugus is the Flatpak `io.github.Faugus.faugus-launcher`
> (installed by `bootstrap.sh` from `pkgs/flatpaks.txt`). See `docs/03`.
>
> This document + `faugus.sh` exist only for the case where you have
> **deliberately disabled Flatpak** and still want Faugus. It is a fragile,
> unmanaged source build. Prefer the Flatpak, or use native Lutris.

## Why the source path is fragile on Void

- Not in xbps (no `srcpkgs/faugus-launcher`) — meson/ninja source build.
- `umu-launcher` (its runtime) is also not in xbps — separate source build
  (Rust toolchain + git submodules).
- `vdf` and `icoextract` are not in xbps **at all** — installed via
  `pipx`/`pip`, outside the package manager. These break silently on Void
  Python major bumps; you must remember to `pipx reinstall-all`.

The Flatpak has none of these problems (it bundles everything and updates with
`flatpak update`).

## What `faugus.sh` does (only if you run it with `--faugus-src`)

1. `xbps-install` the available build/runtime deps.
2. `pipx install vdf icoextract` (the xbps gap — unmanaged).
3. Build + install **umu-launcher** from source.
4. Build + install **faugus-launcher** from source.

## Maintenance you own forever (if you go this route)

- After any Void Python major bump: `pipx reinstall-all` or Faugus won't start.
- Faugus/umu updates are manual `git pull` + rebuild, not `xbps-install -Su`.
- Not tracked by xbps; this repo's package lists won't capture it.

## Sources

- <https://flathub.org/apps/io.github.Faugus.faugus-launcher> (the clean path)
- <https://github.com/Faugus/faugus-launcher>
- <https://github.com/Open-Wine-Components/umu-launcher>
