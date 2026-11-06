#!/usr/bin/env bash
#
# Sets up an Arch-based machine for this Neovim config: system packages,
# language servers, formatters, plugins, treesitter parsers and the global
# .clang-format. install-macos.sh and install-windows.ps1 do the same for
# other systems, and tests/smoke.lua checks the result.
#
#   ./install.sh          install everything
#   ./install.sh --check  only verify that every package name and download
#                         URL used here exists (needs network; changes nothing)
#
# Run it from inside a clone of this repo: if the clone isn't at
# ~/.config/nvim it gets symlinked there (an existing config is moved
# aside). Safe to re-run, since every step checks before acting.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# PATH additions go in the profile of the shell the user logs in with, read
# from the passwd entry rather than $SHELL (which can be stale). fish doesn't
# read POSIX profiles, so it gets a conf.d snippet.
case "$(basename "$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)")" in
    zsh) PROFILE="$HOME/.zprofile" ;;
    bash) PROFILE="$HOME/.bash_profile" ;;
    fish) PROFILE="${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/nvim-config.fish" ;;
    *) PROFILE="$HOME/.profile" ;;
esac
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/scripts/lib.sh"

ARCH="$(uname -m)"
CORE_PKGS=(
    git base-devel neovim ripgrep fd unzip curl wget cmake
    tree-sitter-cli # nvim-treesitter builds parsers with it
    clang           # clangd, clang-format, clang-tidy
    rust-analyzer
    go gopls
    lua-language-server
    nodejs npm
    python python-pipx
    zls
    haskell-language-server
    jdk-openjdk     # jdtls needs Java 21+
    hurl jq         # REST client (hurl.nvim) and JSON response formatting
    wl-clipboard xclip
    otf-hermit-nerd
)
AUR_PKGS=(nil-git jdtls) # only used when there's an AUR helper (see below)
JDTLS_URL=https://download.eclipse.org/jdtls/snapshots/jdt-language-server-latest.tar.gz

# Writes the release binaries published for this architecture to
# $TMP_DL/releases, one per line as "name url [path inside the archive]".
# (Called with a plain redirect, not $(...), so SKIPPED updates stick.)
release_binaries() {
    case "$ARCH" in
        x86_64 | aarch64)
            echo "glsl_analyzer https://github.com/nolanderc/glsl_analyzer/releases/latest/download/$ARCH-linux-musl.zip bin/glsl_analyzer"
            echo "alejandra https://github.com/kamadorueda/alejandra/releases/latest/download/alejandra-$ARCH-unknown-linux-musl" # Nix formatter used by nil
            ;;
        *) SKIPPED+=("glsl_analyzer and alejandra (no $ARCH build)") ;;
    esac
    if [ "$ARCH" = x86_64 ]; then
        echo "c3lsp https://github.com/pherrymason/c3-lsp/releases/latest/download/c3lsp-linux-amd64.tar.gz server/bin/release/c3lsp"
        local v
        v="$(serve_d_version)"
        echo "serve-d https://github.com/Pure-D/serve-d/releases/download/v$v/serve-d_$v-linux-x86_64.tar.gz serve-d"
    else
        SKIPPED+=("c3lsp and serve-d (no $ARCH build)")
    fi
}

aur_exists() {
    local out
    out="$(curl -fsS "https://aur.archlinux.org/rpc/v5/info?arg%5B%5D=$1")" && [[ "$out" == *'"resultcount":1'* ]]
}

# The first AUR helper found, if any.
AUR_HELPER="$(command -v paru yay 2>/dev/null | head -n1)"

# --check: verify names and URLs without installing anything.
check() {
    note "Checking package names and download URLs (installs nothing)"
    local pkg name url _
    for pkg in "${CORE_PKGS[@]}" rust; do
        if pacman -Si "$pkg" >/dev/null 2>&1; then ok "pacman: $pkg"; else warn "pacman: $pkg not found"; FAILED+=("pacman: $pkg"); fi
    done
    for pkg in "${AUR_PKGS[@]}"; do
        if aur_exists "$pkg"; then ok "AUR: $pkg"; else warn "AUR: $pkg not found"; FAILED+=("AUR: $pkg"); fi
    done
    while read -r pkg; do
        if npm view "$pkg" version >/dev/null 2>&1; then ok "npm: $pkg"; else warn "npm: $pkg not found"; FAILED+=("npm: $pkg"); fi
    done < <(read_list "$SCRIPT_DIR/scripts/npm-packages.txt")
    release_binaries >"$TMP_DL/releases"
    while read -r name url _; do
        if curl -fsSIL -o /dev/null "$url"; then ok "download: $name"; else warn "download: $name ($url)"; FAILED+=("download: $name"); fi
    done <"$TMP_DL/releases"
    if curl -fsSIL -o /dev/null "$JDTLS_URL"; then ok "download: jdtls"; else FAILED+=("download: jdtls"); fi
    SUMMARY_OK="Every package name and download URL exists."
    finish
}

if [ "$(uname -s)" != Linux ] || ! command -v pacman >/dev/null 2>&1; then
    echo "This script is for Arch-based Linux (pacman not found)." >&2
    echo "Use install-macos.sh on macOS, or see README.md for the package list." >&2
    exit 1
fi
if [ "$EUID" -eq 0 ]; then
    echo "Run this as your normal user, not root: it calls sudo itself for pacman." >&2
    exit 1
