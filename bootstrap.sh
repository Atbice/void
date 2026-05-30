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
    -h|--help)     awk 'NR==1{next} /^#/{sub(/^# ?/,"");print;next} {exit}' "$0"; exit 0 ;;
    *) echo "unknown arg: $a (see --help)" >&2; exit 2 ;;
  esac
done

say()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
run()  { if [ "$DRY" = 1 ]; then printf '  [dry-run] %s\n' "$*"; else sh -c "$*"; fi; }

# --- guard: Void only -------------------------------------------------------
# Void's /etc/os-release ships ID="void" (quoted) — match quoted OR unquoted.
if [ ! -r /etc/os-release ] || ! grep -Eq '^ID="?void"?$' /etc/os-release; then
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

# --- 2b. NVIDIA module config BEFORE the package install --------------------
# So the initramfs build that nvidia's DKMS install triggers already bakes in
# the modules (dracut conf) and the boot-time options (modprobe conf) are set.
say "Installing NVIDIA modprobe + dracut config (pre-install)"
run "$SUDO install -Dm644 '$REPO_DIR/etc/modprobe.d/nvidia.conf'    /etc/modprobe.d/nvidia.conf"
run "$SUDO install -Dm644 '$REPO_DIR/etc/dracut.conf.d/nvidia.conf' /etc/dracut.conf.d/nvidia.conf"

# --- 3. packages ------------------------------------------------------------
PKGS=$(pkglist "$REPO_DIR"/pkgs/10-core.txt "$REPO_DIR"/pkgs/20-desktop.txt \
                "$REPO_DIR"/pkgs/30-nvidia.txt "$REPO_DIR"/pkgs/40-gaming.txt)
say "Installing packages"; echo "  $PKGS"
run "$SUDO xbps-install -y $PKGS"

# --- 4. SDDM config + initramfs regen + NVIDIA DKMS gate -------------------
say "Installing SDDM Wayland-greeter config (recovery recipe in docs/02)"
run "$SUDO install -Dm644 '$REPO_DIR/etc/sddm.conf.d/10-wayland.conf' /etc/sddm.conf.d/10-wayland.conf"
say "Regenerating initramfs (xbps-reconfigure -fa)"
run "$SUDO xbps-reconfigure -fa"

# xbps exits 0 even when the DKMS build FAILS (void-packages#42047), so a black
# screen on reboot can masquerade as success. Gate hard on the real module for
# the kernel we'll actually boot.
say "Verifying the NVIDIA kernel module built (DKMS)"
if [ "$DRY" = 1 ]; then
  echo "  [dry-run] dkms status nvidia (would hard-fail unless 'installed' for newest kernel)"
else
  NEWK=$(ls /usr/lib/modules 2>/dev/null | sort -V | tail -1)
  if ! dkms status nvidia 2>/dev/null | grep -F "$NEWK" | grep -q installed; then
    warn "NVIDIA DKMS module is NOT installed for kernel $NEWK."
    warn "Inspect /var/lib/dkms/nvidia/*/build/make.log, fix the build, then re-run"
    warn "./bootstrap.sh (idempotent). Do NOT reboot expecting a Wayland desktop."
    exit 1
  fi
  echo "  dkms: nvidia installed for $NEWK"
  if [ "$(uname -r)" != "$NEWK" ]; then
    warn "The update pulled a newer kernel ($NEWK) than the running one ($(uname -r))."
    warn "Reboot now, then re-run ./bootstrap.sh to finish on $NEWK (safe: idempotent)."
    exit 1
  fi
fi

# --- 5. runit services ------------------------------------------------------
# NOTE: elogind is deliberately NOT enabled as a runit service. On current Void
# it is dbus-activated (org.freedesktop.login1) — symlinking /etc/sv/elogind on
# top of that starts a second instance and produces an "elogind is already
# running as PID N" runsv respawn loop that bricks the desktop. See services.txt.
# The guard below refuses to enable it even if it gets re-added to services.txt.
say "Enabling runit services"
for s in $(pkglist "$REPO_DIR/services.txt"); do
  if [ "$s" = elogind ]; then
    warn "refusing to enable elogind as a runit service — it is dbus-activated on Void; a standalone service races it into an 'already running' respawn loop. Skipped."
  elif [ -e "/var/service/$s" ]; then echo "  $s already enabled"
  elif [ -d "/etc/sv/$s" ]; then run "$SUDO ln -s /etc/sv/$s /var/service/"; echo "  enabled $s"
  else warn "no /etc/sv/$s — skipped (package not installed?)"; fi
