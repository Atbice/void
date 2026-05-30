# 00 — Faugus from SOURCE (no-Flatpak fallback ONLY)

> **You almost certainly don't need this.** Flatpak is in the stack, so the
> clean way to run Faugus is the Flatpak `io.github.Faugus.faugus-launcher`
> (installed by `bootstrap.sh` from `pkgs/flatpaks.txt`). See `docs/03`.
>
> This document + `faugus.sh` exist only for the case where you have
> **deliberately disabled Flatpak** and still want Faugus. It is a fragile,
> unmanaged source build. Prefer the Flatpak, or use native Lutris.

## Why the source path is fragile on Void

- `faugus-launcher` is not in xbps (no `srcpkgs/faugus-launcher`) — a meson/ninja
  source build you maintain by hand.
- `umu-launcher` (its runtime) is also not in xbps — a separate source build
  (Rust toolchain + git submodules + a PEP517 Python build).
- Updates are a manual `git` pull + rebuild, not `xbps-install -Su`.

(Its Python deps `python3-vdf` and `python3-icoextract` **are** in xbps now, so
the old pipx/pip workaround is gone — that part is no longer fragile.)

The Flatpak has none of these problems (it bundles everything and updates with
`flatpak update`).

## What `faugus.sh` does (only if you run it with `--faugus-src`)

1. `xbps-install` all build + runtime deps, including `python3-vdf` and
   `python3-icoextract` (no pipx/pip) plus umu's PEP517 build backends
   (`python3-build`, `python3-installer`, `hatchling`, `python3-setuptools`).
2. Build + install **umu-launcher** from source.
3. Build + install **faugus-launcher** from source.

## Maintenance you own forever (if you go this route)

- Faugus/umu updates are a manual `git pull` + rebuild (re-run the script), not
  `xbps-install -Su`. Their xbps-provided deps DO update normally.
- The umu/faugus binaries themselves aren't tracked by xbps; this repo's package
  lists won't capture them.

## Sources

- <https://flathub.org/apps/io.github.Faugus.faugus-launcher> (the clean path)
- <https://github.com/Faugus/faugus-launcher>
- <https://github.com/Open-Wine-Components/umu-launcher>
