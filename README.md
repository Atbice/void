# Void Linux provisioning — gaming + dev daily driver (from Bazzite)

A reproducible "configs before install" repo for a clean Void Linux install on a
**separate disk**, alongside an existing **Bazzite Kinoite** install, on a
**Ryzen 9 5900X + RTX 3090** box.

> **Short answer to "can I set it up with configs before?"**
> Yes — but not the NixOS way. Void has no declarative installer. The realistic,
> community-standard approach (and what this repo is) is: do a normal Void install,
> then run a versioned **package list + idempotent provisioning script + dotfiles**.
> You prepare all of that *now*, commit it to git, and a fresh box is ~one script away.

## The honest picture (Bazzite → Void)

You are trading an image-based, atomic, auto-tuned distro for a minimal,
mutable, rolling one with **runit instead of systemd** and **xbps instead of
rpm-ostree/flatpak-first**. Decisions already made for you here, with reasons:

| Decision | Choice | Why |
|---|---|---|
| libc flavor | **glibc** (not musl) | NVIDIA proprietary driver and Steam are glibc-only. Non-negotiable for this box. |
| Display server | **Wayland** (X11 kept as fallback) | Plasma 6.1+ + NVIDIA 595 + explicit-sync is the mainstream path in 2026; matches your Bazzite experience. |
| Driver | `nvidia` package (DKMS) | RTX 3090 = Ampere → current branch. Ships NVIDIA's open GSP module; rebuilt by DKMS + xbps triggers on kernel updates. |
| Dual-boot | **Separate ESP per disk + firmware boot menu** | Bazzite's `bootupd` atomically owns disk 1's ESP. Sharing it or chainloading ostree via os-prober *will* break. Disconnect disk 1 during Void install. |
| Dotfiles | **chezmoi** | Templating + per-host + one-line `chezmoi init --apply`. Beats stow/bare-git for this. |
| Root filesystem | **Btrfs** (choose at install) | Your only rollback safety net — Void has no atomic rollback. Snapshot before big updates. |

### What you genuinely lose vs Bazzite (no sugar-coating)

- **No turnkey HDR + VRR gaming session.** Bazzite's headline feature. On Void/NVIDIA this is best-effort and fragile; there is no `gamescope-session` kiosk.
- **No atomic rollback.** Mitigated by Btrfs snapshots + kept-back kernels + the `hrmpf` rescue ISO — but it's manual.
- **You own integration.** Driver/kernel/DKMS coordination, udev, repo enabling, breaking-change transitions (the glibc/libxcrypt class of bug) — read <https://voidlinux.org/news/> before big updates.
- **Steam Linux Runtime vs Void's `/usr/lib64` layout** causes recurring breakage (gconv/libudev/EAC). One-time symlink fixes are scripted here (`./bootstrap.sh --steam-fixes`).

Realistic outcome: **~90% Bazzite parity after one evening**, minus the HDR/VRR
session, plus ongoing self-maintenance.

## Repo layout

```
README.md              ← you are here (the plan + decisions)
docs/
  01-install-dualboot.md   Safe separate-disk install, step by step
  02-nvidia-kde.md         RTX 3090 + Plasma 6 Wayland
  03-gaming.md             Gaming stack + Bazzite→Void parity table
  04-dev.md                Dev workstation (containers, langs, fish)
  05-maintenance.md        Rolling-release survival, snapshots, recovery
pkgs/
  10-core.txt  20-desktop.txt  30-nvidia.txt  40-gaming.txt  50-dev.txt
  flatpaks.txt             Your Bazzite flatpaks, to re-add
etc/
  modprobe.d/nvidia.conf   dracut.conf.d/nvidia.conf
services.txt               runit services to enable
bootstrap.sh               Idempotent provisioner (run ON the new Void box)
```

## How to use it

1. **Now (on Bazzite):** read `docs/`, tweak the `pkgs/*.txt` lists, push this repo to git, and set up a [chezmoi](https://chezmoi.io) dotfiles repo from your current `~/.config` (fish, etc.).
2. **Install:** follow `docs/01-install-dualboot.md` — disk 1 physically disconnected, Btrfs root, GRUB to disk 2 only.
3. **Provision (on Void, first boot):**
   ```sh
   git clone <this repo> ~/void && cd ~/void
   ./bootstrap.sh              # repos → update → packages → services → nvidia → flatpak
   ./bootstrap.sh --steam-fixes   # only after installing Steam, if SLR misbehaves
   chezmoi init --apply <your-dotfiles-repo>
   sudo reboot
   ```
4. **Verify:** `nvidia-smi`, `cat /sys/module/nvidia_drm/parameters/modeset` → `Y`, log into "Plasma (Wayland)".

`bootstrap.sh` is **idempotent** (safe to re-run), refuses to run on anything
that isn't Void, and never touches disk 1 / the bootloader.

> ⚠️ One thing to verify yourself before install: the exact KDE metapackage name
> in `pkgs/20-desktop.txt`. Void has historically used `kde5`/`kde5-baseapps`
> (which install **Plasma 6**); some docs list `kde-plasma`. Check the handbook
> KDE page at install time: <https://docs.voidlinux.org/config/graphical-session/kde.html>
