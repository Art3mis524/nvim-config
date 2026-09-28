#!/usr/bin/env bash
#
# macOS counterpart to install.sh (which targets Arch/pacman). Sets up a
# fresh Mac to use this Neovim config: Homebrew, language servers,
# formatting tools, treesitter parsers, plugins and the global .clang-format.
#
# Run it from inside a clone of this repo. If the clone isn't at
# ~/.config/nvim, it gets symlinked there (an existing config is moved aside).
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
note "Linking config into place"
# ---------------------------------------------------------------------------
NVIM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
if [ "$(cd "$NVIM_CONFIG_DIR" 2>/dev/null && pwd -P)" = "$(cd "$SCRIPT_DIR" && pwd -P)" ]; then
    ok "already in place"
else
    if [ -e "$NVIM_CONFIG_DIR" ] || [ -L "$NVIM_CONFIG_DIR" ]; then
        BACKUP="$NVIM_CONFIG_DIR.bak-$(date +%Y%m%d-%H%M%S)"
        mv "$NVIM_CONFIG_DIR" "$BACKUP"
        warn "moved existing config to $BACKUP"
    fi
    mkdir -p "$(dirname "$NVIM_CONFIG_DIR")"
    ln -s "$SCRIPT_DIR" "$NVIM_CONFIG_DIR"
    ok "symlinked $NVIM_CONFIG_DIR -> $SCRIPT_DIR"
fi

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
    tree-sitter-cli  # nvim-treesitter needs it to build parsers
    alejandra        # Nix formatter used by nil
    llvm             # clangd (keg-only, PATH handled below)
    clang-format     # standalone, not keg-only
    rust rust-analyzer
    go gopls
    lua-language-server
    node
    python@3.13
    zls
    haskell-language-server
    openjdk          # JDK (keg-only, PATH handled below)
    jdtls            # Java language server; runs on openjdk even off PATH
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

# openjdk is keg-only too (macOS ships a /usr/bin/java stub that just asks
# you to install Java), so put the real java/javac first on PATH.
JDK_BIN="$(brew --prefix openjdk 2>/dev/null)/bin"
if [ -x "$JDK_BIN/java" ]; then
    export PATH="$JDK_BIN:$PATH"
    append_once "export PATH=\"$JDK_BIN:\$PATH\"" "$HOME/.zprofile"
    ok "added $JDK_BIN to PATH (java, javac)"
else
    warn "could not resolve openjdk's bin directory — java may not be on PATH"
    FAILED+=("java on PATH")
fi

# ---------------------------------------------------------------------------
note "Nerd Font (Hermit)"
# ---------------------------------------------------------------------------
if brew install --cask font-hurmit-nerd-font; then
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
        typescript@6 typescript-language-server  # 7.x has no tsserver.js; see ts_ls in lsp.lua
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
note "Installing cmake-language-server (brew)"
# ---------------------------------------------------------------------------
if brew install cmake-language-server >/dev/null 2>&1; then
    ok "cmake-language-server"
else
    warn "cmake-language-server failed to install via brew"
    FAILED+=("cmake-language-server")
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
note "Installing language servers not on Homebrew (into ~/.local/bin)"
# ---------------------------------------------------------------------------
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
append_once "export PATH=\"$LOCAL_BIN:\$PATH\"" "$HOME/.zprofile"
export PATH="$LOCAL_BIN:$PATH"
ARCH="$(uname -m)"
TMP_DL="$(mktemp -d)"
trap 'rm -rf "$TMP_DL"' EXIT

# Downloads a GitHub release archive and installs one binary from it into
# ~/.local/bin. Args: binary name, archive URL, binary's path inside archive.
install_release_bin() {
    local name="$1" url="$2" inner="$3" dir="$TMP_DL/$1"
    mkdir -p "$dir"
    curl -fsSL -o "$dir/archive" "$url" || return 1
    case "$url" in
        *.zip) unzip -qo "$dir/archive" -d "$dir" ;;
        *)     tar -xzf "$dir/archive" -C "$dir" ;;
    esac || return 1
    install -m 755 "$dir/$inner" "$LOCAL_BIN/$name"
}

# glsl_analyzer: prebuilt for both Apple Silicon and Intel.
if [ "$ARCH" = "arm64" ]; then GLSL_ASSET="aarch64-macos.zip"; else GLSL_ASSET="x86_64-macos.zip"; fi
if install_release_bin glsl_analyzer \
        "https://github.com/nolanderc/glsl_analyzer/releases/latest/download/$GLSL_ASSET" \
        "bin/glsl_analyzer"; then
    ok "glsl_analyzer"
