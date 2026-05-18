# Void Linux — lean gaming box (Steam + Faugus + games, instant)

A **minimal, clean, efficient** Void Linux install whose only job is: boot into
KDE Plasma 6 (Wayland), run **Steam** + **Faugus Launcher**, and play games —
with the **RTX 3090** driver correct. Dual-booted on a separate disk; Bazzite
stays untouched.

> Originally a full Bazzite-replica (dev + gaming daily driver), trimmed to the
> lean gaming scope: no dev stack, no Bazzite-replica bloat. Flatpak is back as
> a **thin layer** (it's the clean way to get Faugus). `docs/01` (dual-boot)
> and `docs/05` (maintenance) are unchanged and still apply.

## Locked decisions (this scope)

| Decision | Choice | Why |
|---|---|---|
| Desktop | **KDE Plasma 6, Wayland** | Best NVIDIA-Wayland path in 2026; VRR+HDR exposed in GUI. |
| KDE size | **`kde-plasma` only** (no `kde-baseapps`) + konsole + dolphin | `kde5` no longer exists. `kde-plasma` already bundles plasma-nm/pa, bluedevil, portal, powerdevil, polkit agent. Skipping the apps meta is the lean win. |
| Driver | `nvidia` (DKMS) + `nvidia-libs-32bit` | RTX 3090 = Ampere → current branch. 32-bit libs mandatory or games won't launch. |
| Flatpak | **Thin layer** (Flathub + a tiny curated list) | Back by request — it's the clean path for Faugus & a few apps not in xbps. |
| Steam | **native `steam`** | Leaner than Flatpak Steam. Requires Void Steam-Runtime fixes — baked into `bootstrap.sh`. |
| Faugus | **Flatpak** `io.github.Faugus.faugus-launcher` | With Flatpak back, this is a one-line clean install (bundles UMU, auto GE-Proton). The fragile source build is now a fallback only. |
| Also | native **`lutris`** | One xbps command, same job as Faugus (per-game Proton + GE-Proton). Use whichever UI you like. |
| Install | Separate disk, Bazzite untouched (`docs/01`) | Unchanged. |

### Honest notes

- **Faugus** is clean via Flatpak now — the earlier "fragile source build"
  problem only applies if you disable Flatpak (`docs/00` + `faugus.sh` are that
  fallback).
- **Native Steam on Void** hits the recurring Steam-Linux-Runtime `/usr/lib64`
  breakage (gconv/libudev/nofile). Since Steam stays native, those fixes are
  **mandatory** and `bootstrap.sh` applies them by default.
- VRR/Adaptive-Sync and HDR are in *System Settings → Display & Monitor* and
  work on the proprietary driver under Wayland in 2026.

## Repo layout

```
README.md                  this file
docs/
  01-install-dualboot.md   safe separate-disk install (unchanged)
  02-nvidia-kde.md          RTX 3090 + lean KDE Plasma 6 Wayland
  03-gaming.md              native Steam + Lutris + Flatpak Faugus
  00-faugus-optional.md     no-Flatpak source fallback ONLY (you won't need it)
  05-maintenance.md         rolling-release survival (unchanged)
pkgs/
  10-core.txt 20-desktop.txt 30-nvidia.txt 40-gaming.txt
  flatpaks.txt             tiny curated Flatpak list (Faugus + commented extras)
etc/
  modprobe.d/nvidia.conf  dracut.conf.d/nvidia.conf  sddm.conf.d/10-wayland.conf
services.txt               runit services to enable
bootstrap.sh               idempotent provisioner (Steam fixes + Flatpak baked in)
faugus.sh                  no-Flatpak source fallback (don't use unless needed)
```

## Use it

1. Install Void on the second disk — `docs/01-install-dualboot.md` (glibc,
   Btrfs root, GRUB to disk 2 only, disk 1 disconnected).
2. First boot:
   ```sh
   git clone <this repo> ~/void && cd ~/void
   ./bootstrap.sh     # repos → update → pkgs → nvidia → KDE → services → Steam fixes → Flatpak/Faugus
   sudo reboot
   ```
   Flags: `--no-flatpaks` (Flathub only, skip the apps list) ·
   `--faugus-src` (fallback source build instead of the Flatpak) ·
   `--no-update` · `--dry-run`.
3. At SDDM pick **Plasma (Wayland)**. Steam → enable Steam Play for all titles.
   Faugus Launcher is in the app menu (Flatpak).
4. Verify: `nvidia-smi`; `cat /sys/module/nvidia_drm/parameters/modeset` → `Y`;
   `vkcube` shows the 3090.
5. Non-Steam / Epic / GOG: Faugus or native `lutris` (both have GE-Proton).
6. VRR/HDR: System Settings → Display & Monitor.

`bootstrap.sh` is idempotent, refuses to run on non-Void, never touches disk 1
or the bootloader.
