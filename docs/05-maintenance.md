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

## SSD TRIM (ext4)

No `fstrim.timer` on Void (no systemd), so `bootstrap.sh` installs a weekly job —
`/etc/cron.weekly/fstrim` (`fstrim --all`), fired by `cronie`+`anacron` (anacron
also catches the job up if the box was off in Bazzite at the scheduled time). Do
**not** use the `discard` mount option — periodic TRIM performs better. Verify:
`lsblk --discard` (non-zero DISC-MAX) and `sudo fstrim -v /`.

## Save points & rollback (no snapshots — by design)

ext4 root means no boot-into-snapshot. That's intentional; your safety net is layered:

1. **This git repo = the rebuild recipe.** Fresh disk → `docs/01` → `git clone`
   → `./bootstrap.sh` → `chezmoi init --apply <dotfiles-repo>` and you're back. Commit the package
   manifest whenever the box is stable (see below).
2. **Cloud = your data backup** — whatever in `/home` you care about.
3. **Previous kernel in the GRUB menu** — first defense for a bad kernel/DKMS bump.
4. **`hrmpf` USB → `xchroot`** — repair packages / initramfs / GRUB in place.
5. **Reinstall + `./bootstrap.sh` + `chezmoi init --apply <dotfiles-repo>`** — the repo *is* the recovery
   image; a hosed userland is a ~20-min rebuild, not a disaster.
6. **Bazzite on disk 1 is independent** — worst case, boot it and fix Void over a
   chroot from there.

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
- Reinstall + `./bootstrap.sh` + `chezmoi init --apply <dotfiles-repo>` — the repo is your recovery image
  (no snapshots; a hosed userland/FS is a quick rebuild, not a loss).
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
`./bootstrap.sh`, `chezmoi init --apply <dotfiles-repo>`, back in business.

## Sources

- Void news (breaking changes): <https://voidlinux.org/news/>
- glibc/libxcrypt Jan 2024 incident: <https://voidlinux.org/news/2024/01/glibc-xcrypt.html>
- XBPS handbook: <https://docs.voidlinux.org/xbps/index.html>
- hrmpf: <https://github.com/leahneukirchen/hrmpf>
- Void Handbook — SSDs / TRIM: <https://docs.voidlinux.org/config/ssd.html>
- zramen: <https://github.com/atweiden/zramen>
