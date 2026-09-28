#!/usr/bin/env bash
#
# Arch Linux counterpart to install-macos.sh. Sets up a fresh Arch-based
# machine to use this Neovim config: system packages, language servers,
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

if [ "$(uname -s)" != "Linux" ] || ! command -v pacman >/dev/null 2>&1; then
    echo "This script only supports Arch-based Linux (pacman not found)." >&2
    echo "Use install-macos.sh on macOS, or see README.md for the manual package list." >&2
    exit 1
fi

if [ "$EUID" -eq 0 ]; then
    echo "Run this as your normal user, not root — it calls sudo itself for pacman." >&2
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/init.lua" ]; then
    echo "Run this from inside the cloned nvim config (expected init.lua next to install.sh)." >&2
    exit 1
fi

# PATH additions go in the login-shell profile, matching whichever shell the
# user actually logs in with.
case "$(basename "${SHELL:-bash}")" in
    zsh)  PROFILE="$HOME/.zprofile" ;;
    bash) PROFILE="$HOME/.bash_profile" ;;
    *)    PROFILE="$HOME/.profile" ;;
esac

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
note "Installing core packages (pacman)"
# ---------------------------------------------------------------------------
CORE_PKGS=(
    git base-devel neovim ripgrep fd unzip curl wget cmake
    tree-sitter-cli  # nvim-treesitter needs it to build parsers
    clang            # clangd + clang-format + clang-tidy
    rust-analyzer
    go gopls
    lua-language-server
    nodejs npm
    python python-pipx
    zls
    haskell-language-server
    jdk-openjdk      # JDK; jdtls needs Java 21+ to run
    wl-clipboard xclip
    otf-hermit-nerd
)
# The rust package conflicts with rustup; if rustup manages the toolchain,
# leave it alone and just make sure rustfmt is there.
if command -v rustup >/dev/null 2>&1; then
    rustup component add rustfmt >/dev/null 2>&1 || warn "rustup: could not add rustfmt"
    ok "rustup found, using its toolchain instead of the rust package"
else
    CORE_PKGS+=(rust)
fi
# -Syu rather than -S: installing against a stale package database is a
# partial upgrade, which Arch doesn't support.
if sudo pacman -Syu --needed --noconfirm "${CORE_PKGS[@]}"; then
    ok "core packages installed"
else
    warn "one or more core packages failed to install — check output above"
    FAILED+=("core pacman packages")
fi

# ~/.local/bin holds npm globals, pipx apps and the release binaries below.
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
append_once "export PATH=\"$LOCAL_BIN:\$PATH\"" "$PROFILE"
export PATH="$LOCAL_BIN:$PATH"

# ---------------------------------------------------------------------------
note "Installing npm-based language servers"
# ---------------------------------------------------------------------------
if command -v npm >/dev/null 2>&1; then
    # Arch's npm prefix is /usr, so plain `npm install -g` needs root. Point
    # it at ~/.local instead so globals land in ~/.local/bin.
    if [ ! -w "$(npm config get prefix)" ]; then
        npm config set prefix "$HOME/.local"
        ok "npm global prefix set to ~/.local"
    fi
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
note "Installing cmake-language-server (pipx)"
# ---------------------------------------------------------------------------
if command -v pipx >/dev/null 2>&1; then
    if command -v cmake-language-server >/dev/null 2>&1 \
        || pipx install cmake-language-server >/dev/null 2>&1; then
        ok "cmake-language-server"
    else
        warn "cmake-language-server failed to install via pipx"
        FAILED+=("cmake-language-server")
    fi
else
    warn "pipx not found, skipping cmake-language-server"
    FAILED+=("cmake-language-server (pipx missing)")
fi

# ---------------------------------------------------------------------------
note "Installing templ (go install)"
# ---------------------------------------------------------------------------
if command -v go >/dev/null 2>&1; then
    if go install github.com/a-h/templ/cmd/templ@latest >/dev/null 2>&1; then
        GOBIN="$(go env GOPATH)/bin"
        append_once "export PATH=\"$GOBIN:\$PATH\"" "$PROFILE"
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
note "Installing tools not in the official repos (into ~/.local/bin)"
# ---------------------------------------------------------------------------
ARCH="$(uname -m)"
TMP_DL="$(mktemp -d)"
trap 'rm -rf "$TMP_DL"' EXIT

# Downloads a GitHub release asset and installs one binary from it into
# ~/.local/bin. Args: binary name, asset URL, binary's path inside the
# archive (omit when the asset is the binary itself).
install_release_bin() {
    local name="$1" url="$2" inner="${3:-}" dir="$TMP_DL/$1"
    mkdir -p "$dir"
    curl -fsSL -o "$dir/archive" "$url" || return 1
    if [ -z "$inner" ]; then
        install -m 755 "$dir/archive" "$LOCAL_BIN/$name"
        return
    fi
    case "$url" in
        *.zip) unzip -qo "$dir/archive" -d "$dir" ;;
        *)     tar -xzf "$dir/archive" -C "$dir" ;;
    esac || return 1
    install -m 755 "$dir/$inner" "$LOCAL_BIN/$name"
}

# glsl_analyzer: prebuilt for x86_64 and aarch64.
if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "aarch64" ]; then
    if install_release_bin glsl_analyzer \
            "https://github.com/nolanderc/glsl_analyzer/releases/latest/download/$ARCH-linux-musl.zip" \
            "bin/glsl_analyzer"; then
        ok "glsl_analyzer"
    else
        warn "glsl_analyzer failed to download"
        FAILED+=("glsl_analyzer")
    fi
