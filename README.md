# nvim-config (windows-minimal)

My personal Neovim configuration, **trimmed down for Windows**: only C/C++, CMake, Make,
Lua and Markdown are set up, and only what those need gets installed. Built around native
LSP (`vim.lsp.config`/`vim.lsp.enable`, no `nvim-lspconfig`), `lazy.nvim` for plugins, and
a custom colorscheme ([`cyberpunk`](https://github.com/Art3mis524/cyberpunk)).

This is the `windows-minimal` branch (latest tag `windows-minimal-v2`). The full config, with
every language and the macOS/Arch install scripts, is on
[`master`](https://github.com/Art3mis524/nvim-config).

## Quick start

In PowerShell, not as admin (**not yet tested on a Windows machine**, see
[below](#install-windowsps1)):

```powershell
git clone --branch windows-minimal-v2 https://github.com/Art3mis524/nvim-config.git $env:USERPROFILE\nvim-config
cd $env:USERPROFILE\nvim-config
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
# open a new terminal so the PATH changes take effect, then:
nvim
```

(Cloning the tag leaves you on a "detached HEAD", which is fine for just using it. Clone
with `--branch windows-minimal` instead if you want to commit changes to this version.
No git yet? Download the tag as a zip from GitHub's Releases/Tags page; the script
installs git.)

The script handles system packages, language servers, and the global `.clang-format`.
See [`install-windows.ps1`](#install-windowsps1) below for exactly what it installs.

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
| `-`/`:colorscheme <Tab>` | Not bound here — see `<leader>ft` above instead |

## Languages

| Language | Syntax (treesitter) | Language server |
|---|---|---|
| C / C++ | `c`, `cpp` | `clangd` |
| CMake | `cmake` | `cmake-language-server` |
| Make | `make` | — |
| Lua | `lua` | `lua-language-server` |
| Markdown | `markdown`, `markdown_inline` | — |

`.h` files are treated as C++. Format-on-save runs whenever the attached language server
can format the file, except for C (C++ is included — see
[Formatting](#formatting-clang-format) below).

## Formatting (clang-format)

C/C++ formatting uses `clang-format`, configured via `.clang-format` files:

- `~/.clang-format` (installed by `install-windows.ps1` from `assets/clang-format-global`) —
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
a normal plugin dependency), currently on the `cyberpunkNeon` style variant. The install
script always pulls its latest commit rather than the one pinned in `lazy-lock.json`, so
re-running the script picks up theme changes; in an open nvim, `:Lazy update cyberpunk`
does the same.
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
| `jake-stewart/multicursor.nvim` | Multiple cursors |
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

## `install-windows.ps1`

> **Untested on Windows.** So far the script has only been checked from macOS: it
> parses cleanly and passes PowerShell 5.1 compatibility linting (PSScriptAnalyzer),
> and every package name, download URL and archive layout it relies on was verified.
> It has not had a complete end-to-end run on real Windows yet, so expect rough
> edges and please report what breaks.

Run it in a normal (non-admin) PowerShell from inside a clone of this repo: the clone is
linked to `%LOCALAPPDATA%\nvim` with a directory junction (no admin or Developer Mode
needed), and an existing config there is moved to `nvim.bak-<timestamp>` first. It sets
the current user's execution policy to `RemoteSigned` (so Scoop's shims run), installs
Scoop if missing, and adds `~\.local\bin` to the user PATH, so open a new terminal after
running it. It's written for the Windows PowerShell 5.1 that ships with Windows, so no
PowerShell 7 is needed.

**What it installs:**

- **Core (Scoop):** git, neovim, ripgrep, fd, cmake, make, mingw (gcc, used to compile
  treesitter parsers, telescope-fzf-native and LuaSnip's jsregexp), tree-sitter, llvm
  (clangd + clang-format), lua-language-server, uv
- **Scoop `nerd-fonts` bucket:** Hermit-NF (per-user, no admin)
- **uv tool:** cmake-language-server (uv fetches its own Python, so no Python installer
  is needed)
- **Copies `assets/clang-format-global` to `~\.clang-format`**
- **Installs every plugin at the version pinned in `lazy-lock.json`** (`Lazy! restore`),
  except the `cyberpunk` theme, which is updated to its latest commit; builds LuaSnip's
  `jsregexp`, installs the treesitter parsers listed in
  `lua/config/parsers.lua`, and checks that none are missing

The script is safe to re-run — every step checks before acting.

On ARM64 Windows it installs x64 builds of everything (they run under emulation): mingw
only exists for x64, and the parsers and plugin libraries it compiles must match
Neovim's architecture to load.

Windows-specific bits in the config itself: toggleterm opens PowerShell instead of
`cmd.exe`, treesitter compiles with `gcc` when MSVC isn't installed, and clangd's
`--query-driver` uses whichever compilers are on PATH.

## Smoke test

`tests/smoke.lua` checks that the machine is actually set up: no startup
errors, every plugin installed, telescope-fzf-native and jsregexp built, every parser
installed and loadable, every configured language server's command on PATH, and that
`luals`, `clangd` and `cmake` really attach to a sample file.

```powershell
nvim --headless "+luafile tests/smoke.lua"
# servers you don't expect on this machine can be skipped:
$env:SMOKE_SKIP_SERVERS = 'cmake'; nvim --headless "+luafile tests/smoke.lua"
```

It prints one line per check and exits non-zero if any fail.
