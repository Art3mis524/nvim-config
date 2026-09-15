#!/usr/bin/env bash
#
# Sets up a fresh machine to use this Neovim config: system packages,
# language servers, formatting tools, and the global .clang-format.
#
# Assumes this repo is already cloned to ~/.config/nvim and this script is
# being run from inside it. Targets Arch-based distros (pacman) — see
# README.md for what to substitute on other distros.
#
# Safe to re-run: every step either checks before acting or uses an
# idempotent install flag (--needed, -g, --user), so running this again
# after adding new tools just fills in whatever's missing.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=()
SKIPPED=()

note()  { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
ok()    { printf '\033[1;32m  ok:\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m  warn:\033[0m %s\n' "$1"; }

if ! command -v pacman >/dev/null 2>&1; then
    echo "This script only supports Arch-based distros (pacman not found)." >&2
    echo "See README.md for the manual package list to install on other distros." >&2
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/init.lua" ]; then
    echo "Run this from inside the cloned nvim config (expected init.lua next to install.sh)." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
note "Installing core packages (pacman)"
# ---------------------------------------------------------------------------
CORE_PKGS=(
    git base-devel neovim ripgrep fd unzip curl wget cmake
    clang            # clangd + clang-format + clang-tidy
    rust-analyzer
    go gopls
    lua-language-server
    nodejs npm
    python python-pip
    wl-clipboard xclip
    ttf-jetbrains-mono-nerd
)
if sudo pacman -S --needed --noconfirm "${CORE_PKGS[@]}"; then
    ok "core packages installed"
else
    warn "one or more core packages failed to install — check output above"
    FAILED+=("core pacman packages")
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
if command -v pip >/dev/null 2>&1; then
    if pip install --user --break-system-packages cmake-language-server >/dev/null 2>&1 \
        || pip install --user cmake-language-server >/dev/null 2>&1; then
        ok "cmake-language-server"
    else
        warn "cmake-language-server failed to install via pip"
        FAILED+=("cmake-language-server")
    fi
else
    warn "pip not found, skipping cmake-language-server"
    FAILED+=("cmake-language-server (pip missing)")
fi

# ---------------------------------------------------------------------------
note "Installing templ (go install)"
# ---------------------------------------------------------------------------
if command -v go >/dev/null 2>&1; then
    if go install github.com/a-h/templ/cmd/templ@latest >/dev/null 2>&1; then
        ok "templ (installed to \$(go env GOPATH)/bin — make sure that's on your PATH)"
    else
        warn "templ failed to install"
        FAILED+=("templ")
    fi
else
    warn "go not found, skipping templ"
    FAILED+=("templ (go missing)")
fi

# ---------------------------------------------------------------------------
note "AUR-only language servers (not installed by this script)"
# ---------------------------------------------------------------------------
AUR_ONLY=(zls nil glsl_analyzer c3-lsp serve-d haskell-language-server)
for pkg in "${AUR_ONLY[@]}"; do
    SKIPPED+=("$pkg")
done
warn "the following need an AUR helper (yay/paru) or manual install: ${AUR_ONLY[*]}"
warn "your config will still work without them — those filetypes just won't get LSP support until installed"

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
    warn "AUR-only, install manually if you need them: ${SKIPPED[*]}"
fi
echo
echo "Open nvim, restart it once fully, and check :Lazy and :checkhealth."

if [ ${#FAILED[@]} -eq 0 ]; then
    exit 0
else
    exit 1
fi
