-- Plugin install step of the install scripts, run after the config loads:
--
--     nvim --headless "+lua dofile(vim.fn.stdpath('config') .. '/scripts/sync-plugins.lua')"
--
-- Installs every plugin at its lazy-lock.json version, moves the cyberpunk
-- theme (my own) to its latest commit, and builds LuaSnip's jsregexp if it's
-- missing. Exits non-zero if lazy.nvim didn't load or a plugin is still
-- missing afterwards. (Headless nvim would otherwise exit 0 regardless.)
local function fail(msg)
    io.stderr:write(msg .. '\n')
    vim.cmd.cquit(1)
end

if not package.loaded.lazy then fail('lazy.nvim did not load') end

vim.cmd('Lazy! restore')
vim.cmd('Lazy! update cyberpunk')

-- Only build when the library is missing: rebuilding overwrites it in place,
-- which crashes nvim on exit once LuaSnip has loaded it.
local luasnip = require('lazy.core.config').plugins.LuaSnip
if #vim.fn.glob(luasnip.dir .. '/deps/luasnip-jsregexp.*', false, true) == 0 then
    vim.cmd('Lazy! build LuaSnip')
end

local missing = {}
for _, plugin in ipairs(require('lazy').plugins()) do
    if not plugin._.installed then table.insert(missing, plugin.name) end
end
if #missing > 0 then fail('plugins not installed: ' .. table.concat(missing, ' ')) end
vim.cmd('qall!')
