#!/bin/sh
# faugus.sh — OPTIONAL, FRAGILE. Installs Faugus Launcher from source on Void
# without Flatpak. READ docs/00-faugus-optional.md FIRST. Lutris (docs/03) is
# the clean answer; this exists only if you specifically want Faugus's UI.
#
# This builds from source and uses pipx for two deps that are NOT in xbps
# (vdf, icoextract). It is NOT tracked by xbps and will rot on Python upgrades.
#
# Usage: ./faugus.sh [--dry-run]
set -eu

DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
run() { if [ "$DRY" = 1 ]; then printf '  [dry-run] %s\n' "$*"; else sh -c "$*"; fi; }
say() { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }

if [ ! -r /etc/os-release ] || ! grep -q '^ID=void' /etc/os-release; then
  echo "REFUSING: not Void Linux." >&2; exit 1
fi
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
WORK="${TMPDIR:-/tmp}/faugus-build.$$"

printf 'Faugus on Void is fragile (see docs/00). Continue? [y/N] '
read -r ans; case "$ans" in y|Y) ;; *) echo "aborted."; exit 0 ;; esac

say "Installing build + runtime deps available in xbps"
run "$SUDO xbps-install -Sy meson ninja git rust cargo scdoc \
  python3-gobject python3-cairo python3-Pillow python3-psutil \
  python3-requests python3-pygame gtk+3 libayatana-appindicator \
  libcanberra ImageMagick vulkan-tools pipx"

say "Installing xbps-gap Python deps via pipx (NOT package-managed)"
run "pipx install vdf || pip install --user vdf"
run "pipx install icoextract || pip install --user icoextract"

say "Building umu-launcher from source"
run "mkdir -p '$WORK'"
run "git clone --recurse-submodules https://github.com/Open-Wine-Components/umu-launcher '$WORK/umu-launcher'"
run "cd '$WORK/umu-launcher' && ./configure.sh --prefix=/usr && make && $SUDO make install"

say "Building faugus-launcher from source"
run "git clone https://github.com/Faugus/faugus-launcher '$WORK/faugus-launcher'"
run "cd '$WORK/faugus-launcher' && meson setup builddir --prefix=/usr && ninja -C builddir && $SUDO ninja -C builddir install"

run "rm -rf '$WORK'"
say "Done. Reminder: after any Void Python major bump, run: pipx reinstall-all"
echo "  (else vdf/icoextract import fails and Faugus won't start)."