else
    warn "glsl_analyzer has no $ARCH build, skipping"
    SKIPPED+=("glsl_analyzer (no $ARCH build)")
fi

# alejandra: Nix formatter used by nil. Static binaries for x86_64 and aarch64.
if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "aarch64" ]; then
    if install_release_bin alejandra \
            "https://github.com/kamadorueda/alejandra/releases/latest/download/alejandra-$ARCH-unknown-linux-musl"; then
        ok "alejandra"
    else
        warn "alejandra failed to download"
        FAILED+=("alejandra")
    fi
else
    warn "alejandra has no $ARCH build, skipping"
    SKIPPED+=("alejandra (no $ARCH build)")
fi

# c3lsp and serve-d: only published for x86_64 Linux.
if [ "$ARCH" = "x86_64" ]; then
    if install_release_bin c3lsp \
            "https://github.com/pherrymason/c3-lsp/releases/latest/download/c3lsp-linux-amd64.tar.gz" \
            "server/bin/release/c3lsp"; then
        ok "c3lsp"
    else
        warn "c3lsp failed to download"
        FAILED+=("c3lsp")
    fi

    SERVE_D_TAG="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/Pure-D/serve-d/releases/latest)"
    SERVE_D_VER="${SERVE_D_TAG##*/v}"
    if install_release_bin serve-d \
            "https://github.com/Pure-D/serve-d/releases/download/v$SERVE_D_VER/serve-d_$SERVE_D_VER-linux-x86_64.tar.gz" \
            "serve-d"; then
        ok "serve-d $SERVE_D_VER"
    else
        warn "serve-d failed to download"
        FAILED+=("serve-d")
    fi
else
    warn "c3lsp and serve-d have no $ARCH Linux build, skipping"
    SKIPPED+=("c3lsp (no $ARCH build)" "serve-d (no $ARCH build)")
fi

# nil: Nix language server. No release binaries and not in the official
# repos, so use nix if present, otherwise an AUR helper if one is installed.
AUR_HELPER=""
for h in paru yay; do
    if command -v "$h" >/dev/null 2>&1; then AUR_HELPER="$h"; break; fi
done
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
        ok "nil (nil-git from the AUR via $AUR_HELPER)"
    else
        warn "nil failed to install from the AUR"
        FAILED+=("nil")
    fi
else
    warn "neither nix nor an AUR helper found, skipping nil (only needed for editing .nix files)"
    SKIPPED+=("nil (needs nix or an AUR helper)")
fi

# jdtls: Java language server, only in the AUR. Without an AUR helper, fall
# back to the upstream build, unpacked into ~/.local/share/jdtls and linked
# into ~/.local/bin (its launcher resolves the symlink to find its files).
if command -v jdtls >/dev/null 2>&1; then
    ok "jdtls (already installed)"
elif [ -n "$AUR_HELPER" ]; then
    if "$AUR_HELPER" -S --needed --noconfirm jdtls; then
        ok "jdtls (from the AUR via $AUR_HELPER)"
    else
        warn "jdtls failed to install from the AUR"
        FAILED+=("jdtls")
    fi
else
    JDTLS_DIR="$HOME/.local/share/jdtls"
    mkdir -p "$TMP_DL/jdtls"
    if curl -fsSL -o "$TMP_DL/jdtls.tar.gz" \
            https://download.eclipse.org/jdtls/snapshots/jdt-language-server-latest.tar.gz \
        && tar -xzf "$TMP_DL/jdtls.tar.gz" -C "$TMP_DL/jdtls"; then
        rm -rf "$JDTLS_DIR"
        mv "$TMP_DL/jdtls" "$JDTLS_DIR"
        ln -sf "$JDTLS_DIR/bin/jdtls" "$LOCAL_BIN/jdtls"
        ok "jdtls (upstream build in $JDTLS_DIR)"
    else
        warn "jdtls failed to download"
        FAILED+=("jdtls")
    fi
fi
# jdtls refuses to start on Java older than 21, and archlinux-java may still
# point at an older JDK if one was installed before.
JAVA_MAJOR="$(java -version 2>&1 | sed -n 's/.*version "\([0-9]*\).*/\1/p' | head -1)"
if [ -n "$JAVA_MAJOR" ] && [ "$JAVA_MAJOR" -lt 21 ]; then
    warn "default java is $JAVA_MAJOR, jdtls needs 21+: pick a newer one from 'archlinux-java status' with 'sudo archlinux-java set <name>'"
    FAILED+=("java 21+ as default JDK")
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
    # a fresh machine matches the tested setup. The cyberpunk theme is the
    # exception: it's my own, so it's then updated to its latest commit.
    # Headless nvim exits 0 even if :Lazy doesn't exist, so fail explicitly
    # when lazy.nvim never loaded.
    if nvim --headless "+lua if not package.loaded['lazy'] then vim.cmd('cquit 1') end" \
            "+Lazy! restore" "+Lazy! update cyberpunk" "+Lazy! build LuaSnip" +qa >"$SYNC_LOG" 2>&1; then
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
echo "Open a new terminal (so the PATH changes in $PROFILE take effect) and"
echo "nvim is ready to use. Set your terminal's font to Hurmit Nerd Font Mono"
echo "if it isn't already, so icons render."
if grep -qi microsoft /proc/version 2>/dev/null; then
    echo
    echo "WSL detected: install the Nerd Font on the Windows side and select it in"
    echo "Windows Terminal (the font installed inside WSL isn't used there), and keep"
    echo "projects under ~ rather than /mnt/c for usable LSP and search speed."
fi

if [ ${#FAILED[@]} -eq 0 ]; then
    exit 0
else
    exit 1
fi
