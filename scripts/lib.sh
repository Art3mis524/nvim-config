# Helpers shared by install.sh (Arch) and install-macos.sh. Source it after
# setting SCRIPT_DIR (the repo root) and PROFILE (the login shell's profile
# file, which add_to_path writes to).
# shellcheck shell=bash

FAILED=()   # reported in the summary; any entry makes the script exit 1
SKIPPED=()  # reported, but not a failure

note() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
ok()   { printf '\033[1;32m  ok:\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m  warn:\033[0m %s\n' "$1"; }

LOCAL_BIN="$HOME/.local/bin" # npm globals, pipx apps and release binaries
TMP_DL="$(mktemp -d)"
trap 'rm -rf "$TMP_DL"' EXIT

# Prints a list file's entries, dropping # comments and blank lines.
read_list() {
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"
}

# Appends a line to a file unless it's already there.
append_once() {
    local line="$1" file="$2"
    mkdir -p "$(dirname "$file")"
    touch "$file"
    grep -qxF "$line" "$file" || echo "$line" >>"$file"
}

# Puts a directory on PATH now and, via $PROFILE, for future shells. Paths
# under $HOME are written with a literal $HOME so the profile isn't tied to
# one user name.
add_to_path() {
    local dir="$1" portable="$1"
    case "$dir" in "$HOME"/*) portable="\$HOME${dir#"$HOME"}" ;; esac
    case "$PROFILE" in
        *.fish) append_once "fish_add_path -g \"$portable\"" "$PROFILE" ;;
        *) append_once "export PATH=\"$portable:\$PATH\"" "$PROFILE" ;;
    esac
    export PATH="$dir:$PATH"
}

# Symlinks the repo to ~/.config/nvim unless it's already there, moving any
# existing config aside first.
link_config() {
    note "Linking config into place"
    local target="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
    if [ "$(cd "$target" 2>/dev/null && pwd -P)" = "$(cd "$SCRIPT_DIR" && pwd -P)" ]; then
        ok "already in place"
        return
    fi
    if [ -e "$target" ] || [ -L "$target" ]; then
        local backup
        backup="$target.bak-$(date +%Y%m%d-%H%M%S)"
        mv "$target" "$backup"
        warn "moved existing config to $backup"
    fi
    mkdir -p "$(dirname "$target")"
    ln -s "$SCRIPT_DIR" "$target"
    ok "symlinked $target -> $SCRIPT_DIR"
}

install_npm_packages() {
    note "Installing npm packages"
    if ! command -v npm >/dev/null 2>&1; then
        warn "npm not found, skipping npm packages"
        FAILED+=("npm packages (npm missing)")
        return
    fi
    local pkg
    while read -r pkg; do
        # npm 12+ skips install scripts unless allowed. pnpm's swaps its
        # placeholder launcher for the native binary; without it, anything
        # that runs pnpm directly (not through a shell) fails with ENOEXEC.
        if npm install -g --allow-scripts=pnpm "$pkg" >/dev/null 2>&1; then
            ok "npm: $pkg"
        else
            warn "npm: $pkg failed to install"
            FAILED+=("npm package: $pkg")
        fi
    done < <(read_list "$SCRIPT_DIR/scripts/npm-packages.txt")
}

install_templ() {
    note "Installing templ (go install)"
    if ! command -v go >/dev/null 2>&1; then
        warn "go not found, skipping templ"
        FAILED+=("templ (go missing)")
    elif go install github.com/a-h/templ/cmd/templ@latest >/dev/null 2>&1; then
        add_to_path "$(go env GOPATH)/bin"
        ok "templ (installed to $(go env GOPATH)/bin, added to PATH)"
    else
        warn "templ failed to install"
        FAILED+=("templ")
    fi
}

# Downloads a release asset and installs one binary from it into
# ~/.local/bin. Args: binary name, asset URL, and the binary's path inside
# the archive (omit when the asset is the binary itself).
install_release_bin() {
    local name="$1" url="$2" inner="${3:-}" dir="$TMP_DL/$1"
    mkdir -p "$dir" "$LOCAL_BIN"
    curl -fsSL -o "$dir/archive" "$url" || return 1
    if [ -z "$inner" ]; then
        install -m 755 "$dir/archive" "$LOCAL_BIN/$name"
        return
    fi
    case "$url" in
        *.zip) unzip -qo "$dir/archive" -d "$dir" ;;
        *) tar -xzf "$dir/archive" -C "$dir" ;;
    esac || return 1
    install -m 755 "$dir/$inner" "$LOCAL_BIN/$name"
}

# install_release_bin plus reporting. Same args.
release_bin() {
    if install_release_bin "$@"; then
        ok "$1"
    else
        warn "$1 failed to download"
        FAILED+=("$1")
    fi
}

# serve-d's asset names contain the version, so look up the latest tag.
serve_d_version() {
    local tag
    tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/Pure-D/serve-d/releases/latest)"
    echo "${tag##*/v}"
}

install_clang_format() {
    note "Installing global .clang-format"
    if cp "$SCRIPT_DIR/assets/clang-format-global" "$HOME/.clang-format"; then
        ok "copied to ~/.clang-format"
    else
        warn "could not copy assets/clang-format-global"
        FAILED+=(".clang-format")
    fi
}

# Installs the plugins at their lockfile versions, then checks the
# treesitter parsers (starting nvim installs missing ones). Both steps are
# Lua scripts in scripts/, shared with install-windows.ps1.
sync_nvim() {
    note "Installing Neovim plugins and treesitter parsers"
    local log="${TMPDIR:-/tmp}/nvim-install-sync.log" missing
    if ! command -v nvim >/dev/null 2>&1; then
        warn "nvim not found even after package install, something went wrong above"
        FAILED+=("nvim itself")
        return
    fi
    if nvim --headless "+lua dofile(vim.fn.stdpath('config') .. '/scripts/sync-plugins.lua')" >"$log" 2>&1; then
        ok "plugins installed at lockfile versions"
    else
        warn "plugin install reported a problem, see $log"
        FAILED+=("lazy.nvim plugin install")
    fi
    if missing="$(nvim --headless "+lua dofile(vim.fn.stdpath('config') .. '/scripts/check-parsers.lua')" 2>>"$log")"; then
        ok "treesitter parsers installed"
    else
        warn "treesitter: ${missing:-parser check failed}, see $log"
        FAILED+=("treesitter parsers")
    fi
}

# Lists what failed or was skipped, prints the given closing lines, and
# exits 1 if anything failed. SUMMARY_OK is the all-clear message.
finish() {
    note "Summary"
    if [ ${#FAILED[@]} -eq 0 ]; then
        ok "${SUMMARY_OK:-Everything installed cleanly.}"
    else
        warn "These need attention:"
        printf '    - %s\n' "${FAILED[@]}"
    fi
    [ ${#SKIPPED[@]} -eq 0 ] || warn "Skipped: ${SKIPPED[*]}"
    echo
    printf '%s\n' "$@"
    [ ${#FAILED[@]} -eq 0 ] || exit 1
    exit 0
}
