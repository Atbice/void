#!/bin/sh
# bootstrap.sh — idempotent Void provisioner for a LEAN gaming box.
# Run ON THE NEW VOID BOX after a clean install (docs/01-install-dualboot.md).
# Safe to re-run. Refuses to run on non-Void. Never touches disk 1 / bootloader.
#
# Scope: NVIDIA 3090 + lean KDE Plasma 6 Wayland + native Steam + Lutris.
# No Flatpak. Steam-on-Void fixes are applied BY DEFAULT (mandatory here).
#
# Usage:
#   ./bootstrap.sh [--faugus] [--no-update] [--dry-run]
#     --faugus     ALSO run ./faugus.sh (fragile source build — read docs/00)
#     --no-update  skip the full `xbps-install -Su`
#     --dry-run    print actions, change nothing
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DO_FAUGUS=0; DO_UPDATE=1; DRY=0
for a in "$@"; do
  case "$a" in
    --faugus)    DO_FAUGUS=1 ;;
    --no-update) DO_UPDATE=0 ;;
    --dry-run)   DRY=1 ;;
    -h|--help)   grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
run "$SUDO install -Dm644 '$REPO_DIR/etc/modprobe.d/nvidia.conf'   /etc/modprobe.d/nvidia.conf"
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

# --- 6. Steam-on-Void fixes (MANDATORY — no Flatpak escape) -----------------
say "Applying mandatory Steam-on-Void fixes"
# 6a. gconv: SLR/EAC look in /usr/lib64/gconv
if [ ! -e /usr/lib64/gconv ] && [ -d /usr/lib/gconv ]; then
  run "$SUDO ln -s ../lib/gconv /usr/lib64/gconv"; echo "  linked /usr/lib64/gconv"
else echo "  gconv: nothing to do"; fi
# 6b. system-wide GCONV_PATH
run "printf '%s\\n' 'export GCONV_PATH=/usr/lib/gconv' | $SUDO tee /etc/profile.d/steam-void.sh >/dev/null"
run "$SUDO chmod 644 /etc/profile.d/steam-void.sh"
# 6c. raise file-descriptor limit (Proton 'eventfd: Too many open files')
run "printf '%s\\n%s\\n' '* soft nofile 1048576' '* hard nofile 1048576' | $SUDO tee /etc/security/limits.d/steam.conf >/dev/null"
# 6d. groups for controllers / GPU
run "$SUDO usermod -aG video,input '$TARGET_USER'"
warn "Log out/in (or reboot) for group + nofile + GCONV_PATH changes to apply."

# --- 7. optional Faugus -----------------------------------------------------
if [ "$DO_FAUGUS" = 1 ]; then
  say "Running optional faugus.sh (fragile — see docs/00-faugus-optional.md)"
  if [ "$DRY" = 1 ]; then echo "  [dry-run] $REPO_DIR/faugus.sh"
  else sh "$REPO_DIR/faugus.sh"; fi
fi

# --- done -------------------------------------------------------------------
say "Done."
cat <<'EOF'

Next steps:
  1. sudo reboot
  2. At SDDM, pick the gear menu -> "Plasma (Wayland)".
  3. Verify:
       nvidia-smi
       cat /sys/module/nvidia_drm/parameters/modeset      # -> Y
       echo $XDG_SESSION_TYPE                              # -> wayland
       vkcube                                              # 3090 renders
  4. Steam -> log in -> Settings -> Compatibility ->
       enable "Steam Play for all other titles" -> install a game.
  5. Non-Steam / Epic / GOG: use Lutris (built-in GE-Proton downloader).
  6. VRR/HDR: System Settings -> Display & Monitor.

  (Optional, not recommended) Faugus: ./faugus.sh  — read docs/00 first.
EOF