done

# --- 5b. PipeWire (Void does NOT autostart it — without this there is NO audio)
# pipewire/wireplumber ship .desktop files in /usr/share/applications (NOT
# /etc/xdg/autostart) and KDE won't auto-spawn them, so the desktop AND games
# are silent. Link the autostart + the conf.d drop-ins + the ALSA bridges.
say "Wiring up PipeWire (autostart + pulse replacement + ALSA bridges)"
run "$SUDO install -d /etc/pipewire/pipewire.conf.d /etc/alsa/conf.d /etc/xdg/autostart"
for pair in \
  '/usr/share/examples/wireplumber/10-wireplumber.conf:/etc/pipewire/pipewire.conf.d/' \
  '/usr/share/examples/pipewire/20-pipewire-pulse.conf:/etc/pipewire/pipewire.conf.d/' \
  '/usr/share/alsa/alsa.conf.d/50-pipewire.conf:/etc/alsa/conf.d/' \
  '/usr/share/alsa/alsa.conf.d/99-pipewire-default.conf:/etc/alsa/conf.d/' \
  '/usr/share/applications/pipewire.desktop:/etc/xdg/autostart/'; do
  src=${pair%:*}; dst=${pair##*:}
  if [ -e "$src" ] || [ "$DRY" = 1 ]; then run "$SUDO ln -sf '$src' '$dst'"; echo "  linked $src"
  else warn "PipeWire example missing: $src (skipped — audio may need manual setup)"; fi
done

# --- 5c. Keyboard layout: Swedish -------------------------------------------
# Three independent places need it: console TTYs (rc.conf), the Wayland/Plasma
# session default (libxkbcommon via pam_env), and the SDDM greeter (set in
# etc/sddm.conf.d/10-wayland.conf, since the greeter ignores /etc/environment).
say "Setting keyboard layout to Swedish (console + Wayland session)"
run "$SUDO sed -i '/^KEYMAP=/d' /etc/rc.conf"
run "printf '%s\\n' 'KEYMAP=sv-latin1' | $SUDO tee -a /etc/rc.conf >/dev/null"
if ! grep -q '^XKB_DEFAULT_LAYOUT=' /etc/environment 2>/dev/null; then
  run "printf '%s\\n' 'XKB_DEFAULT_LAYOUT=se' | $SUDO tee -a /etc/environment >/dev/null"
fi

# --- 6. Steam-on-Void fixes (MANDATORY for native Steam) --------------------
say "Applying mandatory Steam-on-Void fixes"
if [ ! -e /usr/lib64/gconv ] && [ -d /usr/lib/gconv ]; then
  run "$SUDO ln -s ../lib/gconv /usr/lib64/gconv"; echo "  linked /usr/lib64/gconv"
else echo "  gconv: nothing to do"; fi
run "printf '%s\\n' 'export GCONV_PATH=/usr/lib/gconv' | $SUDO tee /etc/profile.d/steam-void.sh >/dev/null"
run "$SUDO chmod 644 /etc/profile.d/steam-void.sh"
# belt-and-suspenders: also expose GCONV_PATH via pam_env (/etc/environment) so
# it survives a session start that doesn't source /etc/profile. profile.d above
# is the primary path; this is a no-op if it's already present.
if ! grep -q '^GCONV_PATH=' /etc/environment 2>/dev/null; then
  run "printf '%s\\n' 'GCONV_PATH=/usr/lib/gconv' | $SUDO tee -a /etc/environment >/dev/null"
fi
run "printf '%s\\n%s\\n' '* soft nofile 1048576' '* hard nofile 1048576' | $SUDO tee /etc/security/limits.d/steam.conf >/dev/null"
GRPS=video,input
if grep -q '^bluetooth:' /etc/group 2>/dev/null; then GRPS="$GRPS,bluetooth"; fi
run "$SUDO usermod -aG $GRPS '$TARGET_USER'"
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
       vkcube            # window MUST name "GeForce RTX 3090" (NOT llvmpipe)
       wpctl status      # audio: a sink must be listed (else PipeWire is dead)
       dkms status nvidia                                  # -> installed
  4. Steam -> log in -> Settings -> Compatibility ->
       enable "Steam Play for all other titles" -> install a game.
  5. Faugus Launcher: installed as a Flatpak — launch it from the menu.
     Non-Steam / Epic / GOG: Faugus or native Lutris (both have GE-Proton).
  6. VRR/HDR: System Settings -> Display & Monitor.
EOF
