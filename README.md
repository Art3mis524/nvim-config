# nvim-config

My personal Neovim configuration. Built around native LSP (`vim.lsp.config`/`vim.lsp.enable`,
no `nvim-lspconfig`), `lazy.nvim` for plugins, and a custom colorscheme
([`cyberpunk`](https://github.com/Art3mis524/cyberpunk)).

## Quick start on a new machine

**Arch-based Linux:**

```sh
git clone https://github.com/Art3mis524/nvim-config.git ~/.config/nvim
cd ~/.config/nvim
./install.sh
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

Both scripts handle system packages, language servers, and the global `.clang-format`.
See [Install scripts](#install-scripts) below for exactly what each does and doesn't cover.
On any other distro/OS, install the equivalent packages listed in that section manually,
then just run `nvim` (`lazy.nvim` bootstraps itself and reads `lazy-lock.json` for exact
plugin versions).

## Leader key

`<Space>`

## Keybinds

### General

| Key | Mode | Action |
|---|---|---|
| `<leader>e` | n | Open netrw file explorer (`:Ex`) |
| `Ctrl-\` | n | Toggle a docked terminal (right side, ~40% width) |
| `<leader>lr` | n (LSP buffers) | Restart the LSP client(s) attached to the current buffer |

### Finding things (Telescope)

| Key | Action |
|---|---|
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Find open buffers |
| `<leader>fh` | Help tags |
| `<leader>ft` | Browse colorschemes with live preview |

### LSP (active only on buffers with an attached language server)

| Key | Action |
|---|---|
| `K` | Hover docs |
| `gd` / `gD` | Go to definition / declaration |
| `gi` | Go to implementation |
| `go` | Go to type definition |
| `gr` | Find references |
| `gs` | Signature help (also shown automatically while typing via `lsp_signature.nvim`) |
| `gl` | Open diagnostic float for the current line |
| `<F2>` / `<leader>rn` | Rename symbol |
| `<F3>` / `<leader>f` | Format buffer |
| `<F4>` / `<leader>ca` | Code actions — checks the whole current line, not just the exact cursor column |

### Multi-cursor (`vim-visual-multi`)

| Key | Action |
|---|---|
| `Ctrl-n` | Select word under cursor; repeat to add the next matching occurrence as another cursor |
| `Ctrl-Down` / `Ctrl-Up` | Add a cursor directly below/above |
| `Ctrl-LeftMouse` | Add a cursor where you click |
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
| `-`/`:colorscheme <Tab>` | Not bound here — see `<leader>ft` above instead |

## Languages with LSP configured

C/C++ (`clangd`), Lua (`luals`), CSS/SCSS/Less (`cssls`), PHP (`phpls`), JS/JSX/TS/TSX (`ts_ls`),
Zig (`zls`), Nix (`nil_ls`), Rust (`rust_analyzer`), CMake (`cmake`), GLSL (`glsl_analyzer`),
C3 (`c3lsp`), D (`serve_d`), JSON/JSONC (`jsonls`), Tailwind (`tailwindcss`), ESLint (`eslint`),
Haskell (`hls`), Go (`gopls`), templ (`templ`).

Format-on-save is enabled for every language except C and PHP (C++ is included — see
[Formatting](#formatting-clang-format) below).

## Formatting (clang-format)

C/C++ formatting uses `clang-format`, configured via `.clang-format` files:

- `~/.clang-format` (installed by `install.sh` from `assets/clang-format-global`) —
  the default for any C/C++ project anywhere under your home directory, since
  clang-format walks up parent directories looking for the nearest `.clang-format`.
- A project can override it with its own `.clang-format` closer to the source files.

Current style: Allman braces, namespace contents indented, 120-column limit, one
parameter per line once a signature doesn't fit, 4-space indentation, inline
class-body functions collapse to one line but out-of-line definitions never do.

`static_cast`/`reinterpret_cast`/`const_cast`/`dynamic_cast` are styled as keywords
(bold, matching `if`/`throw`/etc.) rather than the function-call color the C++ grammar
would otherwise give them — via a treesitter query override at
`after/queries/cpp/highlights.scm`.

## Theme

Active colorscheme: [`cyberpunk`](https://github.com/Art3mis524/cyberpunk) (installed as
a normal plugin dependency), currently on the `cyberpunkNeon` style variant.
Switch to the calmer variant any time with `:colorscheme cyberpunk`, or browse everything
installed (several other themes are kept around purely for comparison) with `<leader>ft`.

## Plugins

| Plugin | Purpose |
|---|---|
| `Art3mis524/cyberpunk` | Active colorscheme |
| `nvim-lualine/lualine.nvim` | Statusline |
| `nvim-telescope/telescope.nvim` | Fuzzy finder |
| `nvim-treesitter/nvim-treesitter` | Syntax highlighting/parsing |
| `hrsh7th/nvim-cmp` + `cmp-nvim-lsp`/`cmp-buffer`/`cmp-path` | Autocomplete |
| `L3MON4D3/LuaSnip` + `cmp_luasnip` | Snippets |
| `ray-x/lsp_signature.nvim` | Live parameter hints while typing a call |
| `lewis6991/gitsigns.nvim` | Git change markers in the sign column |
| `tpope/vim-fugitive` | Git commands |
| `mg979/vim-visual-multi` | Multiple cursors |
| `akinsho/toggleterm.nvim` | Docked terminal (`Ctrl-\`) |
| `folke/ts-comments.nvim` | Treesitter-aware `gc`/`gcc` comment toggling |
| `folke/which-key.nvim` | Keybind hints |
| `m4xshen/hardtime.nvim` | Nudges away from inefficient motions |
| `lukas-reineke/indent-blankline.nvim` | Indent guides |
| `brenoprata10/nvim-highlight-colors` | Inline color previews for hex codes etc. |
| `ojroques/vim-oscyank` | Clipboard over SSH |
| `ThePrimeagen/vim-be-good` | Vim motion practice game |

Several more colorschemes are installed purely for browsing via `<leader>ft` (see
`lua/plugins/themes.lua`) — they're not active by default.

## Install scripts

Both scripts are safe to re-run — every step checks before acting, so running one again
after adding new language servers to `lsp.lua` just fills in whatever's newly missing.

### `install.sh` (Arch-based Linux)

Does **not** need to be run from a login shell with root — it calls `sudo` itself only
for the pacman step.

**What it installs:**

- **Core (pacman):** git, base-devel, neovim, ripgrep, fd, unzip, curl, wget, cmake,
  clang (clangd + clang-format + clang-tidy), rust-analyzer, go, gopls,
  lua-language-server, nodejs, npm, python, python-pip, wl-clipboard, xclip,
  a Nerd Font (JetBrains Mono Nerd)
- **npm (global):** typescript, typescript-language-server, intelephense,
  vscode-langservers-extracted, vscode-json-languageserver, @tailwindcss/language-server
- **pip (user):** cmake-language-server
- **go install:** templ
- **Copies `assets/clang-format-global` to `~/.clang-format`**
- **Runs `lazy.nvim` sync** to install every plugin

**What it deliberately doesn't install** (AUR-only or toolchain-heavy — install
manually if you need that filetype's LSP support): `zls` (Zig), `nil` (Nix),
`glsl_analyzer` (GLSL), `c3-lsp` (C3), `serve-d` (D), `haskell-language-server`.
Your config works fine without them; those specific filetypes just won't get LSP
support until you install the server yourself.

**Non-Arch distros:** the script exits immediately with a message if `pacman` isn't
found. Install the equivalent packages from the list above using your distro's package
manager, then the npm/pip/go/clang-format/Lazy-sync steps in the script are distro-agnostic
if you want to run those portions by hand or adapt the script.

**Testing note:** syntax-checked, every referenced package name verified against the
actual pacman/npm/pip/go registries, and run end-to-end (the npm/pip/go/clang-format/
Lazy-sync steps genuinely executed; the `sudo pacman` step was verified by confirming
every package name resolves, since the test environment didn't have an interactive sudo
session available to complete that step live).

### `install-macos.sh` (macOS)

Installs Xcode Command Line Tools and Homebrew itself if either is missing (Xcode's
installer is a GUI prompt — the script tells you to re-run once it finishes). Homebrew's
`shellenv` and any PATH additions it needs (`llvm`'s keg-only bin dir for `clangd`,
Go's `$GOPATH/bin` for `templ`) get appended to `~/.zprofile` if not already present, so
open a new terminal after running it.

**What it installs:**

- **Core (Homebrew):** git, neovim, ripgrep, fd, unzip, wget, cmake, llvm (for clangd),
  clang-format, rust, rust-analyzer, go, gopls, lua-language-server, node, python@3.13,
  zls, haskell-language-server
- **Cask:** font-jetbrains-mono-nerd-font
- **npm (global):** same six packages as `install.sh`
- **pip (user, via the Homebrew python):** cmake-language-server
- **go install:** templ
- **Copies `assets/clang-format-global` to `~/.clang-format`**
- **Runs `lazy.nvim` sync** to install every plugin

No clipboard package is needed — macOS's built-in `pbcopy`/`pbpaste` work with
`unnamedplus` out of the box.

Two servers that need an AUR helper on Arch (`zls`, `haskell-language-server`) have real
Homebrew formulae and get installed directly here — one advantage over the Arch script.
Four don't have a Homebrew formula at all: `nil` (Nix), `glsl_analyzer` (GLSL), `c3-lsp`
(C3), `serve-d` (D) — build from source if you need those filetypes.

**Testing note:** syntax-checked, and every Homebrew formula/cask name verified against
the live `formulae.brew.sh` API (including checking `keg_only` status, which is why only
`llvm` gets special PATH handling) — but this script could not be run end-to-end, since
no macOS machine was available while writing it. Run it once yourself and report back if
anything needs adjusting.
