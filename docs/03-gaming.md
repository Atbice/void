# 03 — Gaming stack on Void (Bazzite parity)

Void has near-complete native package coverage; you assemble and wire it
yourself. Realistic outcome: ~90% Bazzite parity after setup, minus the turnkey
HDR/VRR session.

## Packages (`pkgs/40-gaming.txt`, installed by bootstrap.sh)

```
steam lutris wine wine-32bit winetricks dxvk vkd3d
gamescope MangoHud MangoHud-32bit vkBasalt vkBasalt-32bit gamemode
libgcc-32bit libstdc++-32bit libdrm-32bit libglvnd-32bit libva-32bit
```

- **Steam:** native `steam` package + the 32-bit deps above (per Void's
  `steam/files/README.voidlinux`). It ships its own bundled runtime — no separate
  `steam-runtime` package. Needs `dbus` enabled and your user in `video`/`input`.
- **Proton:** enable Steam Play (Settings → Compatibility → all titles). Native
  Proton arrives via Steam; Proton bundles its own DXVK/VKD3D.
- **Proton-GE:** **not packaged**. Use Flatpak ProtonUp-Qt (you already have
  `net.davidotek.pupgui2` on Bazzite — it's in `flatpaks.txt`) or drop tarballs
  into `~/.steam/root/compatibilitytools.d/`.
- **GameMode:** Void patches it for **elogind**, so it works under runit without
  systemd — the one place Void quietly does the right thing.
- **gamescope:** no `gamescope-session` (no SteamOS kiosk). Run per-game, e.g.
  `gamescope -W 3840 -H 2160 -r 144 --adaptive-sync --hdr-enabled --mangoapp -- %command%`.
  With gamescope use `--mangoapp`, not the MangoHud layer directly.

## The Void-specific gotcha: Steam Linux Runtime vs `/usr/lib64`

EAC and `iconv()`-using games fail under SLR/pressure-vessel because Void's lib
layout differs. `bootstrap.sh --steam-fixes` applies the documented, idempotent
fixes (run only **after** installing Steam, only if you hit it):

- `/usr/lib64/gconv` → `/usr/lib/gconv` symlink (steam-runtime #680)
- `libudev.so.0` → `libudev.so.1` symlink (steam-runtime #533)
- Per-game: toggle the compatibility tool off if a title segfaults with SLR forced.

For stubborn anticheat titles, Flatpak Steam sidesteps the layout entirely.

## Controllers

- Xbox/PS5 (DualSense) **wired**: in-kernel `xpad`/`hid-playstation` — nothing to do.
- Xbox **Bluetooth**: `xpadneo` (DKMS, rebuilds on kernel updates) — add to
  `pkgs/40-gaming.txt` if you use it.
- The `steam` package installs Steam Input udev rules; if a pad enumerates but
  games see no input, reinstall `steam` (missing-rules symptom).

## Bazzite → Void parity table

| Bazzite bundles | On Void |
|---|---|
| Tuned NVIDIA + 32-bit | `nvidia nvidia-libs-32bit` + multilib repos |
| Steam preconfigured | `steam` + 32-bit deps; apply `--steam-fixes` if needed |
| Proton-GE managed | Flatpak ProtonUp-Qt (`net.davidotek.pupgui2`) |
| Lutris | `lutris` (native) |
| Heroic | Flatpak `com.heroicgameslauncher.hgl` (not in xbps) |
| Bottles | Flatpak `com.usebottles.bottles` (you already use it) |
| MangoHud +32bit | `MangoHud MangoHud-32bit` (orphaned, slightly behind upstream) |
| gamescope-session | none — wrap Steam manually with `gamescope` |
| GameMode (systemd) | `gamemode` (Void-patched for elogind ✓) |
| vkBasalt | `vkBasalt vkBasalt-32bit` |
| HDR/VRR tuned | **best-effort only**, fragile on NVIDIA, no session glue |

## Where Void is materially worse — accept these

1. SLR vs lib64 layout — recurring; mitigated by `--steam-fixes` / Flatpak Steam.
2. No SteamOS game-mode / couch kiosk.
3. **HDR + VRR on NVIDIA** — Bazzite's headline feature; rough on Void, no glue.
4. Orphaned/missing packages (MangoHud lag; Proton-GE/Heroic/ProtonUp-Qt only via Flatpak).
5. You own kernel/driver/udev/repo maintenance — nothing auto-tunes.

## Sources

- Void `steam/files/README.voidlinux`: <https://github.com/void-linux/void-packages/blob/master/srcpkgs/steam/files/README.voidlinux>
- steam-runtime #680 (gconv): <https://github.com/ValveSoftware/steam-runtime/issues/680>
- steam-runtime #533 (libudev): <https://github.com/ValveSoftware/steam-runtime/issues/533>
- Gamescope ArchWiki (HDR/VRR/mangoapp): <https://wiki.archlinux.org/title/Gamescope>
- "How I setup gaming on Void": <https://pixelfogwiki.netlify.app/docs/linux/void-linux/gaming/gaming/>
