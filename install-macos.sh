#!/usr/bin/env bash
#
# macOS counterpart to install.sh: Homebrew, language servers, formatters,
# plugins, treesitter parsers and the global .clang-format.
#
# Run it from inside a clone of this repo: if the clone isn't at
# ~/.config/nvim it gets symlinked there (an existing config is moved
# aside). Safe to re-run, since every step checks before acting.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="$HOME/.zprofile" # macOS logs in with zsh
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/scripts/lib.sh"

if [ "$(uname -s)" != Darwin ]; then
    echo "This script is for macOS only. Use install.sh on Arch-based Linux." >&2
    exit 1
fi
if [ ! -f "$SCRIPT_DIR/init.lua" ]; then
    echo "Run this from inside the cloned nvim config (expected init.lua next to install-macos.sh)." >&2
    exit 1
fi

link_config

note "Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then
    ok "already installed"
else
    warn "not installed: opening the install prompt (a GUI dialog)"
    xcode-select --install
    echo "Finish that install, then re-run this script." >&2
    exit 1
fi

note "Homebrew"
if ! command -v brew >/dev/null 2>&1; then
    warn "not found, installing"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
if [ -x /opt/homebrew/bin/brew ]; then
    BREW_PREFIX=/opt/homebrew
elif [ -x /usr/local/bin/brew ]; then
    BREW_PREFIX=/usr/local
else
    echo "Homebrew install did not produce a usable brew binary, aborting." >&2
    exit 1
fi
eval "$("$BREW_PREFIX/bin/brew" shellenv)"
append_once "eval \"\$($BREW_PREFIX/bin/brew shellenv)\"" "$PROFILE"
ok "brew available at $BREW_PREFIX/bin/brew"
brew update >/dev/null 2>&1 || warn "brew update failed, continuing with whatever's cached"

note "Installing core packages (Homebrew)"
CORE_PKGS=(
    git neovim ripgrep fd unzip wget cmake
    tree-sitter-cli # nvim-treesitter builds parsers with it
    alejandra       # Nix formatter used by nil
    llvm            # clangd (keg-only, PATH handled below)
    clang-format    # standalone, not keg-only
    rust rust-analyzer
    go gopls
    lua-language-server
    node
    python@3.13
    zls
    haskell-language-server
    openjdk         # keg-only, PATH handled below
    jdtls           # runs on openjdk even off PATH
    hurl jq         # REST client (hurl.nvim) and JSON response formatting
)
if brew install "${CORE_PKGS[@]}"; then
    ok "core packages installed"
else
    warn "one or more core packages failed to install, check the output above"
    FAILED+=("core Homebrew packages")
fi

# llvm and openjdk are keg-only (not linked onto PATH): add their bin dirs,
# or clangd isn't found and java is macOS's stub that asks you to install it.
for keg in llvm openjdk; do
    bin="$(brew --prefix "$keg" 2>/dev/null)/bin"
    if [ -d "$bin" ]; then
        add_to_path "$bin"
        ok "added $bin to PATH"
    else
        warn "could not find $keg's bin directory"
        FAILED+=("$keg on PATH")
    fi
done

note "Nerd Font (Hermit)"
if brew install --cask font-hurmit-nerd-font; then
    ok "font installed"
else
    warn "font cask failed, install it manually if icons look wrong in nvim"
    FAILED+=("Nerd Font")
fi

install_npm_packages

note "Installing cmake-language-server (Homebrew)"
if brew install cmake-language-server >/dev/null 2>&1; then
    ok "cmake-language-server"
else
    warn "cmake-language-server failed to install"
    FAILED+=("cmake-language-server")
fi

install_templ

note "Installing language servers not on Homebrew (into ~/.local/bin)"
mkdir -p "$LOCAL_BIN"
add_to_path "$LOCAL_BIN"
ARCH="$(uname -m)"
if [ "$ARCH" = arm64 ]; then
    release_bin glsl_analyzer https://github.com/nolanderc/glsl_analyzer/releases/latest/download/aarch64-macos.zip bin/glsl_analyzer
    release_bin c3lsp https://github.com/pherrymason/c3-lsp/releases/latest/download/c3lsp-darwin-arm64.zip server/bin/release/c3lsp
else
    release_bin glsl_analyzer https://github.com/nolanderc/glsl_analyzer/releases/latest/download/x86_64-macos.zip bin/glsl_analyzer
    warn "c3lsp has no Intel Mac build, skipping"
    SKIPPED+=("c3lsp (no Intel build)")
fi
# serve-d is only built for Intel, so Apple Silicon runs it under Rosetta.
if [ "$ARCH" = arm64 ] && ! arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    warn "serve-d needs Rosetta: run 'softwareupdate --install-rosetta --agree-to-license', then re-run"
    FAILED+=("serve-d (Rosetta missing)")
else
    v="$(serve_d_version)"
    release_bin serve-d "https://github.com/Pure-D/serve-d/releases/download/v$v/serve-d_$v-osx-x86_64.tar.gz" serve-d
fi

# nil (Nix language server) has no macOS binaries and needs nix to build.
if ! command -v nix >/dev/null 2>&1; then
    warn "nix not installed, skipping nil (only needed for .nix files)"
    SKIPPED+=("nil (needs nix)")
elif command -v nil >/dev/null 2>&1 \
    || nix --extra-experimental-features 'nix-command flakes' profile install nixpkgs#nil >/dev/null 2>&1; then
    ok "nil"
else
    warn "nil failed to install from nixpkgs"
    FAILED+=("nil")
fi

install_clang_format
sync_nvim

# No clipboard tool needed: macOS's pbcopy/pbpaste work out of the box.
finish \
    "Open a new terminal (so the PATH changes in ~/.zprofile take effect) and" \
    "nvim is ready. Set your terminal's font to Hurmit Nerd Font Mono if it" \
    "isn't already, so icons render."
