-- Headless smoke test for this config, the same on every OS. Run it after an
-- install script to confirm the machine is actually set up:
--
--     nvim --headless "+luafile tests/smoke.lua"
--
-- Checks startup errors, plugins, compiled plugin libraries, treesitter
-- parsers, that every configured language server's command is on PATH, and
-- that a few servers really attach to a buffer. Exits 0 when everything
-- passes, 1 otherwise.
--
-- SMOKE_SKIP_SERVERS: comma-separated vim.lsp.config names that are expected
-- to be missing on this machine (e.g. "nil_ls,hls" on Windows).

local failures = 0
local function out(line) io.stdout:write(line .. '\n') end
local function check(ok, msg)
    if ok then
        out('  ok:   ' .. msg)
    else
        out('  FAIL: ' .. msg)
        failures = failures + 1
    end
    return ok
end

local is_win = vim.fn.has('win32') == 1
local skip = {}
for name in (vim.env.SMOKE_SKIP_SERVERS or ''):gmatch('[^,%s]+') do skip[name] = true end

out('== startup')
local messages = vim.api.nvim_exec2('messages', { output = true }).output
check(vim.v.errmsg == '' and not messages:find('E%d+:'),
    'no startup errors' .. (vim.v.errmsg ~= '' and (' (' .. vim.v.errmsg .. ')') or ''))

out('== plugins')
local plugins = require('lazy').plugins()
local not_installed = {}
for _, p in ipairs(plugins) do
    if not p._.installed then table.insert(not_installed, p.name) end
end
check(#not_installed == 0, #plugins .. ' plugins installed'
    .. (#not_installed > 0 and (', missing: ' .. table.concat(not_installed, ' ')) or ''))

local function plugin_dir(name)
    for _, p in ipairs(plugins) do
        if p.name == name then return p.dir end
    end
end
local fzf_dir = plugin_dir('telescope-fzf-native.nvim')
check(fzf_dir and vim.fn.filereadable(fzf_dir .. '/build/libfzf.' .. (is_win and 'dll' or 'so')) == 1,
    'telescope-fzf-native built')
local luasnip_dir = plugin_dir('LuaSnip')
check(luasnip_dir and #vim.fn.glob(luasnip_dir .. '/deps/luasnip-jsregexp.*', false, true) > 0,
    'LuaSnip jsregexp built')

out('== treesitter parsers')
local have = {}
for _, p in ipairs(require('nvim-treesitter.config').get_installed()) do have[p] = true end
for _, p in ipairs(require('config.parsers')) do
    local ok = have[p] and pcall(vim.treesitter.language.add, p)
    check(ok, 'parser ' .. p .. ' installed and loadable')
end

out('== language server commands')
local servers = {}
---@diagnostic disable-next-line: invisible
for name in pairs(vim.lsp.config._configs) do
    if name ~= '*' then table.insert(servers, name) end
end
table.sort(servers)
local runnable = {}
for _, name in ipairs(servers) do
    local cmd = vim.lsp.config[name].cmd
    local exe = type(cmd) == 'table' and cmd[1] or nil
    if skip[name] then
        out('  skip: ' .. name .. ' (SMOKE_SKIP_SERVERS)')
    elseif exe then
        if check(vim.fn.executable(exe) == 1, name .. ': ' .. exe .. ' on PATH') then
            runnable[name] = true
        end
    end
end

out('== language servers attach')
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, 'p')
local samples = {
    { server = 'luals',   file = 'sample.lua', text = { 'local x = 1', 'return x' } },
    { server = 'ts_ls',   file = 'sample.ts',  text = { 'const x: number = 1;', 'export default x;' } },
    { server = 'clangd',  file = 'sample.cpp', text = { 'int main() { return 0; }' } },
    { server = 'gopls',   file = 'sample.go',  text = { 'package main', '', 'func main() {}' } },
}
for _, s in ipairs(samples) do
    if runnable[s.server] then
        local path = tmp .. '/' .. s.file
        vim.fn.writefile(s.text, path)
        vim.cmd.edit(vim.fn.fnameescape(path))
        local buf = vim.api.nvim_get_current_buf()
        local attached = vim.wait(30000, function()
            return #vim.lsp.get_clients({ bufnr = buf, name = s.server }) > 0
        end, 200)
        check(attached, s.server .. ' attached to ' .. s.file)
    end
end
for _, client in ipairs(vim.lsp.get_clients()) do client:stop(true) end

out('')
out(failures == 0 and 'SMOKE TEST PASSED' or ('SMOKE TEST FAILED: ' .. failures .. ' check(s)'))
vim.cmd('cquit ' .. (failures == 0 and 0 or 1))
