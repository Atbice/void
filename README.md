# Void Linux — lean gaming box (Steam + games, instant)

A **minimal, clean, efficient** Void Linux install whose only job is: boot into
KDE Plasma 6 (Wayland), run **Steam**, and play games — with the **RTX 3090**
driver correct and **zero Flatpak**. Dual-booted on a separate disk; Bazzite
stays untouched.

> This repo was originally a full Bazzite-replica (dev + gaming daily driver).
> It has been **trimmed to the lean gaming scope**. The dev stack and all
> Flatpak tooling were removed. `docs/01` (dual-boot) and `docs/05`
> (maintenance) are unchanged and still apply.

## Locked decisions (this scope)

| Decision | Choice | Why |
|---|---|---|
| Desktop | **KDE Plasma 6, Wayland** | You chose it; in 2026 it's the best NVIDIA-Wayland path, VRR+HDR exposed in GUI. |
| KDE size | **`kde-plasma` only** (no `kde-baseapps`) + konsole + dolphin | `kde5` no longer exists. `kde-plasma` already bundles plasma-nm/pa, bluedevil, portal, powerdevil, polkit agent. Skipping the apps meta is the lean win. |
| Driver | `nvidia` (DKMS) + `nvidia-libs-32bit` | RTX 3090 = Ampere → current branch. 32-bit libs are mandatory or games won't launch. |
| Flatpak | **None** | Your call. Everything below is native xbps. |
| Steam | **native `steam`** | No Flatpak. Requires the Void Steam-Runtime fixes (now mandatory — baked into `bootstrap.sh`). |
| Game launcher | **native `lutris`** (Faugus = optional `faugus.sh`) | Lutris is one xbps command, upgrade-safe, and does everything Faugus does (per-game Proton prefixes + GE-Proton downloader). Faugus-without-Flatpak is a fragile source build — opt-in only. |
| Install | Separate disk, Bazzite untouched (`docs/01`) | Unchanged from before. |

### Honest notes

- **Faugus specifically**: not packaged on Void; needs source build + `pip`
  (`vdf`, `icoextract`) + source umu-launcher (Rust). It rots on Python
  upgrades. `faugus.sh` does it if you insist, but Lutris is the clean answer.
- **Native Steam on Void** hits the recurring Steam-Linux-Runtime `/usr/lib64`
  breakage (gconv/libudev). With Flatpak off the table these fixes are
  **mandatory**, so `bootstrap.sh` applies them by default (not opt-in).
- VRR/Adaptive-Sync and HDR are in *System Settings → Display & Monitor* and
  work on the proprietary driver under Wayland in 2026.

## Repo layout

```
README.md                  this file
docs/
  01-install-dualboot.md   safe separate-disk install (unchanged)
  02-nvidia-kde.md          RTX 3090 + lean KDE Plasma 6 Wayland
  03-gaming.md              native Steam + Lutris, mandatory Void fixes
  00-faugus-optional.md     ONLY if you really want Faugus (fragile)
  05-maintenance.md         rolling-release survival (unchanged)
pkgs/
  10-core.txt 20-desktop.txt 30-nvidia.txt 40-gaming.txt
etc/
  modprobe.d/nvidia.conf  dracut.conf.d/nvidia.conf  sddm.conf.d/10-wayland.conf
services.txt               runit services to enable
bootstrap.sh               idempotent provisioner (Steam fixes baked in)
faugus.sh                  optional, fragile Faugus-from-source installer
```

## Use it

1. Install Void on the second disk — `docs/01-install-dualboot.md` (glibc,
   Btrfs root, GRUB to disk 2 only, disk 1 disconnected).
2. First boot:
   ```sh
   git clone <this repo> ~/void && cd ~/void
   ./bootstrap.sh          # repos → update → packages → nvidia → KDE → services → Steam fixes
   sudo reboot
   ```
3. At SDDM pick **Plasma (Wayland)**. Launch Steam, enable Steam Play for all
   titles, install a game.
4. Verify: `nvidia-smi`; `cat /sys/module/nvidia_drm/parameters/modeset` → `Y`;
   `vkcube` shows the 3090.
5. Non-Steam / Epic / GOG games: `lutris` (built-in GE-Proton downloader).
6. (Optional, not recommended) Faugus: `./faugus.sh` — read its header first.

`bootstrap.sh` is idempotent, refuses to run on non-Void, and never touches
disk 1 / the bootloader.
