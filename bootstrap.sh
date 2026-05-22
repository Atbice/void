#!/bin/sh
# bootstrap.sh — idempotent Void provisioner for a LEAN gaming box.
# Run ON THE NEW VOID BOX after a clean install (docs/01-install-dualboot.md).
# Safe to re-run. Refuses to run on non-Void. Never touches disk 1 / bootloader.
#
# Scope: NVIDIA 3090 + lean KDE Plasma 6 Wayland + native Steam + Lutris
#        + a thin Flatpak layer (Faugus etc.). Steam-on-Void fixes applied
#        BY DEFAULT (mandatory for native Steam).
#
# Usage:
#   ./bootstrap.sh [--no-flatpaks] [--faugus-src] [--no-update] [--dry-run]
#     --no-flatpaks  set up Flatpak/Flathub but DON'T install pkgs/flatpaks.txt
#     --faugus-src   ALSO build Faugus from source (./faugus.sh) — only if you
#                    refuse the Flatpak; fragile, read docs/00
#     --no-update    skip the full `xbps-install -Su`
#     --dry-run      print actions, change nothing
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DO_FLATPAKS=1; DO_FAUGUS_SRC=0; DO_UPDATE=1; DRY=0
for a in "$@"; do
  case "$a" in
    --no-flatpaks) DO_FLATPAKS=0 ;;
    --faugus-src)  DO_FAUGUS_SRC=1 ;;
    --no-update)   DO_UPDATE=0 ;;
    --dry-run)     DRY=1 ;;
    -h|--help)     grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $a (see --help)" >&2; exit 2 ;;
  esac
done

say()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
run()  { if [ "$DRY" = 1 ]; then printf '  [dry-run] %s\n' "$*"; else sh -c "$*"; fi; }

# --- guard: Void only -------------------------------------------------------
if [ ! -r /etc/os-release ] || ! grep -q '^ID=void' /etc/os-release; then
  echo "REFUSING: not Void Linux. Run this on the new Void box only." >&2
  exit 1
fi
command -v xbps-install >/dev/null || { echo "xbps not found?!" >&2; exit 1; }

SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
TARGET_USER="${SUDO_USER:-$(id -un)}"

pkglist() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$@" 2>/dev/null \
            | awk 'NF' | tr '\n' ' '; }

# --- 1. repositories --------------------------------------------------------
say "Enabling nonfree + multilib repositories"
run "$SUDO xbps-install -Sy void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree"
run "$SUDO xbps-install -S"

# --- 2. full update (twice: xbps self-update gotcha) ------------------------
if [ "$DO_UPDATE" = 1 ]; then
  say "Full system update (pass 1/2)"; run "$SUDO xbps-install -Suy"
  say "Full system update (pass 2/2)"; run "$SUDO xbps-install -Suy"
  warn "If a new kernel was installed, reboot before continuing (NVIDIA DKMS)."
fi

# --- 3. packages ------------------------------------------------------------
PKGS=$(pkglist "$REPO_DIR"/pkgs/10-core.txt "$REPO_DIR"/pkgs/20-desktop.txt \
                "$REPO_DIR"/pkgs/30-nvidia.txt "$REPO_DIR"/pkgs/40-gaming.txt)
say "Installing packages"; echo "  $PKGS"
run "$SUDO xbps-install -y $PKGS"

# --- 4. NVIDIA config + initramfs ------------------------------------------
say "Installing NVIDIA modprobe + dracut config"
run "$SUDO install -Dm644 '$REPO_DIR/etc/modprobe.d/nvidia.conf'    /etc/modprobe.d/nvidia.conf"
run "$SUDO install -Dm644 '$REPO_DIR/etc/dracut.conf.d/nvidia.conf' /etc/dracut.conf.d/nvidia.conf"
say "Installing SDDM Wayland-greeter config (delete it if the greeter misbehaves)"
run "$SUDO install -Dm644 '$REPO_DIR/etc/sddm.conf.d/10-wayland.conf' /etc/sddm.conf.d/10-wayland.conf"
say "Regenerating initramfs (xbps-reconfigure -fa)"
run "$SUDO xbps-reconfigure -fa"

# --- 5. runit services ------------------------------------------------------
say "Enabling runit services"
for s in $(pkglist "$REPO_DIR/services.txt"); do
  if [ -e "/var/service/$s" ]; then echo "  $s already enabled"
  elif [ -d "/etc/sv/$s" ]; then run "$SUDO ln -s /etc/sv/$s /var/service/"; echo "  enabled $s"
  else warn "no /etc/sv/$s — skipped (e.g. elogind is dbus-activated on current Void)"; fi
done

# --- 6. Steam-on-Void fixes (MANDATORY for native Steam) --------------------
say "Applying mandatory Steam-on-Void fixes"
if [ ! -e /usr/lib64/gconv ] && [ -d /usr/lib/gconv ]; then
  run "$SUDO ln -s ../lib/gconv /usr/lib64/gconv"; echo "  linked /usr/lib64/gconv"
else echo "  gconv: nothing to do"; fi
run "printf '%s\\n' 'export GCONV_PATH=/usr/lib/gconv' | $SUDO tee /etc/profile.d/steam-void.sh >/dev/null"
run "$SUDO chmod 644 /etc/profile.d/steam-void.sh"
run "printf '%s\\n%s\\n' '* soft nofile 1048576' '* hard nofile 1048576' | $SUDO tee /etc/security/limits.d/steam.conf >/dev/null"
run "$SUDO usermod -aG video,input '$TARGET_USER'"
warn "Log out/in (or reboot) for group + nofile + GCONV_PATH changes to apply."

# --- 7. Flatpak + Flathub ---------------------------------------------------
say "Setting up Flatpak / Flathub"
run "$SUDO flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"
if [ "$DO_FLATPAKS" = 1 ]; then
  FP=$(pkglist "$REPO_DIR/pkgs/flatpaks.txt")
  if [ -n "$FP" ]; then
    say "Installing Flatpak apps (incl. Faugus Launcher)"
    run "$SUDO flatpak install -y --noninteractive flathub $FP"
  fi
else
  echo "  --no-flatpaks: skipped pkgs/flatpaks.txt (Flathub still configured)"
fi
warn "Log out/in once so Flatpak apps appear in the menu (XDG_DATA_DIRS)."

# --- 8. optional: Faugus from SOURCE (only if refusing the Flatpak) ---------
if [ "$DO_FAUGUS_SRC" = 1 ]; then
  say "Running optional faugus.sh — SOURCE build (fragile; see docs/00)"
  warn "The Flatpak (step 7) is the clean way to get Faugus. Source build is a fallback."
  if [ "$DRY" = 1 ]; then echo "  [dry-run] $REPO_DIR/faugus.sh"
  else sh "$REPO_DIR/faugus.sh"; fi
fi

# --- done -------------------------------------------------------------------
say "Done."
cat <<'EOF'

Next steps:
  1. sudo reboot
  2. At SDDM, gear menu -> "Plasma (Wayland)".
  3. Verify:
       nvidia-smi
       cat /sys/module/nvidia_drm/parameters/modeset      # -> Y
       echo $XDG_SESSION_TYPE                              # -> wayland
       vkcube                                              # 3090 renders
  4. Steam -> log in -> Settings -> Compatibility ->
       enable "Steam Play for all other titles" -> install a game.
  5. Faugus Launcher: installed as a Flatpak — launch it from the menu.
     Non-Steam / Epic / GOG: Faugus or native Lutris (both have GE-Proton).
  6. VRR/HDR: System Settings -> Display & Monitor.
EOF
