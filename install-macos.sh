#!/usr/bin/env bash
#
# macOS counterpart to install.sh (which targets Arch/pacman). Sets up a
# fresh Mac to use this Neovim config: Homebrew, language servers,
# formatting tools, and the global .clang-format.
#
# Assumes this repo is already cloned to ~/.config/nvim and this script is
# being run from inside it.
#
# Safe to re-run: every step either checks before acting or uses an
# idempotent install flag, so running this again after adding new tools
# just fills in whatever's missing.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=()
SKIPPED=()

note()  { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
ok()    { printf '\033[1;32m  ok:\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m  warn:\033[0m %s\n' "$1"; }

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This script is for macOS only. Use install.sh on Arch-based Linux." >&2
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/init.lua" ]; then
    echo "Run this from inside the cloned nvim config (expected init.lua next to install-macos.sh)." >&2
    exit 1
fi

# Appends a line to a profile file if it isn't already present.
append_once() {
    local line="$1" file="$2"
    mkdir -p "$(dirname "$file")"
    touch "$file"
    grep -qxF "$line" "$file" || echo "$line" >> "$file"
}

# ---------------------------------------------------------------------------
note "Xcode Command Line Tools"
# ---------------------------------------------------------------------------
if xcode-select -p >/dev/null 2>&1; then
    ok "already installed"
else
    warn "not installed — triggering the install prompt now (this opens a GUI dialog)"
    xcode-select --install
    echo "Finish that install, then re-run this script." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
note "Homebrew"
# ---------------------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
    warn "not found, installing"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [ -x /opt/homebrew/bin/brew ]; then
    BREW_PREFIX="/opt/homebrew"
elif [ -x /usr/local/bin/brew ]; then
    BREW_PREFIX="/usr/local"
else
    echo "Homebrew install did not produce a usable brew binary — aborting." >&2
    exit 1
fi
eval "$("$BREW_PREFIX/bin/brew" shellenv)"
append_once "eval \"\$($BREW_PREFIX/bin/brew shellenv)\"" "$HOME/.zprofile"
ok "brew available at $BREW_PREFIX/bin/brew"

brew update >/dev/null 2>&1 || warn "brew update failed, continuing with whatever's cached"

# ---------------------------------------------------------------------------
note "Installing core packages (Homebrew formulae)"
# ---------------------------------------------------------------------------
CORE_PKGS=(
    git neovim ripgrep fd unzip wget cmake
    llvm             # clangd (keg-only, PATH handled below)
    clang-format     # standalone, not keg-only
    rust rust-analyzer
    go gopls
    lua-language-server
    node
    python@3.13
    zls
    haskell-language-server
)
if brew install "${CORE_PKGS[@]}"; then
    ok "core packages installed"
else
    warn "one or more core packages failed to install — check output above"
    FAILED+=("core Homebrew packages")
fi

# llvm is keg-only: not linked onto PATH by default, so clangd wouldn't be found.
LLVM_BIN="$(brew --prefix llvm 2>/dev/null)/bin"
if [ -d "$LLVM_BIN" ]; then
    export PATH="$LLVM_BIN:$PATH"
    append_once "export PATH=\"$LLVM_BIN:\$PATH\"" "$HOME/.zprofile"
    ok "added $LLVM_BIN to PATH (clangd lives here)"
else
    warn "could not resolve llvm's bin directory — clangd may not be on PATH"
    FAILED+=("clangd on PATH")
fi

# ---------------------------------------------------------------------------
note "Nerd Font (JetBrains Mono)"
# ---------------------------------------------------------------------------
if brew install --cask font-jetbrains-mono-nerd-font; then
    ok "font installed"
else
    warn "font cask failed — install manually if icons look wrong in nvim"
    FAILED+=("Nerd Font")
fi

# ---------------------------------------------------------------------------
note "Installing npm-based language servers"
# ---------------------------------------------------------------------------
if command -v npm >/dev/null 2>&1; then
    NPM_PKGS=(
        typescript typescript-language-server
        intelephense
        vscode-langservers-extracted
        vscode-json-languageserver
        "@tailwindcss/language-server"
    )
    for pkg in "${NPM_PKGS[@]}"; do
        if npm install -g "$pkg" >/dev/null 2>&1; then
            ok "npm: $pkg"
        else
            warn "npm: $pkg failed to install"
            FAILED+=("npm package: $pkg")
        fi
    done
else
    warn "npm not found, skipping npm-based language servers"
    FAILED+=("all npm language servers (npm missing)")
fi

# ---------------------------------------------------------------------------
note "Installing cmake-language-server (pip)"
# ---------------------------------------------------------------------------
PYTHON_BIN="$(brew --prefix python@3.13 2>/dev/null)/bin/python3.13"
if [ -x "$PYTHON_BIN" ]; then
    if "$PYTHON_BIN" -m pip install --user --break-system-packages cmake-language-server >/dev/null 2>&1 \
        || "$PYTHON_BIN" -m pip install --user cmake-language-server >/dev/null 2>&1; then
        ok "cmake-language-server"
    else
        warn "cmake-language-server failed to install via pip"
        FAILED+=("cmake-language-server")
    fi
else
    warn "python@3.13 not found on expected path, skipping cmake-language-server"
    FAILED+=("cmake-language-server (python missing)")
fi

# ---------------------------------------------------------------------------
note "Installing templ (go install)"
# ---------------------------------------------------------------------------
if command -v go >/dev/null 2>&1; then
    if go install github.com/a-h/templ/cmd/templ@latest >/dev/null 2>&1; then
        GOBIN="$(go env GOPATH)/bin"
        append_once "export PATH=\"$GOBIN:\$PATH\"" "$HOME/.zprofile"
        export PATH="$GOBIN:$PATH"
        ok "templ (installed to $GOBIN, added to PATH)"
    else
        warn "templ failed to install"
        FAILED+=("templ")
    fi
else
    warn "go not found, skipping templ"
    FAILED+=("templ (go missing)")
fi

# ---------------------------------------------------------------------------
note "Not available via Homebrew (install manually if you need them)"
# ---------------------------------------------------------------------------
NOT_ON_BREW=(nil glsl_analyzer c3-lsp serve-d)
for pkg in "${NOT_ON_BREW[@]}"; do
    SKIPPED+=("$pkg")
done
warn "no Homebrew formula for: ${NOT_ON_BREW[*]} — build from source if you need those filetypes"
warn "your config will still work without them; those filetypes just won't get LSP support until installed"

# ---------------------------------------------------------------------------
note "Installing global .clang-format"
# ---------------------------------------------------------------------------
if [ -f "$SCRIPT_DIR/assets/clang-format-global" ]; then
    cp "$SCRIPT_DIR/assets/clang-format-global" "$HOME/.clang-format"
    ok "copied to ~/.clang-format"
else
    warn "assets/clang-format-global not found in repo, skipping"
    FAILED+=(".clang-format")
fi

# ---------------------------------------------------------------------------
note "Installing Neovim plugins (lazy.nvim sync)"
# ---------------------------------------------------------------------------
if command -v nvim >/dev/null 2>&1; then
    if nvim --headless "+Lazy! sync" +qa >/tmp/nvim-install-sync.log 2>&1; then
        ok "plugins synced"
    else
        warn "plugin sync reported an issue — see /tmp/nvim-install-sync.log"
        FAILED+=("lazy.nvim plugin sync")
    fi
else
    warn "nvim not found even after package install — something went wrong above"
    FAILED+=("nvim itself")
fi

# ---------------------------------------------------------------------------
note "Summary"
# ---------------------------------------------------------------------------
if [ ${#FAILED[@]} -eq 0 ]; then
    ok "Everything installed cleanly."
else
    warn "These need attention:"
    for f in "${FAILED[@]}"; do
        printf '    - %s\n' "$f"
    done
fi
if [ ${#SKIPPED[@]} -gt 0 ]; then
    warn "Not on Homebrew, install manually if you need them: ${SKIPPED[*]}"
fi
echo
echo "Open a new terminal (so the PATH changes in ~/.zprofile take effect), then"
echo "open nvim, restart it once fully, and check :Lazy and :checkhealth."

if [ ${#FAILED[@]} -eq 0 ]; then
    exit 0
else
    exit 1
fi