fi
if [ ! -f "$SCRIPT_DIR/init.lua" ]; then
    echo "Run this from inside the cloned nvim config (expected init.lua next to install.sh)." >&2
    exit 1
fi
case "${1:-}" in
    --check) check ;;
    "") ;;
    *) echo "usage: ./install.sh [--check]" >&2; exit 2 ;;
esac

link_config

note "Installing core packages (pacman)"
# rust conflicts with rustup; if rustup manages the toolchain, just make
# sure rustfmt is there.
if command -v rustup >/dev/null 2>&1; then
    rustup component add rustfmt >/dev/null 2>&1 || warn "rustup: could not add rustfmt"
    ok "rustup found, using its toolchain instead of the rust package"
else
    CORE_PKGS+=(rust)
fi
# -Syu, not -S: installing against a stale package database is a partial
# upgrade, which Arch doesn't support.
if sudo pacman -Syu --needed --noconfirm "${CORE_PKGS[@]}"; then
    ok "core packages installed"
else
    warn "one or more core packages failed to install, check the output above"
    FAILED+=("core pacman packages")
fi

mkdir -p "$LOCAL_BIN"
add_to_path "$LOCAL_BIN"

# Arch's npm prefix is /usr, where `npm install -g` needs root; use ~/.local
# instead so globals land in ~/.local/bin.
if command -v npm >/dev/null 2>&1 && [ ! -w "$(npm config get prefix)" ]; then
    npm config set prefix "$HOME/.local"
    ok "npm global prefix set to ~/.local"
fi
install_npm_packages

note "Installing cmake-language-server (pipx)"
if command -v cmake-language-server >/dev/null 2>&1 || pipx install cmake-language-server >/dev/null 2>&1; then
    ok "cmake-language-server"
else
    warn "cmake-language-server failed to install via pipx"
    FAILED+=("cmake-language-server")
fi

install_templ

note "Installing tools not in the official repos (into ~/.local/bin)"
release_binaries >"$TMP_DL/releases"
while read -r name url inner; do
    release_bin "$name" "$url" "$inner"
done <"$TMP_DL/releases"

# nil (Nix language server) has no release binaries: use nix if present,
# otherwise the AUR.
if command -v nil >/dev/null 2>&1; then
    ok "nil (already installed)"
elif command -v nix >/dev/null 2>&1; then
    if nix --extra-experimental-features 'nix-command flakes' profile install nixpkgs#nil >/dev/null 2>&1; then
        ok "nil (from nixpkgs)"
    else
        warn "nil failed to install from nixpkgs"
        FAILED+=("nil")
    fi
elif [ -n "$AUR_HELPER" ]; then
    if "$AUR_HELPER" -S --needed --noconfirm nil-git; then
        ok "nil (nil-git from the AUR)"
    else
        warn "nil failed to install from the AUR"
        FAILED+=("nil")
    fi
else
    warn "neither nix nor an AUR helper found, skipping nil (only needed for .nix files)"
    SKIPPED+=("nil (needs nix or an AUR helper)")
fi

# jdtls (Java) is only in the AUR. Without a helper, use the upstream build,
# unpacked into ~/.local/share/jdtls and linked into ~/.local/bin (its
# launcher follows the symlink to find its files).
if command -v jdtls >/dev/null 2>&1; then
    ok "jdtls (already installed)"
elif [ -n "$AUR_HELPER" ]; then
    if "$AUR_HELPER" -S --needed --noconfirm jdtls; then
        ok "jdtls (from the AUR)"
    else
        warn "jdtls failed to install from the AUR"
        FAILED+=("jdtls")
    fi
else
    mkdir -p "$TMP_DL/jdtls"
    if curl -fsSL -o "$TMP_DL/jdtls.tar.gz" "$JDTLS_URL" && tar -xzf "$TMP_DL/jdtls.tar.gz" -C "$TMP_DL/jdtls"; then
        rm -rf "$HOME/.local/share/jdtls"
        mv "$TMP_DL/jdtls" "$HOME/.local/share/jdtls"
        ln -sf "$HOME/.local/share/jdtls/bin/jdtls" "$LOCAL_BIN/jdtls"
        ok "jdtls (upstream build in ~/.local/share/jdtls)"
    else
        warn "jdtls failed to download"
        FAILED+=("jdtls")
    fi
fi
# jdtls won't start on Java older than 21, and archlinux-java may still point
# at an older JDK installed earlier.
JAVA_MAJOR="$(java -version 2>&1 | sed -n 's/.*version "\([0-9]*\).*/\1/p' | head -n1)"
if [ -n "$JAVA_MAJOR" ] && [ "$JAVA_MAJOR" -lt 21 ]; then
    warn "default java is $JAVA_MAJOR but jdtls needs 21+: pick one from 'archlinux-java status' and run 'sudo archlinux-java set <name>'"
    FAILED+=("java 21+ as the default JDK")
fi

install_clang_format
sync_nvim

CLOSING=(
    "Open a new terminal (so the PATH changes in $PROFILE take effect) and"
    "nvim is ready. Set your terminal's font to Hurmit Nerd Font Mono if it"
    "isn't already, so icons render."
)
if grep -qi microsoft /proc/version 2>/dev/null; then
    CLOSING+=(
        ""
        "WSL detected: install the Nerd Font on the Windows side and select it in"
        "Windows Terminal (fonts installed inside WSL aren't used there), and keep"
        "projects under ~ rather than /mnt/c for usable LSP and search speed."
    )
fi
finish "${CLOSING[@]}"
