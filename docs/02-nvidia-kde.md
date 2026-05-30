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

> Illustrative only. The authoritative, complete set is `pkgs/20-desktop.txt`
> (which also has `flatpak`, `xdg-desktop-portal-gtk`, and the fonts) plus
> `pkgs/30-nvidia.txt` (`nvidia`, `nvidia-libs-32bit`, `Vulkan-Tools`). Run
> `bootstrap.sh` rather than copy-pasting this line.

- `xorg-minimal` is still required: the default SDDM **greeter** runs on X
  (the Plasma *session* is Wayland regardless). It's small.
- PipeWire: `bootstrap.sh` wires it up — **Void does not autostart it**, so
  without this you have *no audio* (desktop and games). It links
  `pipewire.desktop` into `/etc/xdg/autostart`, the wireplumber + pipewire-pulse
  example drop-ins into `/etc/pipewire/pipewire.conf.d/`, and the ALSA bridges
  into `/etc/alsa/conf.d/`. Verify after login: `wpctl status` must list a sink.

### SDDM greeter on Wayland

`bootstrap.sh` installs `etc/sddm.conf.d/10-wayland.conf` (greeter via
`kwin_wayland --drm`). Works on NVIDIA with the current driver. `--locale1` is
intentionally omitted (Void has no `systemd-localed` provider — it's a no-op);
the greeter keymap is set via `GreeterEnvironment=XKB_DEFAULT_LAYOUT=se`
(Swedish), since the greeter process doesn't read `/etc/environment`.

If the greeter misbehaves (black screen / no greeter), recover from a TTY — the
Plasma **session** is Wayland regardless of the greeter's display server:

```sh
# Ctrl+Alt+F2 to a text console, log in, then:
sudo rm /etc/sddm.conf.d/10-wayland.conf
sudo sv restart sddm
```

### Keyboard layout (Swedish)

`bootstrap.sh` sets Swedish in all three independent places, so you get `se`
from the boot console through to the desktop:

- **Console TTYs** — `KEYMAP=sv-latin1` in `/etc/rc.conf` (Void applies it at boot).
- **Wayland/Plasma session** — `XKB_DEFAULT_LAYOUT=se` in `/etc/environment`
  (kwin reads it via pam_env). On first login Plasma inherits this; once you set
  layouts in *System Settings → Keyboard*, that per-user `kxkbrc` takes over.
- **SDDM greeter** — `XKB_DEFAULT_LAYOUT=se` in the greeter's `GreeterEnvironment`
  (`etc/sddm.conf.d/10-wayland.conf`).

To change it, swap `se` / `sv-latin1` in those three spots (or just pick a layout
in System Settings for the running session).

## runit services

```sh
sudo ln -s /etc/sv/dbus           /var/service/
sudo ln -s /etc/sv/NetworkManager /var/service/
sudo ln -s /etc/sv/sddm           /var/service/   # enable last to test the box first
```

runit supervises services in **parallel** — symlink order does not set a boot
order; each run script self-gates on its deps (Void's `NetworkManager`/`sddm` run
scripts call `sv check dbus`). Enabling `sddm` last is just so you can verify the
system before the greeter takes the VT.

**Do NOT enable `elogind` as a runit service.** It ships `/etc/sv/elogind`, but on
current Void it is **dbus-activated**: the `dbus` package is built
`--enable-elogind`, and the elogind package installs a dbus activation file
(`/usr/share/dbus-1/system-services/org.freedesktop.login1.service`,
`Exec=…/elogind --daemon`). The first `org.freedesktop.login1` call — SDDM's
`pam_elogind` or Plasma — auto-spawns elogind. If you *also* symlink
`/etc/sv/elogind`, runit starts a **second** instance; the loser exits
`elogind is already running as PID N` and runsv respawns it instantly — a tight
loop that saturates the box (reproduced on a real VM: `sshd` died, Plasma never
displayed). `bootstrap.sh` therefore omits elogind from `services.txt` and
actively refuses to enable it. KDE-initiated **suspend** and the NVIDIA sleep
hook still fire — they go KDE → `org.freedesktop.login1` `Suspend()` → the
dbus-activated elogind → kernel sleep + `/usr/lib/elogind/system-sleep` hooks;
no standalone service is needed. (The handbook's "enable its service if you have
issues" remedy would *also* require neutering the dbus activation file so the two
don't race — unnecessary complexity for this box.) The official KDE-on-Void page
enables only `dbus`, `NetworkManager`, `sddm` — exactly our set.

Don't enable `dhcpcd` alongside NetworkManager.

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
