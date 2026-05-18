# 03 — Gaming: native Steam + Lutris (no Flatpak)

Scope: get games running instantly with the leanest native stack. No Flatpak.

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

## Faugus Launcher — optional, not recommended (see `docs/00`)

Faugus is **not packaged** on Void and needs a fragile from-source install
(pip `vdf`/`icoextract` + source umu-launcher/Rust) that rots on Python
upgrades. It adds maintenance burden for no capability Lutris doesn't already
cover. If you still want it: `./faugus.sh` (read `docs/00-faugus-optional.md`
first). To make it your default instead of Lutris, just run `faugus.sh` — both
can coexist.

## Sources

- Void steam `README.voidlinux`: <https://github.com/void-linux/void-packages/blob/master/srcpkgs/steam/files/README.voidlinux>
- Void `lutris` template: <https://github.com/void-linux/void-packages/blob/master/srcpkgs/lutris/template>
- steam-runtime #680 (gconv): <https://github.com/ValveSoftware/steam-runtime/issues/680>
- steam-runtime #533 (libudev): <https://github.com/ValveSoftware/steam-runtime/issues/533>
- steam-for-linux #11302 (nofile limit): <https://github.com/ValveSoftware/steam-for-linux/issues/11302>
