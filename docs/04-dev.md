# 04 — Dev workstation on Void

Your Bazzite box is `bazzite-dx-nvidia` (the developer image). Inventory found:
fish 4.2, git, gcc 15, clang (Homebrew), make/cmake, python 3.14, node 26 + npm,
rust nightly + cargo, podman 5 + docker 29 + distrobox 1.8, VS Code, vim, tmux,
layered `java-21-openjdk mosh netbird nodejs npm`. All reproducible on Void.

## Toolchains & languages (`pkgs/50-dev.txt`)

```
base-devel clang lld gdb cmake meson ninja pkg-config
rustup go uv nodejs docker docker-compose podman fuse-overlayfs slirp4netns
distrobox flatpak fish-shell vscode
```

`base-devel` ≈ `build-essential` (gcc, make, binutils, headers).

Per-language rule for a **rolling** distro:

| Lang | Use | Avoid |
|---|---|---|
| C/C++ | system `clang`/`base-devel` gcc | — |
| Go | xbps `go` (fine, current) | per-version managers unless legacy |
| Rust | `rustup` then `rustup default stable` (you run nightly — `rustup default nightly`) | xbps `rust` |
| Python | system `python3` for scripts; **`uv`** for everything project-level | pyenv (recompiles) |
| Node | **`fnm`/`nvm`** for project-pinned versions | relying on xbps `nodejs` for app dev |

> `uv` may or may not be in the repos in your snapshot — if `xbps-query -Rs uv`
> is empty, install via `curl -LsSf https://astral.sh/uv/install.sh | sh`.
> `java-21-openjdk` equivalent on Void: `openjdk21` (add to the list if needed).
> `mosh`, `netbird` are both packaged on Void — add to `pkgs/50-dev.txt`.

## Containers under runit (no systemd)

**Rootless Podman** (daemonless, recommended default):
```sh
sudo xbps-install -S podman fuse-overlayfs slirp4netns
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
podman system migrate
```

**Docker** (when you need the daemon / compose-heavy workflows):
```sh
sudo xbps-install -S docker docker-compose
sudo ln -s /etc/sv/docker /var/service     # runit enable+start (NOT auto-enabled by bootstrap)
sudo usermod -aG docker $USER ; newgrp docker
```

**distrobox:** `xbps-install -S distrobox`. Void is officially supported as host
*and* image (`ghcr.io/void-linux/void-glibc-full`). Your Bazzite distrobox
workflow ports over essentially unchanged once podman/docker is set up. Your
Bazzite GUIs `DistroShelf`/`BoxBuddy` are in `flatpaks.txt`.

> **GPU-in-container** (CUDA/ML in podman): NVIDIA Container Toolkit isn't in
> xbps — install upstream `nvidia-ctk` and generate a CDI spec for rootless podman.

## Flatpak

Still worth it on Void: decouples GUI apps from the rolling base, gives
Bazzite-like sandboxing/portals, avoids long source builds. `bootstrap.sh` sets
up Flathub and (with `--flatpaks`) re-installs everything in `flatpaks.txt`.
Ensure `dbus`, pipewire, and `xdg-desktop-portal-kde` are present or
audio/file-picker break (handled by `pkgs/20-desktop.txt`).

## Editors

- VS Code: xbps `vscode` (OSS build) or `vscodium`. For the **MS Marketplace +
  proprietary `code`** (what you have on Bazzite), use Flatpak
  `com.visualstudio.code` — add it to `flatpaks.txt` if you want exact parity.
- Neovim/Helix: `xbps-install -S neovim helix`.
- JetBrains: Flatpak / Toolbox (don't bundle JREs against a rolling base).

## fish as login shell (you already use fish)

```sh
sudo xbps-install -S fish-shell
command -v fish | sudo tee -a /etc/shells
chsh -s "$(command -v fish)"
```
Config path `~/.config/fish/` is identical to Bazzite — bring it via chezmoi.

## Dev services under runit (per-need, not auto-enabled)

```sh
sudo xbps-install -S postgresql16 postgresql16-client redis
sudo ln -s /etc/sv/redis /var/service/
# Postgres: initdb, then create /etc/sv/postgresql/run -> chpst -u postgres postgres -D <datadir>
sudo ln -s /etc/sv/postgresql /var/service/
```
Disable: `sudo rm /var/service/<svc>` (or `touch /etc/sv/<svc>/down`).

## Sources

- Void Handbook — Services/runit: <https://docs.voidlinux.org/config/services/index.html>
- Flatpak on Void: <https://flatpak.org/setup/Void%20Linux>
- distrobox compatibility: <https://github.com/89luca89/distrobox/blob/main/docs/compatibility.md>
- Docker on Void: <https://docs.voidlinux.org/config/containers-and-vms/docker.html>
- rustup: <https://rustup.rs/> · uv: <https://docs.astral.sh/uv/>
