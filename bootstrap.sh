#!/bin/sh
# bootstrap.sh — idempotent Artix Linux (runit) provisioner for the gaming box.
# Run ON THE NEW ARTIX BOX after a clean install (docs/01-install-artix.md).
# Safe to re-run. Refuses to run on non-Artix. Never touches disk 1 / bootloader.
#
# Scope: RTX 3090 + niri (Wayland) + Noctalia (Quickshell) + greetd/tuigreet
#        + native Steam + Lutris + Faugus (AUR). Multilib is enabled by this
#        script (mandatory for 32-bit nvidia libs and native Steam).
#
# Usage:
#   ./bootstrap.sh [--no-aur] [--no-update] [--dry-run]
#     --no-aur     skip paru bootstrap + AUR installs (pacman.txt only)
#     --no-update  skip the full `pacman -Syu`
#     --dry-run    print actions, change nothing
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DO_AUR=1; DO_UPDATE=1; DRY=0
for a in "$@"; do
  case "$a" in
    --no-aur)    DO_AUR=0 ;;
    --no-update) DO_UPDATE=0 ;;
    --dry-run)   DRY=1 ;;
    -h|--help)   grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $a (see --help)" >&2; exit 2 ;;
  esac
done

say()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
run()  { if [ "$DRY" = 1 ]; then printf '  [dry-run] %s\n' "$*"; else sh -c "$*"; fi; }

# --- guard: Artix only ------------------------------------------------------
if [ ! -r /etc/os-release ] || ! grep -q '^ID=artix' /etc/os-release; then
  echo "REFUSING: not Artix Linux. Run this on the new Artix box only." >&2
  exit 1
fi
command -v pacman >/dev/null || { echo "pacman not found?!" >&2; exit 1; }

SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

pkglist() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$@" 2>/dev/null \
            | awk 'NF' | tr '\n' ' '; }

# --- 1. enable multilib + sync ----------------------------------------------
say "Enabling [multilib] in /etc/pacman.conf (idempotent)"
if grep -q '^\s*#\s*\[multilib\]' /etc/pacman.conf; then
  # Uncomment the [multilib] section header AND the Include line that follows.
  run "$SUDO sed -i '/^\s*#\s*\[multilib\]/,/^\s*#\s*Include/ s/^\s*#\s*//' /etc/pacman.conf"
  echo "  multilib uncommented"
elif grep -q '^\[multilib\]' /etc/pacman.conf; then
  echo "  multilib already enabled"
else
  warn "Could not find a [multilib] block to uncomment — add it manually."
fi
run "$SUDO pacman -Syy"

# --- 2. full update ---------------------------------------------------------
if [ "$DO_UPDATE" = 1 ]; then
  say "Full system update"; run "$SUDO pacman -Syu --noconfirm"
  warn "If a new kernel was installed, reboot before continuing (NVIDIA DKMS)."
fi

# --- 3. pacman packages -----------------------------------------------------
PKGS=$(pkglist "$REPO_DIR/pkgs/pacman.txt")
say "Installing pacman packages"
echo "  $PKGS"
run "$SUDO pacman -S --needed --noconfirm $PKGS"

# --- 4. NVIDIA + mkinitcpio configs + initramfs -----------------------------
say "Installing NVIDIA modprobe + mkinitcpio drop-in"
run "$SUDO install -Dm644 '$REPO_DIR/etc/modprobe.d/nvidia.conf'           /etc/modprobe.d/nvidia.conf"
run "$SUDO install -Dm644 '$REPO_DIR/etc/mkinitcpio.conf.d/nvidia.conf'    /etc/mkinitcpio.conf.d/nvidia.conf"
say "Installing greetd config"
run "$SUDO install -Dm644 '$REPO_DIR/etc/greetd/config.toml'               /etc/greetd/config.toml"
say "Regenerating initramfs (mkinitcpio -P)"
run "$SUDO mkinitcpio -P"

# --- 5. user groups ---------------------------------------------------------
say "Adding $TARGET_USER to video,input,gamemode groups"
run "$SUDO usermod -aG video,input '$TARGET_USER'"
# gamemode group is optional but lets gamemoderun lift the governor without sudo
getent group gamemode >/dev/null && run "$SUDO usermod -aG gamemode '$TARGET_USER'" || true
warn "Log out/in (or reboot) for group changes to apply."

# --- 6. runit services (Artix layout) ---------------------------------------
say "Enabling runit services in /etc/runit/runsvdir/default/"
RUNSVDIR=/etc/runit/runsvdir/default
for s in $(pkglist "$REPO_DIR/services.txt"); do
  if [ -e "$RUNSVDIR/$s" ]; then
    echo "  $s already enabled"
  elif [ -d "/etc/runit/sv/$s" ]; then
    run "$SUDO ln -s /etc/runit/sv/$s $RUNSVDIR/"
    echo "  enabled $s"
  else
    warn "no /etc/runit/sv/$s — skipped (dbus/socket-activated, or pkg not installed)"
  fi
done

# --- 7. paru + AUR ----------------------------------------------------------
if [ "$DO_AUR" = 1 ]; then
  if ! command -v paru >/dev/null; then
    say "Bootstrapping paru from AUR (one-time, as $TARGET_USER)"
    # paru-bin is the prebuilt variant — faster than compiling paru itself.
    if [ "$DRY" = 1 ]; then
      echo "  [dry-run] git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin && (cd /tmp/paru-bin && makepkg -si --noconfirm)"
    else
      sudo -u "$TARGET_USER" sh -c '
        set -e
        cd /tmp
        rm -rf paru-bin
        git clone https://aur.archlinux.org/paru-bin.git
        cd paru-bin
        makepkg -si --noconfirm
      '
    fi
  else
    echo "  paru already installed"
  fi

  AUR_PKGS=$(pkglist "$REPO_DIR/pkgs/aur.txt")
  if [ -n "$AUR_PKGS" ]; then
    say "Installing AUR packages via paru"
    echo "  $AUR_PKGS"
    if [ "$DRY" = 1 ]; then
      echo "  [dry-run] paru -S --needed --noconfirm $AUR_PKGS"
    else
      sudo -u "$TARGET_USER" paru -S --needed --noconfirm $AUR_PKGS
    fi
  fi
else
  warn "--no-aur: skipped paru bootstrap AND pkgs/aur.txt — Noctalia not installed."
fi

# --- done -------------------------------------------------------------------
say "Done."
cat <<'EOF'

Next steps:
  1. sudo reboot
  2. tuigreet appears on tty1 — log in (session command is "niri-session";
     leave it as-is).
  3. Verify the basics:
       nvidia-smi
       cat /sys/module/nvidia_drm/parameters/modeset      # -> Y
       echo $XDG_SESSION_TYPE                              # -> wayland
       echo $XDG_CURRENT_DESKTOP                           # -> niri
       vkcube                                              # 3090 renders
  4. Start Noctalia: it should auto-start via the niri config; if not,
     `qs -c noctalia` from a foot terminal. See docs/03-shell-noctalia.md
     for the niri spawn-at-startup config snippet.
  5. Steam: log in -> Settings -> Compatibility -> enable "Steam Play for
     all other titles". Install a game.
  6. Faugus Launcher: launch from Noctalia's app launcher (installed via AUR).
     Non-Steam / Epic / GOG: Faugus or Lutris.
  7. VRR: per-output `enable-vrr` in ~/.config/niri/config.kdl.
EOF
