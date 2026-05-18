# 02 — RTX 3090 + KDE Plasma 6 (Wayland) on Void

**Recommendation: daily-drive Wayland.** As of 2026 (Plasma ≥ 6.1 explicit-sync
via `linux-drm-syncobj-v1`, Void `nvidia` ≈ 595.71.05) NVIDIA+Plasma Wayland on
Ampere is the mainstream, well-behaved path and matches your Bazzite experience.
Keep an X11 session installed only as a rare-regression fallback.

## Driver model (key mental-model shift from Bazzite)

- RTX 3090 = Ampere → the **current `nvidia` package** (NOT a legacy `nvidia580/470/390`).
  For Turing+ it ships NVIDIA's **open GSP kernel module** (proprietary userspace) —
  there is no "open vs proprietary" choice to agonize over; `nvidia` is correct.
- Lives in `void-repo-nonfree`. Pulls `nvidia-libs`, `nvidia-gtklibs`,
  `nvidia-dkms`, `nvidia-firmware`.
- **DKMS-built** — not akmods, not prebuilt. `xbps-triggers` fires the DKMS build
  *and* `initramfs-regenerate` automatically on driver/kernel updates. DKMS logs:
  `/var/lib/dkms/`.
- The package's `modprobe.d` already **blacklists nouveau** — no manual blacklist
  needed.
- **No `nvidia-suspend/resume` runit services exist** (those are systemd-only on
  other distros). Suspend/resume is handled by the modparam below instead.

## Config this repo ships

`etc/modprobe.d/nvidia.conf` (your override; `bootstrap.sh` installs it):
```
options nvidia-drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
```
`NVreg_PreserveVideoMemoryAllocations=1` is *the* fix for NVIDIA suspend/resume
VRAM corruption without the systemd nvidia units Void doesn't have.

`etc/dracut.conf.d/nvidia.conf`:
```
add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "
```
Then `xbps-reconfigure -fa` rebuilds the initramfs with the modules baked in
(bootstrap.sh does this).

GBM is the default backend on Plasma 6 (EGLStreams is dead). With driver 595 +
Plasma 6.x you do **not** need `GBM_BACKEND` / `__GLX_VENDOR_LIBRARY_NAME` env
vars. Explicit sync removes the old flicker/tearing automatically.

## Ordered sequence (base Void → Plasma 6 Wayland + 3090)

`bootstrap.sh` automates all of this; shown here so you understand it:

```sh
# 1. Repos
sudo xbps-install -S void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree
sudo xbps-install -Su          # FULL update first; run TWICE (xbps self-update gotcha)

# 2. NVIDIA driver + 32-bit libs
sudo xbps-install -S nvidia nvidia-libs-32bit

# 3. modprobe + dracut configs (from etc/ in this repo), then rebuild initramfs
sudo cp etc/modprobe.d/nvidia.conf /etc/modprobe.d/nvidia.conf
sudo cp etc/dracut.conf.d/nvidia.conf /etc/dracut.conf.d/nvidia.conf
sudo xbps-reconfigure -fa

# 4. KDE Plasma 6 + SDDM + session deps
#    ⚠️ VERIFY metapackage names: handbook KDE page. Historically kde5/kde5-baseapps
#       install Plasma 6; some docs say kde-plasma/kde-baseapps.
sudo xbps-install -S xorg-minimal xorg-fonts kde5 kde5-baseapps sddm \
                     dbus elogind NetworkManager xdg-desktop-portal-kde

# 5. Enable services (runit) — symlink into /var/service
for s in dbus elogind NetworkManager chronyd sddm; do
  sudo ln -s /etc/sv/$s /var/service/ 2>/dev/null || true
done

sudo reboot   # then pick "Plasma (Wayland)" at SDDM
```

> `xorg-minimal` is required even for a pure-Wayland session because SDDM's
> greeter still uses X by default.

## Post-boot sanity checks

```sh
cat /sys/module/nvidia_drm/parameters/modeset   # → Y
nvidia-smi                                       # driver loaded, 3090 visible
echo $XDG_SESSION_TYPE                           # → wayland
kscreen-doctor -o                                # outputs/refresh
```

## Sources

- Void Handbook — NVIDIA: <https://docs.voidlinux.org/config/graphical-session/graphics-drivers/nvidia.html>
- Void Handbook — KDE: <https://docs.voidlinux.org/config/graphical-session/kde.html>
- Void Handbook — Wayland: <https://docs.voidlinux.org/config/graphical-session/wayland.html>
- KDE Community Wiki — Plasma/Wayland/Nvidia: <https://community.kde.org/Plasma/Wayland/Nvidia>
- void-packages `srcpkgs/nvidia/template`: <https://github.com/void-linux/void-packages/blob/master/srcpkgs/nvidia/template>
