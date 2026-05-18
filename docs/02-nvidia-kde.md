# 02 — RTX 3090 + lean KDE Plasma 6 (Wayland)

Daily-drive **Wayland**. In 2026 (NVIDIA 590+/595, Plasma 6.5) NVIDIA-Wayland on
Ampere is the mainstream, well-behaved path.

## NVIDIA driver (this part is non-negotiable)

RTX 3090 = Ampere → the **current `nvidia` package** (NOT a legacy
`nvidia470/580`), from `void-repo-nonfree`. DKMS — auto-rebuilds on kernel
updates via xbps triggers. nouveau is auto-blacklisted by the package.

- **`nvidia-libs-32bit`** from `void-repo-multilib-nonfree` — *mandatory*; without
  it Steam/Proton games will not launch. This is the #1 mistake.
- `etc/modprobe.d/nvidia.conf` (installed by bootstrap.sh):
  `nvidia-drm modeset=1 fbdev=1` + `NVreg_PreserveVideoMemoryAllocations=1`
  (suspend/resume — Void has no systemd nvidia units).
- `etc/dracut.conf.d/nvidia.conf` bakes the modules into the initramfs;
  `xbps-reconfigure -fa` regenerates it.
- `modeset=1` is default-on in the 590+ packaging — **verify** anyway:
  `cat /sys/module/nvidia_drm/parameters/modeset` → must be `Y`.
- No `GBM_BACKEND` / `__GLX_VENDOR_LIBRARY_NAME` env vars needed with the
  current driver. GBM is the default.

## Lean KDE Plasma 6 — the resolved package set

`kde5` **no longer exists**. The current metapackage is **`kde-plasma`**
(Plasma 6.5.x). It already pulls plasma-nm, plasma-pa, bluedevil,
xdg-desktop-portal-kde, powerdevil, and (via plasma-desktop) the polkit-kde
agent. The lean win is **not installing `kde-baseapps`/`kde-applications`** —
we add only konsole + dolphin by hand.

```sh
sudo xbps-install -S \
  kde-plasma sddm konsole dolphin xorg-minimal \
  NetworkManager pipewire wireplumber libspa-bluetooth \
  elogind dbus polkit nvidia
```

- `xorg-minimal` is still required: the default SDDM **greeter** runs on X
  (the Plasma *session* is Wayland regardless). It's small.
- Enable PipeWire per the handbook (symlink the example
  `pipewire-pulse`/`wireplumber` autostarts into `/etc/xdg/autostart`).

### Optional: SDDM greeter on Wayland

`bootstrap.sh` installs `etc/sddm.conf.d/10-wayland.conf` (greeter via
`kwin_wayland`). Works on NVIDIA with the current driver. If the greeter
misbehaves, delete that file — the session stays Wayland either way.

## runit services

```sh
sudo ln -s /etc/sv/dbus           /var/service/   # FIRST — SDDM/NM depend on it
sudo ln -s /etc/sv/NetworkManager /var/service/
sudo ln -s /etc/sv/sddm           /var/service/   # LAST — after one interactive test
```

`elogind` on current Void is typically dbus/socket-activated with **no standalone
`/etc/sv/elogind`** — bootstrap.sh enables it only if that service dir exists,
and does not fail otherwise. Don't enable `dhcpcd` alongside NetworkManager.

## Session selection & verification

- At SDDM's session menu pick **"Plasma (Wayland)"** explicitly (SDDM defaults
  to X if both exist). To force: `Session=plasma` in `/etc/sddm.conf.d/`.
- Post-boot: `nvidia-smi`; `echo $XDG_SESSION_TYPE` → `wayland`;
  `cat /sys/module/nvidia_drm/parameters/modeset` → `Y`; `kscreen-doctor -o`.

## Gaming: VRR + HDR (Wayland + proprietary NVIDIA, 2026)

Both are exposed in **System Settings → Display & Monitor**:

- **Adaptive Sync** (Never/Automatic/Always) — works on the proprietary driver
  on Wayland in 2026 (the earlier multi-display VRR signal-loss bug is fixed in
  580+). "Allow tearing in fullscreen" is also exposed for lowest latency.
- **HDR** + SDR-brightness slider — functional; desktop/native-Wayland HDR is
  the reliable path. gamescope-HDR-on-NVIDIA can still wash out in edge cases.

## Sources

- Void Handbook — KDE: <https://docs.voidlinux.org/config/graphical-session/kde.html>
- `kde-plasma` template (6.5.x metapackage): <https://github.com/void-linux/void-packages/blob/master/srcpkgs/kde-plasma/template>
- Void Handbook — NVIDIA: <https://docs.voidlinux.org/config/graphical-session/graphics-drivers/nvidia.html>
- KDE Wiki — Plasma/Wayland/Nvidia: <https://community.kde.org/Plasma/Wayland/Nvidia>