else
    warn "glsl_analyzer failed to download"
    FAILED+=("glsl_analyzer")
fi

# c3lsp: only published for Apple Silicon.
if [ "$ARCH" = "arm64" ]; then
    if install_release_bin c3lsp \
            "https://github.com/pherrymason/c3-lsp/releases/latest/download/c3lsp-darwin-arm64.zip" \
            "server/bin/release/c3lsp"; then
        ok "c3lsp"
    else
        warn "c3lsp failed to download"
        FAILED+=("c3lsp")
    fi
else
    warn "c3lsp has no Intel Mac build, skipping"
    SKIPPED+=("c3lsp (no Intel build)")
fi

# serve-d: only published for Intel, so Apple Silicon runs it under Rosetta.
if [ "$ARCH" = "arm64" ] && ! arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    warn "serve-d needs Rosetta on Apple Silicon: run 'softwareupdate --install-rosetta --agree-to-license', then re-run"
    FAILED+=("serve-d (Rosetta missing)")
else
    SERVE_D_TAG="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/Pure-D/serve-d/releases/latest)"
    SERVE_D_VER="${SERVE_D_TAG##*/v}"
    if install_release_bin serve-d \
            "https://github.com/Pure-D/serve-d/releases/download/v$SERVE_D_VER/serve-d_$SERVE_D_VER-osx-x86_64.tar.gz" \
            "serve-d"; then
        ok "serve-d $SERVE_D_VER"
    else
        warn "serve-d failed to download"
        FAILED+=("serve-d")
    fi
fi

# nil: Nix language server. It has no macOS release binaries and needs nix
# itself to build, so it's only installed (from nixpkgs) when nix is present.
if command -v nix >/dev/null 2>&1; then
    if command -v nil >/dev/null 2>&1 \
        || nix --extra-experimental-features 'nix-command flakes' profile install nixpkgs#nil >/dev/null 2>&1; then
        ok "nil"
    else
        warn "nil failed to install from nixpkgs"
        FAILED+=("nil")
    fi
else
    warn "nix not installed, skipping nil (only needed for editing .nix files)"
    SKIPPED+=("nil (needs nix)")
fi

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
note "Installing Neovim plugins and treesitter parsers"
# ---------------------------------------------------------------------------
SYNC_LOG=/tmp/nvim-install-sync.log
if command -v nvim >/dev/null 2>&1; then
    # restore installs each plugin at the version pinned in lazy-lock.json, so
    # a fresh machine matches the tested setup. Headless nvim exits 0 even if
    # :Lazy doesn't exist, so fail explicitly when lazy.nvim never loaded.
    if nvim --headless "+lua if not package.loaded['lazy'] then vim.cmd('cquit 1') end" \
            "+Lazy! restore" "+Lazy! build LuaSnip" +qa >"$SYNC_LOG" 2>&1; then
        ok "plugins installed at lockfile versions"
    else
        warn "plugin install reported an issue — see $SYNC_LOG"
        FAILED+=("lazy.nvim plugin install")
    fi

    # The treesitter config installs missing parsers at startup (blocking when
    # headless), so one more start fills any gaps; then check none are missing.
    PARSER_CHECK="$TMP_DL/missing-parsers"
    nvim --headless "+lua local have = {}
        for _, p in ipairs(require('nvim-treesitter.config').get_installed()) do have[p] = true end
        local miss = {}
        for _, p in ipairs(require('config.parsers')) do if not have[p] then table.insert(miss, p) end end
        vim.fn.writefile({ table.concat(miss, ' ') }, '$PARSER_CHECK')" +qa >>"$SYNC_LOG" 2>&1
    if [ ! -f "$PARSER_CHECK" ]; then
        warn "could not check treesitter parsers — see $SYNC_LOG"
        FAILED+=("treesitter parser check")
    elif [ -n "$(cat "$PARSER_CHECK")" ]; then
        warn "treesitter parsers missing: $(cat "$PARSER_CHECK") — see $SYNC_LOG"
        FAILED+=("treesitter parsers: $(cat "$PARSER_CHECK")")
    else
        ok "treesitter parsers installed"
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
    warn "Skipped: ${SKIPPED[*]}"
fi
echo
echo "Open a new terminal (so the PATH changes in ~/.zprofile take effect) and"
echo "nvim is ready to use. Set your terminal's font to Hurmit Nerd Font Mono"
echo "if it isn't already, so icons render."

if [ ${#FAILED[@]} -eq 0 ]; then
    exit 0
else
    exit 1
fi
