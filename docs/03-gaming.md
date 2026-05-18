# 03 — Gaming: native Steam + Lutris (no Flatpak)

Scope: games running instantly. Native Steam + Lutris, plus a thin Flatpak
layer for apps not in xbps (notably Faugus). Steam itself stays native.

## Packages (`pkgs/40-gaming.txt`, installed by bootstrap.sh)

```
steam lutris mono
libgcc-32bit libstdc++-32bit libdrm-32bit libglvnd-32bit libva-32bit
```

(`nvidia-libs-32bit` comes from `pkgs/30-nvidia.txt`. Proton bundles its own
DXVK/VKD3D. Lutris pulls Wine + its deps via xbps. No MangoHud/gamescope/vkBasalt
— not needed for "just play games"; add later if you want them.)

## Steam — mandatory Void fixes (Flatpak is NOT an escape hatch here)

Native Steam on Void hits Steam-Linux-Runtime / `/usr/lib64` breakage. Because
Flatpak Steam is excluded, `bootstrap.sh` applies these **by default**:

1. **gconv** (EAC / iconv games fail otherwise — steam-runtime #680):
   - idempotent symlink: `/usr/lib64/gconv → ../lib/gconv`
   - system-wide `GCONV_PATH=/usr/lib/gconv` via `/etc/profile.d/steam-void.sh`
2. **file-descriptor limit** (Proton "eventfd: Too many open files"):
   `/etc/security/limits.d/steam.conf` raises `nofile` to 1048576.
3. **groups**: your user added to `video,input` (controllers / GPU access).

If a specific game still errors on `libudev.so.0`, set per-game launch options:

```
LD_PRELOAD=/usr/lib/libudev.so.1 %command%
```

If SLR-forced titles segfault, toggle the compatibility tool off for that game.

## First run

1. Launch Steam, log in.
2. Settings → Compatibility → **Enable Steam Play for all other titles**
   (uses bundled Proton; no ProtonUp/Flatpak needed).
3. Per game, Properties → Compatibility → pick a Proton version. Install & play.
4. Controllers: wired Xbox/PS5 work in-kernel; the `steam` package ships the
   Steam Input udev rules. If a pad enumerates but games see no input,
   reinstall `steam`.

## Non-Steam / Epic / GOG — use Lutris

`lutris` is native xbps and is the clean answer for everything Faugus would do:

- Per-game Wine/Proton **prefixes**.
- Built-in **GE-Proton / Wine-GE downloader** (Lutris → Preferences → Runners).
- Native **UMU** support.
- Epic/GOG via Lutris install scripts.

One command, fully xbps-tracked, survives system upgrades. No pip, no source
builds.

## Faugus Launcher — via Flatpak (the clean way)

With Flatpak in the stack, Faugus is trivial and well-maintained:
`io.github.Faugus.faugus-launcher`. `bootstrap.sh` installs it from Flathub
(it's in `pkgs/flatpaks.txt`). It bundles UMU and auto-downloads GE-Proton —
nothing to hand-build. Launch it from the application menu.

Faugus and Lutris cover the same job (per-game Proton prefixes + GE-Proton);
use whichever UI you prefer — both are installed.

> The from-source `faugus.sh` / `docs/00-faugus-optional.md` now exist **only**
> as a no-Flatpak fallback. Don't use them unless you've disabled Flatpak.

## Sources

- Void steam `README.voidlinux`: <https://github.com/void-linux/void-packages/blob/master/srcpkgs/steam/files/README.voidlinux>
- Void `lutris` template: <https://github.com/void-linux/void-packages/blob/master/srcpkgs/lutris/template>
- steam-runtime #680 (gconv): <https://github.com/ValveSoftware/steam-runtime/issues/680>
- steam-runtime #533 (libudev): <https://github.com/ValveSoftware/steam-runtime/issues/533>
- steam-for-linux #11302 (nofile limit): <https://github.com/ValveSoftware/steam-for-linux/issues/11302>
