# 05 — Rolling-release survival (the part Bazzite did for you)

You no longer have atomic image updates or one-command rollback. This is the
ongoing tax. Make it routine.

## Update ritual

```sh
sudo xbps-install -Su      # then run AGAIN — xbps self-updates in its own
sudo xbps-install -Su      # transaction; the 2nd pass applies the rest
```
- **Read <https://voidlinux.org/news/> before big updates.** It's the *only*
  breaking-change channel. The textbook case: the Jan 2024 glibc 2.38 /
  libxcrypt transition could break `sudo`/login on a partial upgrade — recovery
  was chroot + `libxcrypt-compat`.
- Skim the transaction summary before confirming. If `xbps` itself is in the
  list, expect to re-run.
- Hold a package: `sudo xbps-pkgdb -m hold <pkg>`.

## Snapshots = your rollback (Btrfs root, chosen at install)

This is why `docs/01` picks Btrfs. Snapshot before any non-trivial update:

```sh
sudo btrfs subvolume snapshot -r / /.snapshots/$(date +%F-%H%M)
```
Consider `snapper` or `btrbk` (both packaged) for automation + GRUB
boot-into-snapshot. A failed update → boot a snapshot, investigate, retry.

## NVIDIA + rolling kernel

- Driver is **DKMS-rebuilt** on kernel updates via `xbps-triggers`. If a DKMS
  build fails you must be able to boot the old kernel.
- Void keeps **N kernels** (`xbps` config). Don't prune to 1. After a kernel or
  driver bump: reboot, then `nvidia-smi` before relying on the machine.
- Force a rebuild if needed: `sudo xbps-reconfigure -fa` (reconfigures all;
  avoids needing the exact `linuxX.Y` series string).

## Recovery toolkit (keep on a USB stick)

- **`hrmpf`** — Void-based rescue ISO. `xchroot /mnt /bin/bash` to repair
  packages, regen initramfs, reinstall GRUB to disk 2's ESP. See `docs/01`.
- Old kernel entry in GRUB — first line of defense for DKMS failures.
- Btrfs snapshot — first line of defense for everything else.
- Bazzite is independent on disk 1 — worst case you boot Bazzite and fix Void
  over SSH/chroot from there.

## What to keep in git (this repo) so the box is reproducible

- `pkgs/*.txt` — regenerate the truth list anytime:
  `xbps-query -m | awk '{print $1}' | sed 's/-[0-9].*$//' > pkgs/installed.txt`
- `services.txt` — runit services you enabled.
- `etc/` — your `/etc/modprobe.d`, `/etc/dracut.conf.d`, custom `/etc/sv/*/run`.
- Dotfiles live in a **separate chezmoi repo** (`chezmoi init --apply <repo>`),
  not here — keep provisioning and dotfiles decoupled.

Treat this repo as the source of truth: a dead disk → new disk, `docs/01`,
`./bootstrap.sh`, `chezmoi apply`, back in business.

## Sources

- Void news (breaking changes): <https://voidlinux.org/news/>
- glibc/libxcrypt Jan 2024 incident: <https://voidlinux.org/news/2024/01/glibc-xcrypt.html>
- XBPS handbook: <https://docs.voidlinux.org/xbps/index.html>
- hrmpf: <https://github.com/leahneukirchen/hrmpf>
