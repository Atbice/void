#!/bin/sh
# bootstrap.sh — idempotent Void Linux provisioner.
# Run this ON THE NEW VOID BOX after a clean install (docs/01-install-dualboot.md).
# Safe to re-run. Refuses to run on anything that is not Void.
# It NEVER touches disk 1 / the bootloader / partitions.
#
# Usage:
#   ./bootstrap.sh [--flatpaks] [--steam-fixes] [--no-update] [--dry-run]
#
#   --flatpaks     also install every app in pkgs/flatpaks.txt from Flathub
#   --steam-fixes  apply the Steam-Linux-Runtime /usr/lib64 symlink fixes
#                  (run ONLY after installing Steam, ONLY if SLR misbehaves)
#   --no-update    skip the full `xbps-install -Su` system update
#   --dry-run      print what would happen, change nothing
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DO_FLATPAKS=0; DO_STEAMFIX=0; DO_UPDATE=1; DRY=0

for a in "$@"; do
  case "$a" in
    --flatpaks)    DO_FLATPAKS=1 ;;
    --steam-fixes) DO_STEAMFIX=1 ;;
    --no-update)   DO_UPDATE=0 ;;
    --dry-run)     DRY=1 ;;
    -h|--help)     grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $a (see --help)" >&2; exit 2 ;;
  esac
done

say() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
run() { if [ "$DRY" = 1 ]; then printf '  [dry-run] %s\n' "$*"; else sh -c "$*"; fi; }

# --- guard: Void only -------------------------------------------------------
if [ ! -r /etc/os-release ] || ! grep -q '^ID=void' /etc/os-release; then
  echo "REFUSING: this is not Void Linux. Run bootstrap.sh on the new Void box only." >&2
  exit 1
fi
command -v xbps-install >/dev/null || { echo "xbps not found?!" >&2; exit 1; }

SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

# strip comments/blanks, join to a space-separated list
pkglist() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$@" 2>/dev/null \
            | awk 'NF' | tr '\n' ' '; }

# --- 1. repositories --------------------------------------------------------
say "Enabling nonfree + multilib repositories"
run "$SUDO xbps-install -Sy void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree"
run "$SUDO xbps-install -S"

# --- 2. full system update (twice: xbps self-update gotcha) -----------------
if [ "$DO_UPDATE" = 1 ]; then
  say "Full system update (pass 1/2)"
  run "$SUDO xbps-install -Suy"
  say "Full system update (pass 2/2 — applies the rest if xbps self-updated)"
  run "$SUDO xbps-install -Suy"
  warn "If a new kernel was installed, reboot before continuing (NVIDIA DKMS)."
fi

# --- 3. packages ------------------------------------------------------------
PKGS=$(pkglist "$REPO_DIR"/pkgs/10-core.txt "$REPO_DIR"/pkgs/20-desktop.txt \
                "$REPO_DIR"/pkgs/30-nvidia.txt "$REPO_DIR"/pkgs/40-gaming.txt \
                "$REPO_DIR"/pkgs/50-dev.txt)
say "Installing packages"
echo "  $PKGS"
run "$SUDO xbps-install -y $PKGS"

# --- 4. NVIDIA modprobe/dracut config + initramfs ---------------------------
say "Installing NVIDIA modprobe + dracut config"
run "$SUDO install -Dm644 '$REPO_DIR/etc/modprobe.d/nvidia.conf'  /etc/modprobe.d/nvidia.conf"
run "$SUDO install -Dm644 '$REPO_DIR/etc/dracut.conf.d/nvidia.conf' /etc/dracut.conf.d/nvidia.conf"
say "Regenerating initramfs (xbps-reconfigure -fa)"
run "$SUDO xbps-reconfigure -fa"

# --- 5. runit services (idempotent symlinks) --------------------------------
say "Enabling runit services"
for s in $(pkglist "$REPO_DIR/services.txt"); do
  if [ -e "/var/service/$s" ]; then
    echo "  $s already enabled"
  elif [ -d "/etc/sv/$s" ]; then
    run "$SUDO ln -s /etc/sv/$s /var/service/"
    echo "  enabled $s"
  else
    warn "service '$s' has no /etc/sv/$s — skipped (install its package first?)"
  fi
done

# --- 6. flatpak / flathub ---------------------------------------------------
if command -v flatpak >/dev/null 2>&1 || [ "$DRY" = 1 ]; then
  say "Configuring Flathub"
  run "$SUDO flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"
  if [ "$DO_FLATPAKS" = 1 ]; then
    FP=$(pkglist "$REPO_DIR/pkgs/flatpaks.txt")
    say "Installing Flatpak apps from Flathub"
    run "flatpak install -y --noninteractive flathub $FP"
  else
    echo "  (re-run with --flatpaks to install pkgs/flatpaks.txt)"
  fi
fi

# --- 7. optional Steam Linux Runtime fixes ----------------------------------
if [ "$DO_STEAMFIX" = 1 ]; then
  say "Applying Steam Linux Runtime /usr/lib64 fixes (idempotent)"
  if [ -d /usr/lib/gconv ] && [ ! -e /usr/lib64/gconv ]; then
    run "$SUDO ln -s ../lib/gconv /usr/lib64/gconv"
    echo "  linked /usr/lib64/gconv -> /usr/lib/gconv"
  else
    echo "  gconv: nothing to do"
  fi
  if [ -e /usr/lib/libudev.so.1 ] && [ ! -e /usr/lib/libudev.so.0 ]; then
    run "$SUDO ln -s libudev.so.1 /usr/lib/libudev.so.0"
    echo "  linked libudev.so.0 -> libudev.so.1"
  else
    echo "  libudev: nothing to do"
  fi
  warn "If a game still segfaults under SLR, toggle its compatibility tool off per-game."
fi

# --- done -------------------------------------------------------------------
say "Done."
cat <<'EOF'

Next steps:
  1. Set your shell:     command -v fish | sudo tee -a /etc/shells && chsh -s "$(command -v fish)"
  2. Dotfiles:           chezmoi init --apply <your-dotfiles-repo>
  3. Rust toolchain:     rustup default nightly   (you run nightly on Bazzite)
  4. Podman subids:      sudo usermod --add-subuids 100000-165535 \
                              --add-subgids 100000-165535 "$USER" && podman system migrate
  5. Reboot, log in to "Plasma (Wayland)" at SDDM.
  6. Verify:  nvidia-smi ; cat /sys/module/nvidia_drm/parameters/modeset  (-> Y)

If Steam misbehaves later:  ./bootstrap.sh --steam-fixes
EOF
