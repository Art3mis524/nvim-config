-- Global keymaps. Plugin keymaps live in their plugin spec and LSP ones in
-- config/lsp.lua. The leader has to be set before lazy.nvim loads plugins.
vim.g.mapleader = ' '

vim.keymap.set('n', '<leader>e', vim.cmd.Ex, { desc = 'File explorer (netrw)' })
