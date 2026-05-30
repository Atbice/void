#!/bin/sh
# faugus.sh — OPTIONAL, FRAGILE. Installs Faugus Launcher from source on Void
# without Flatpak. READ docs/00-faugus-optional.md FIRST. Lutris (docs/03) is
# the clean answer; this exists only if you specifically want Faugus's UI.
#
# Builds umu-launcher + faugus-launcher from source (meson/cargo). ALL deps —
# including python3-vdf and python3-icoextract — now come from xbps; no pipx/pip.
# umu/faugus themselves are source-built, so they update by re-running this.
#
# Usage: ./faugus.sh [--dry-run]
set -eu

DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
run() { if [ "$DRY" = 1 ]; then printf '  [dry-run] %s\n' "$*"; else sh -c "$*"; fi; }
say() { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }

# Void's /etc/os-release ships ID="void" (quoted) — match quoted OR unquoted.
if [ ! -r /etc/os-release ] || ! grep -Eq '^ID="?void"?$' /etc/os-release; then
  echo "REFUSING: not Void Linux." >&2; exit 1
fi
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
WORK="${TMPDIR:-/tmp}/faugus-build.$$"
trap 'rm -rf "$WORK"' EXIT

printf 'Faugus on Void is fragile (see docs/00). Continue? [y/N] '
read -r ans; case "$ans" in y|Y) ;; *) echo "aborted."; exit 0 ;; esac

say "Installing all build + runtime deps from xbps (no pipx/pip needed)"
run "$SUDO xbps-install -Sy meson ninja git rust cargo scdoc \
  python3-gobject python3-cairo python3-Pillow python3-psutil \
  python3-requests python3-pygame python3-vdf python3-icoextract \
  python3-build python3-installer python3-setuptools hatchling \
  gtk+3 libayatana-appindicator libcanberra ImageMagick Vulkan-Tools"

say "Building umu-launcher from source"
run "mkdir -p '$WORK'"
run "git clone --recurse-submodules https://github.com/Open-Wine-Components/umu-launcher '$WORK/umu-launcher'"
run "cd '$WORK/umu-launcher' && ./configure.sh --prefix=/usr && make && $SUDO make install"

say "Building faugus-launcher from source"
run "git clone https://github.com/Faugus/faugus-launcher '$WORK/faugus-launcher'"
run "cd '$WORK/faugus-launcher' && meson setup builddir --prefix=/usr && ninja -C builddir && $SUDO ninja -C builddir install"

say "Done. python3-vdf/python3-icoextract are real xbps packages now, so they"
echo "  update with 'sudo xbps-install -Su'. Re-run this script to update umu/faugus."
