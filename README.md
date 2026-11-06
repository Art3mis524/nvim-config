# nvim-config

My personal Neovim configuration. Built around native LSP (`vim.lsp.config`/`vim.lsp.enable`,
no `nvim-lspconfig`), `lazy.nvim` for plugins, and my own colorscheme,
[`cyberpunk`](https://github.com/Art3mis524/cyberpunk). Needs Neovim 0.12+.

## Quick start on a new machine

**Arch-based Linux:**

```sh
git clone https://github.com/Art3mis524/nvim-config.git ~/.config/nvim
cd ~/.config/nvim
./install.sh
# open a new terminal so the PATH changes take effect, then:
nvim
```

**macOS:**

```sh
git clone https://github.com/Art3mis524/nvim-config.git ~/.config/nvim
cd ~/.config/nvim
./install-macos.sh
# open a new terminal so the PATH changes take effect, then:
nvim
```

**Windows** (PowerShell, not as admin; **not yet tested on a Windows machine**, see
[below](#install-windowsps1-windows)):

```powershell
git clone https://github.com/Art3mis524/nvim-config.git $env:USERPROFILE\nvim-config
cd $env:USERPROFILE\nvim-config
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
# open a new terminal so the PATH changes take effect, then:
nvim
```

(No git yet? Download the repo as a zip from GitHub instead; the script installs git.)

Each script handles system packages, language servers, plugins and the global
`.clang-format`; see [Install scripts](#install-scripts) for exactly what each covers. On
any other distro/OS, install the equivalent packages manually, then just run `nvim`
(`lazy.nvim` bootstraps itself and reads `lazy-lock.json` for exact plugin versions).
Afterwards, [`tests/smoke.lua`](#smoke-test) checks the machine is fully set up.

## Layout

```text
init.lua                 loads the modules below, in order
lua/config/
  options.lua            editor options, clipboard (OSC 52 over SSH)
  keybinds.lua           leader key and global keymaps
  lazy.lua               lazy.nvim bootstrap, pinned to lazy-lock.json
  lsp.lua                what all servers share: diagnostics, keymaps, format on save
  jdtls.lua              client-side extras for Java (jdt:// files)
  parsers.lua            treesitter parsers to keep installed
lsp/<server>.lua         one file per language server, all enabled automatically
lua/plugins/<area>.lua   plugin specs, grouped by purpose (ui, completion, git, ...)
after/ftplugin/          per-filetype settings (2-space indent for html/json/jsonc)
after/queries/cpp/       treesitter query override (C++ casts as keywords)
scripts/                 install steps shared by the three install scripts
tests/smoke.lua          checks that a machine is set up
```

To add a language server, add `lsp/<name>.lua` returning its config (copying from
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig/tree/master/lsp) is the easy
way), and install its binary in the install scripts.

## Leader key

`<Space>`

## Keybinds

### General

| Key | Mode | Action |
|---|---|---|
| `<leader>e` | n | Open netrw file explorer (`:Ex`) |
| `Ctrl-\` | n | Toggle a docked terminal (right side, ~40% width) |
| `<leader>lr` | n (LSP buffers) | Restart the LSP client(s) attached to the current buffer (`:lsp restart`) |

### Finding things (Telescope)

| Key | Action |
|---|---|
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Find open buffers |
| `<leader>fh` | Help tags |
| `<leader>ft` | Browse colorschemes with live preview |

Telescope uses the native fzf sorter, so the query understands fzf syntax (`'exact`,
`^prefix`, `suffix$`, `!not`).

### LSP (active only on buffers with an attached language server)

| Key | Action |
|---|---|
| `K` | Hover docs |
| `gd` / `gD` | Go to definition / declaration |
| `gi` | Go to implementation |
| `go` | Go to type definition |
| `gr` | Find references (fires immediately, without waiting on Neovim's `grn`/`grr`/... defaults) |
| `gs` | Signature help (also shown automatically while typing via `lsp_signature.nvim`) |
| `gl` | Open diagnostic float for the current line |
| `<F2>` / `<leader>rn` | Rename symbol |
| `<F3>` / `<leader>f` | Format buffer |
| `<F4>` / `<leader>ca` | Code actions for the whole current line, not just the exact cursor column |

### REST client (`hurl.nvim`, only in `.hurl` files)

| Key | Mode | Action |
|---|---|---|
| `<leader>ha` | n | Run the request under the cursor; the response opens in a split (`q` closes it) |
| `<leader>ha` | v | Run the selected requests |
| `<leader>hA` | n | Run every request in the file |
| `<leader>hv` | n | Run the request under the cursor in verbose mode (full headers, timings) |
| `<leader>hl` | n | Show the last response again |
| `<leader>hm` | n | Toggle responses between a split and a popup |

### Markdown

| Key | Action |
|---|---|
| `<leader>p` | Toggle between rendered and raw markdown (`render-markdown.nvim`) |

### Multi-cursor (`multicursor.nvim`)

| Key | Action |
|---|---|
| `Ctrl-n` | Select word under cursor; repeat to add the next matching occurrence as another cursor |
| `Ctrl-Down` / `Ctrl-Up` | Add a cursor directly below/above |
| `Ctrl-LeftMouse` | Add a cursor where you click (drag to add several) |
| `Ctrl-q` | Add/remove a cursor at the current position |
| `Esc` | Exit multi-cursor mode |

### Editor basics worth knowing (built into Vim, not this config)

| Key | Action |
|---|---|
| `diw` | Delete the word under the cursor |
| `cgn` then `.` | Change next search match, repeat with `.` for the rest |
| `Ctrl-o` / `Ctrl-i` | Jump back / forward through cursor history |
| `n` / `N` | Next / previous search match |
| `:noh` | Clear search highlight |
| `Ctrl-r` | Redo |

## Languages with LSP configured

C/C++ (`clangd`), Lua (`luals`), HTML (`html`), CSS/SCSS/Less (`cssls`), PHP (`phpls`), JS/JSX/TS/TSX (`ts_ls`),
Zig (`zls`), Nix (`nil_ls`), Rust (`rust_analyzer`), CMake (`cmake`), GLSL (`glsl_analyzer`),
C3 (`c3lsp`), D (`serve_d`), JSON/JSONC (`jsonls`), Tailwind (`tailwindcss`), ESLint (`eslint`),
Haskell (`hls`), Go (`gopls`), templ (`templ`), Java (`jdtls`).

Format-on-save is enabled for every language except C and PHP (C++ is included, see
[Formatting](#formatting-clang-format) below).

Indentation is 4 spaces everywhere (`lua/config/options.lua`) except HTML and JSON/JSONC,
which use 2 (`after/ftplugin/html.lua`, `json.lua`, `jsonc.lua`). The formatters follow the
buffer's setting, so saving re-indents a file to match, including existing files written
with a different width. A project's `.editorconfig` overrides both. (Neovim's own SCSS
settings use 2.)

**Java notes:** `jdtls` is configured natively (no `nvim-jdtls` plugin). It finds the
project root from `mvnw`/`gradlew`/`settings.gradle`/`.git` first, then
`pom.xml`/`build.gradle`, and keeps each project's index in its own directory under
`~/.cache/nvim/jdtls/`. Delete a project's folder there if jdtls gets confused about it.
`gd` on a JDK or library class (e.g. `String`) opens its source, or a decompiled version
when the jar has none, in a read-only buffer. The first open of a project is slow while
jdtls imports and indexes it. Formatting uses jdtls's built-in Eclipse formatter with
4-space indentation.

## Formatting (clang-format)

C/C++ formatting uses `clang-format`, configured via `.clang-format` files:

- `~/.clang-format` (installed by the install scripts from `assets/clang-format-global`)
  is the default for any C/C++ project under your home directory, since clang-format
  walks up parent directories looking for the nearest `.clang-format`.
- A project can override it with its own `.clang-format` closer to the source files.

Current style: Allman braces, namespace contents indented, 120-column limit, one
parameter per line once a signature doesn't fit, 4-space indentation, inline
class-body functions collapse to one line but out-of-line definitions never do.

`static_cast`/`reinterpret_cast`/`const_cast`/`dynamic_cast` are styled as keywords
(bold, matching `if`/`throw`/etc.) rather than the function-call color the C++ grammar
would otherwise give them, via a treesitter query override at
`after/queries/cpp/highlights.scm`.

## Theme

Active colorscheme: [`cyberpunk`](https://github.com/Art3mis524/cyberpunk), in its
`cyberpunkNeon` style, with its own lualine theme for the statusline. The install scripts
always pull its latest commit rather than the one pinned in `lazy-lock.json`, so
re-running a script picks up theme changes; in an open nvim, `:Lazy update cyberpunk`
does the same. Switch to the calmer style any time with `:colorscheme cyberpunk`.

`<leader>ft` browses every installed colorscheme with live preview. The extras in
`lua/plugins/colorscheme.lua` are only there for comparison: they stay unloaded until
previewed or picked.

## Clipboard

Yanks and puts use the system clipboard (`clipboard=unnamedplus`, through `wl-clipboard`
on Wayland). Over SSH there's no clipboard tool, so yanks are sent to your local
terminal's clipboard with OSC 52 instead, and `p` pastes from Neovim's own register
(paste from the local clipboard with the terminal's paste key).

## Plugins

| Plugin | Purpose | Spec |
|---|---|---|
| `Art3mis524/cyberpunk` | Active colorscheme | `colorscheme.lua` |
| `nvim-lualine/lualine.nvim` | Statusline | `ui.lua` |
| `folke/which-key.nvim` | Keybind hints | `ui.lua` |
| `lukas-reineke/indent-blankline.nvim` | Indent guides | `ui.lua` |
| `brenoprata10/nvim-highlight-colors` | Inline color previews for hex codes etc. | `ui.lua` |
| `hrsh7th/nvim-cmp` + `cmp-nvim-lsp`/`cmp-buffer`/`cmp-path` | Autocomplete | `completion.lua` |
| `L3MON4D3/LuaSnip` + `cmp_luasnip` | Snippets | `completion.lua` |
| `ray-x/lsp_signature.nvim` | Live parameter hints while typing a call | `completion.lua` |
| `nvim-telescope/telescope.nvim` + `telescope-fzf-native.nvim` | Fuzzy finder | `telescope.lua` |
| `nvim-treesitter/nvim-treesitter` | Syntax highlighting/parsing | `treesitter.lua` |
| `tpope/vim-fugitive` | Git commands | `git.lua` |
| `lewis6991/gitsigns.nvim` | Git change markers in the sign column | `git.lua` |
| `folke/ts-comments.nvim` | Treesitter-aware `gc`/`gcc` comment toggling | `editing.lua` |
| `jake-stewart/multicursor.nvim` | Multiple cursors | `editing.lua` |
| `akinsho/toggleterm.nvim` | Docked terminal (`Ctrl-\`) | `terminal.lua` |
| `MeanderingProgrammer/render-markdown.nvim` | Rendered markdown in the buffer | `markdown.lua` |
| `jellydn/hurl.nvim` | REST client: run HTTP requests from `.hurl` files (see below) | `hurl.lua` |
| `m4xshen/hardtime.nvim` | Nudges away from inefficient motions | `practice.lua` |
| `ThePrimeagen/vim-be-good` | Vim motion practice game | `practice.lua` |

## REST client (hurl)

Write requests in a `.hurl` file, put the cursor on one and press `<leader>ha`:

```hurl
GET http://localhost:3000/users/1

POST http://localhost:3000/users
Content-Type: application/json
{
    "name": "Josh"
}
```

The response (status, headers, and the body pretty-printed by `jq`) opens in a split.
Shared values go in a `vars.env` file next to it (`base_url=http://localhost:3000`) and
are used as `{{base_url}}`. Checks (`HTTP 200`, `[Asserts]`) and captures for chaining
requests are optional; see the [Hurl docs](https://hurl.dev). The same file also runs
outside Neovim with `hurl --test file.hurl`.

## Install scripts

All three scripts are safe to re-run: every step checks before acting, so running one
again after adding a language server just fills in whatever's newly missing. They share
their common steps through `scripts/`:

- `scripts/npm-packages.txt`: the npm language servers and tools, for all three scripts
- `scripts/sync-plugins.lua` and `scripts/check-parsers.lua`: the headless Neovim steps
  (plugins at their lockfile versions, then a check that every treesitter parser is in)
- `scripts/lib.sh`: the bash helpers `install.sh` and `install-macos.sh` share

### `install.sh` (Arch-based Linux)

Run it as your normal user from inside a clone of this repo, wherever that is: if the
clone isn't at `~/.config/nvim` it gets symlinked there (any existing config there is
moved to `~/.config/nvim.bak-<timestamp>` first). It calls `sudo` itself only for the
pacman step, which runs `pacman -Syu` (Arch doesn't support installing packages against
a stale database), so it also brings the rest of the system up to date. PATH additions
(`~/.local/bin`, Go's `$GOPATH/bin`) are appended to your login shell's profile
(`~/.zprofile`, `~/.bash_profile`, `~/.config/fish/conf.d/nvim-config.fish` for fish, or
`~/.profile`) if not already present, so open a new terminal after running it.

`./install.sh --check` installs nothing: it verifies that every pacman, AUR and npm
package name and every download URL the script uses still exists, and exits non-zero if
any doesn't.

**What it installs:**

- **Core (pacman):** git, base-devel, neovim, ripgrep, fd, unzip, curl, wget, cmake,
  tree-sitter-cli, clang (clangd + clang-format + clang-tidy), rust (skipped if `rustup`
  is present), rust-analyzer, go, gopls, lua-language-server, nodejs, npm, python,
  python-pipx, zls, haskell-language-server, jdk-openjdk, hurl, jq, wl-clipboard, xclip,
  a Nerd Font (Hermit Nerd)
- **npm (global):** everything in `scripts/npm-packages.txt`: typescript,
  typescript-language-server, intelephense, vscode-langservers-extracted,
  @tailwindcss/language-server, prettier and pnpm (`typescript` is pinned to 6.x: 7.x is
  the native rewrite and has no `tsserver.js` for `ts_ls` to fall back on). If npm's
  global prefix isn't writable (Arch's default is `/usr`), it's set to `~/.local` so no
  sudo is needed.
- **pipx:** cmake-language-server
- **go install:** templ
- **GitHub release binaries into `~/.local/bin`:** `glsl_analyzer` and `alejandra`
  (x86_64 and aarch64), `c3lsp` and `serve-d` (x86_64 only)
- **`nil`**, from nixpkgs if `nix` is installed, otherwise `nil-git` from the AUR if
  `paru` or `yay` is installed, otherwise skipped
- **`jdtls`** (Java), from the AUR if `paru` or `yay` is installed, otherwise the
  upstream build unpacked into `~/.local/share/jdtls` and linked into `~/.local/bin`.
  It needs Java 21+, so the script warns if the default JDK (`archlinux-java`) is older
- **Copies `assets/clang-format-global` to `~/.clang-format`**
- **Installs every plugin at the version pinned in `lazy-lock.json`** (`Lazy! restore`),
  except the `cyberpunk` theme, which is updated to its latest commit; builds LuaSnip's
  `jsregexp`, installs the treesitter parsers listed in `lua/config/parsers.lua`, and
  checks that none are missing

On WSL it also reminds you to install the Nerd Font on the Windows side, since
Windows Terminal doesn't use fonts installed inside WSL.

The script exits non-zero and lists anything that failed in its summary.

### `install-macos.sh` (macOS)

Run it from inside a clone of this repo, wherever that is: if the clone isn't at
`~/.config/nvim` it gets symlinked there (any existing config there is moved to
`~/.config/nvim.bak-<timestamp>` first). Installs Xcode Command Line Tools and Homebrew
itself if either is missing (Xcode's installer is a GUI prompt; the script tells you to
re-run once it finishes). Homebrew's `shellenv` and the PATH additions it needs (`llvm`'s
keg-only bin dir for `clangd`, `openjdk`'s for `java`, Go's `$GOPATH/bin` for `templ`,
`~/.local/bin` for the servers below) get appended to `~/.zprofile` if not already
present, so open a new terminal after running it.

**What it installs:**

- **Core (Homebrew):** git, neovim, ripgrep, fd, unzip, wget, cmake, tree-sitter-cli,
  alejandra, llvm (for clangd), clang-format, rust, rust-analyzer, go, gopls,
  lua-language-server, node, python@3.13, zls, haskell-language-server,
  cmake-language-server, openjdk, jdtls, hurl, jq
- **Cask:** font-hurmit-nerd-font (Hermit; Nerd Fonts publishes it as "Hurmit")
- **npm (global):** `scripts/npm-packages.txt`, same as `install.sh`
- **go install:** templ
- **GitHub release binaries into `~/.local/bin`:** `glsl_analyzer`, `c3lsp` (Apple
  Silicon only), `serve-d` (Intel build; runs under Rosetta on Apple Silicon)
- **`nil`**, from nixpkgs, only if `nix` is installed (it can't be built without it)
- **Copies `assets/clang-format-global` to `~/.clang-format`**
- **Plugins and treesitter parsers**, the same as `install.sh`

No clipboard package is needed: macOS's built-in `pbcopy`/`pbpaste` work with
`unnamedplus` out of the box.

### `install-windows.ps1` (Windows)

> **Untested on Windows.** It has had no complete end-to-end run on real Windows yet,
> so expect rough edges and please report what breaks. It's kept to plain ASCII and
> Windows PowerShell 5.1 syntax, since a fresh Windows only has 5.1.

Run it in a normal (non-admin) PowerShell from inside a clone of this repo: the clone is
linked to `%LOCALAPPDATA%\nvim` with a directory junction (no admin or Developer Mode
needed), and an existing config there is moved to `nvim.bak-<timestamp>` first. It sets
the current user's execution policy to `RemoteSigned` (so Scoop's shims run), installs
Scoop if missing, and adds `~\.local\bin` and Go's `bin` dir to the user PATH, so open a
new terminal after running it.

**What it installs:**

- **Core (Scoop):** git, neovim, ripgrep, fd, cmake, make, mingw (gcc, used to compile
  treesitter parsers, telescope-fzf-native and LuaSnip's jsregexp), tree-sitter, llvm
  (clangd + clang-format), rustup-gnu (Rust via the GNU toolchain, so no Visual Studio),
  rust-analyzer, go, lua-language-server, nodejs-lts, uv, python (jdtls's launcher is
  a Python script), zls, jdtls, hurl, jq
- **Scoop `java` bucket:** temurin-lts-jdk (sets `JAVA_HOME`; jdtls needs Java 21+)
- **Scoop `nerd-fonts` bucket:** Hermit-NF (per-user, no admin)
- **npm (global):** `scripts/npm-packages.txt`, same as the other scripts
- **uv tool:** cmake-language-server (uv fetches its own Python, so no Python installer
  is needed)
- **go install:** gopls, templ
- **GitHub release binaries into `~\.local\bin`:** `glsl_analyzer`, `c3lsp`, `serve-d`
- **Copies `assets/clang-format-global` to `~\.clang-format`**
- **Plugins and treesitter parsers**, the same as the other scripts

**Not installed:** `nil` and `alejandra` (no Windows builds) and
`haskell-language-server` (install it with [GHCup](https://www.haskell.org/ghcup/) if you
need it).

On ARM64 Windows it installs x64 builds of everything (they run under emulation): mingw
only exists for x64, and the parsers and plugin libraries it compiles must match
Neovim's architecture to load.

Windows-specific bits in the config itself: toggleterm opens PowerShell instead of
`cmd.exe`, treesitter compiles with `gcc` when MSVC isn't installed, and clangd's
`--query-driver` uses whichever compilers are on PATH.

## Smoke test

`tests/smoke.lua` checks that a machine is actually set up, on any OS:

- no startup errors; `cyberpunkNeon` active with the cyberpunk lualine theme; the
  browse-only themes unloaded but loadable with `:colorscheme`
- every plugin installed, telescope-fzf-native and jsregexp built, telescope using the
  fzf sorter
- every treesitter parser installed and loadable; 2-space indentation for html/json/jsonc
  and 4 elsewhere
- one enabled server per `lsp/*.lua` file, each with its command on PATH, and `luals`,
  `ts_ls`, `clangd`, `gopls` and `jdtls` really attaching to a sample file (jdtls gets
  up to 90 seconds, since it starts a JVM), with this config's keymaps
- `hurl` and `jq` on PATH, and `<leader>ha` in a sample `.hurl` file sending a real
  request to a tiny local server it starts (so no network is needed) and showing the
  formatted response
- `prettier` and `pnpm` running, render-markdown.nvim rendering a sample `README.md`
  with long lines wrapping between words, and yanks using OSC 52 over SSH

```sh
nvim --headless "+luafile tests/smoke.lua"
# servers you don't expect on this machine can be skipped:
SMOKE_SKIP_SERVERS=nil_ls,hls nvim --headless "+luafile tests/smoke.lua"
```

It prints one line per check and exits non-zero if any fail.
