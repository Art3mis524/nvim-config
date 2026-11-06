local opt = vim.opt

-- Line numbers: absolute on the cursor line, relative elsewhere.
opt.number = true
opt.relativenumber = true
opt.cursorline = true
-- Always show the sign column, so text doesn't shift sideways whenever git
-- or diagnostic signs appear.
opt.signcolumn = 'yes'

-- 4-space indentation; after/ftplugin/ narrows it for some filetypes.
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4

-- Idle time (ms) before CursorHold, which highlights other uses of the
-- symbol under the cursor (config/lsp.lua). The default of 4000 is sluggish.
opt.updatetime = 250

-- Yank and paste through the system clipboard. Over SSH there's no clipboard
-- tool, so copy through the terminal with OSC 52; pasting keeps Neovim's own
-- register, since an OSC 52 paste makes the terminal ask permission every time.
opt.clipboard = 'unnamedplus'
if vim.env.SSH_TTY then
    local osc52 = require('vim.ui.clipboard.osc52')
    local function paste()
        return { vim.fn.split(vim.fn.getreg(''), '\n'), vim.fn.getregtype('') }
    end
    vim.g.clipboard = {
        name = 'OSC 52 (copy only)',
        copy = { ['+'] = osc52.copy('+'), ['*'] = osc52.copy('*') },
        paste = { ['+'] = paste, ['*'] = paste },
    }
end

-- No remote plugins are used, so skip the language providers (and their
-- :checkhealth warnings).
vim.g.loaded_python3_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
