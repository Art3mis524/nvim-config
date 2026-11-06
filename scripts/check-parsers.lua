-- Parser step of the install scripts, run after sync-plugins.lua:
--
--     nvim --headless "+lua dofile(vim.fn.stdpath('config') .. '/scripts/check-parsers.lua')"
--
-- Starting nvim already installed any missing parser (plugins/treesitter.lua
-- waits for that when headless); this checks every parser in
-- config/parsers.lua is now there, printing any that aren't and exiting
-- non-zero.
local installed = require('nvim-treesitter.config').get_installed()
local missing = vim.tbl_filter(function(lang)
    return not vim.list_contains(installed, lang)
end, require('config.parsers'))
if #missing > 0 then
    io.stdout:write('missing parsers: ' .. table.concat(missing, ' ') .. '\n')
    vim.cmd.cquit(1)
end
vim.cmd('qall!')
