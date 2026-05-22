# 01 — Safe dual-boot install (Void on disk 2, Bazzite untouched)

**Goal:** Bazzite (disk 1) stays bootable and byte-for-byte untouched. Void goes
on a blank disk 2 with its **own ESP**. OS selection happens in the **motherboard
firmware boot menu**, not via anyone's GRUB.

## Why this exact strategy

- Bazzite is Fedora atomic. `bootupd`/`bootupctl` *atomically* rewrites shim+GRUB
  on "its" ESP on every image update. If Void shares that ESP, a Bazzite update
  silently re-stages GRUB and breaks the dual-boot.
- ostree rewrites BLS entries (`/boot/loader/entries/*.conf`) on shutdown and GC's
  old deployments. An external GRUB using `os-prober` captures a stale snapshot
  pointing at a deployment hash that disappears → unbootable entry.
- **Conclusion:** one ESP per physical disk; never chainload Bazzite from Void's
  GRUB; switch OSes at the firmware level.

## Pre-flight (do this on Bazzite, before touching anything)

1. Back up your current boot state for reference:
   ```sh
   efibootmgr -v > ~/efibootmgr-before.txt
   lsblk -o NAME,SIZE,MODEL,SERIAL,PARTLABEL > ~/disks-before.txt
   ```
   Copy both off-machine. Note **which physical disk + serial is Bazzite**.
2. Back up real data (this is a new-disk install, but a `dd` to the wrong device
   is forever). Bazzite itself is reproducible from its image; your `~` is not.
3. Firmware setup → **disable Secure Boot**. Void ships no signed shim, so it
   won't boot with SB on. Fedora/Bazzite boots fine with SB off — no harm done.
4. Leave Bazzite's disk as the firmware default boot device.

## Install

1. **Power off. Physically disconnect disk 1 (Bazzite)** — or disable its
   NVMe/SATA port in firmware. With disk 1 absent there is *zero* chance of
   clobbering its ESP or NVRAM. This is the single most effective safeguard.
2. Boot the **Void glibc x86_64** live ISO (NOT musl). `hrmpf` is a Void-based
   rescue ISO worth keeping on a second stick for later repairs.
3. `lsblk` — confirm only the blank disk 2 is present.
4. Run `void-installer`. Flow: keyboard → network → **source** (Network = fetch
   current packages, recommended) → hostname/locale/timezone → root + user
   (⚠️ create your user with **UID/GID 1000** to match Bazzite for any shared
   data partition later) → **bootloader** → **partition** → **filesystems**.
5. **Partition** disk 2 (GPT):

   | Partition | Size | Type | Mount |
   |---|---|---|---|
   | p1 | 1 GiB | EFI System (vfat) | `/boot/efi` (Void's **own** ESP) |
   | p2 | rest | **Btrfs** | `/` |
   | p3 *(optional)* | as needed | ext4 | shared data (see §Shared data) |

   Pick **Btrfs** for root — it's your only rollback path on Void (snapshots).
6. **Bootloader step:** install GRUB to **disk 2**. With disk 1 disconnected
   this is the only option anyway. `void-installer` runs
   `grub-install --efi-directory=/boot/efi --bootloader-id=Void` into disk 2's
   ESP and adds a "Void" NVRAM entry. Disk 1 is never referenced.
7. Finish, **power off**, **reconnect disk 1** (re-enable its port).

## First boot & switching

1. Power on, mash the firmware **one-time boot menu** key (X570/B550 boards:
   usually **F8/F11/F12**). Pick **Void** → verify it boots.
2. Reboot, pick **Bazzite** from the same menu → verify it boots unchanged.
3. Daily workflow: leave firmware default = Bazzite, use the F-key menu to pick
   Void when wanted. Lowest-risk, zero on-disk bootloader coupling.
4. *(Optional convenience)* Install **rEFInd into Bazzite's ESP only** and make
   it the default NVRAM entry for a graphical picker that auto-scans disk 2:
   ```sh
   # from Bazzite
   sudo bootctl ... # NO — use refind-install or manual copy; see rodsbooks.com/refind
   efibootmgr -c -l '\EFI\refind\refind_x64.efi' -L rEFInd
   ```
   Caveat: Bazzite's `bootupd` may reassert GRUB as default on updates; re-run
   the `efibootmgr` line if so. The plain firmware menu needs zero maintenance.

## Shared data partition (optional)

- Use **ext4** (or xfs), *not* NTFS, *not* a btrfs subvolume shared across distros.
- Same primary user **UID/GID 1000** on both OSes (you set this above), then
  `chown -R 1000:1000` the mount.
- Mount by `UUID=` in `/etc/fstab` on **both** sides.

## Clock

Both Void and Bazzite default to **UTC** — no conflict. Do **not** run
`timedatectl set-local-rtc 1`.

## Recovery

- **Void bootloader damaged:** boot `hrmpf`, then:
  ```sh
  mount -t efivarfs none /sys/firmware/efi/efivars
  xchroot /mnt /bin/bash          # /mnt = Void root; disk2 ESP at /mnt/boot/efi
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Void
  xbps-reconfigure -fa
  ```
- **Bazzite bootloader damaged:** boot Bazzite Live ISO → built-in Bootloader
  Restoring Tool; or from a running deployment: `ujust regenerate-grub` /
  `sudo bootupctl update` (`sudo bootupctl status` to inspect).

## Sources

- Void Handbook — Installation / Partitioning: <https://docs.voidlinux.org/installation/live-images/guide.html>
- ostree bootloaders (BLS, blscfg, os-prober caveat): <https://ostreedev.github.io/ostree/bootloaders/>
- Fedora — Automatic Bootloader Updates / bootc: <https://fedoraproject.org/wiki/Changes/AutomaticBootloaderUpdatesBootc>
- Bazzite dual-boot guide: <https://docs.bazzite.gg/General/Installation_Guide/dual_boot_setup_guide/>
- rEFInd install: <https://www.rodsbooks.com/refind/installing.html>
- hrmpf rescue: <https://github.com/leahneukirchen/hrmpf>
