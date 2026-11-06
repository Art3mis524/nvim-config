-- Headless smoke test for this config, the same on every OS. Run it after an
-- install script to confirm the machine is actually set up:
--
--     nvim --headless "+luafile tests/smoke.lua"
--
-- Checks startup errors, the colorscheme and statusline theme, plugins and
-- their compiled libraries, treesitter parsers, per-filetype indentation,
-- that every configured language server's command is on PATH, that a few
-- servers really attach (with this config's keymaps), that hurl.nvim's
-- <leader>ha sends a request (to a local server) and shows the response,
-- that prettier and pnpm run, that markdown renders and wraps at word
-- boundaries, and that copying works over SSH.
-- Exits 0 when everything passes, 1 otherwise.
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

out('== theme')
check(vim.g.colors_name == 'cyberpunkNeon', 'colorscheme is cyberpunkNeon (got ' .. tostring(vim.g.colors_name) .. ')')
check(require('lualine').get_config().options.theme == 'cyberpunk', 'lualine uses the cyberpunk theme')
-- Browse-only themes stay unloaded but are still found by :colorscheme
-- (and so by the <leader>ft picker).
local tokyonight = require('lazy.core.config').plugins['tokyonight.nvim']
check(tokyonight and not tokyonight._.loaded, 'browse-only themes are lazy-loaded')
check(pcall(vim.cmd.colorscheme, 'tokyonight') and vim.startswith(vim.g.colors_name or '', 'tokyonight'),
    ':colorscheme loads a lazy theme on demand')
vim.cmd.colorscheme('cyberpunkNeon')

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
require('lazy').load({ plugins = { 'telescope.nvim' } })
check(pcall(function() return require('telescope').extensions.fzf.native_fzf_sorter end),
    'telescope loads the fzf-native sorter')

out('== treesitter parsers')
local have = {}
for _, p in ipairs(require('nvim-treesitter.config').get_installed()) do have[p] = true end
for _, p in ipairs(require('config.parsers')) do
    local ok = have[p] and pcall(vim.treesitter.language.add, p)
    check(ok, 'parser ' .. p .. ' installed and loadable')
end

out('== indentation')
for ft, width in pairs({ html = 2, json = 2, jsonc = 2, typescript = 4, lua = 4 }) do
    vim.cmd('enew | setfiletype ' .. ft)
    check(vim.bo.shiftwidth == width and vim.bo.expandtab, ft .. ' indents with ' .. width .. ' spaces')
    vim.cmd('bwipeout!')
end

out('== language server commands')
local servers = {}
for _, config in ipairs(vim.lsp.get_configs({ enabled = true })) do
    table.insert(servers, config.name)
end
table.sort(servers)
check(#servers == #vim.fn.globpath(vim.fn.stdpath('config'), 'lsp/*.lua', false, true),
    #servers .. ' servers enabled, one per lsp/*.lua file')
-- Servers whose cmd is a function (so the executable can't be read off it).
local function_cmd_exes = { jdtls = 'jdtls' }
local runnable = {}
for _, name in ipairs(servers) do
    local cmd = vim.lsp.config[name].cmd
    local exe = type(cmd) == 'table' and cmd[1] or function_cmd_exes[name]
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
    { server = 'luals',  file = 'sample.lua',  text = { 'local x = 1', 'return x' } },
    { server = 'ts_ls',  file = 'sample.ts',   text = { 'const x: number = 1;', 'export default x;' } },
    { server = 'clangd', file = 'sample.cpp',  text = { 'int main() { return 0; }' } },
    { server = 'gopls',  file = 'sample.go',   text = { 'package main', '', 'func main() {}' } },
    -- jdtls boots a JVM, so give it longer.
    { server = 'jdtls',  file = 'Sample.java', text = { 'class Sample {}' },                          timeout = 90000 },
}
for _, s in ipairs(samples) do
    if runnable[s.server] then
        local path = tmp .. '/' .. s.file
        vim.fn.writefile(s.text, path)
        vim.cmd.edit(vim.fn.fnameescape(path))
        local buf = vim.api.nvim_get_current_buf()
        local attached = vim.wait(s.timeout or 30000, function()
            return #vim.lsp.get_clients({ bufnr = buf, name = s.server }) > 0
        end, 200)
        check(attached, s.server .. ' attached to ' .. s.file)
        if attached and s.server == 'luals' then
            local gr = vim.fn.maparg('gr', 'n', false, true)
            check(gr.buffer == 1 and gr.nowait == 1, 'LSP keymaps set (gr is buffer-local and nowait)')
        end
    end
end
-- Stop servers politely first, so they don't report being killed.
for _, client in ipairs(vim.lsp.get_clients()) do client:stop() end
vim.wait(5000, function() return #vim.lsp.get_clients() == 0 end, 100)
for _, client in ipairs(vim.lsp.get_clients()) do client:stop(true) end

out('== hurl (REST client)')
local have_hurl = check(vim.fn.executable('hurl') == 1, 'hurl on PATH')
check(vim.fn.executable('jq') == 1, 'jq on PATH (formats JSON responses)')
if have_hurl then
    -- A one-shot local HTTP server, so the request needs no network.
    local server = assert(vim.uv.new_tcp())
    server:bind('127.0.0.1', 0)
    local port = server:getsockname().port
    server:listen(8, function()
        local conn = assert(vim.uv.new_tcp())
        server:accept(conn)
        local req = ''
        conn:read_start(function(_, chunk)
            req = req .. (chunk or '')
            if not chunk or req:find('\r\n\r\n', 1, true) then
                local body = '{"pong":true}'
                conn:write('HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: '
                    .. #body .. '\r\nConnection: close\r\n\r\n' .. body, function() conn:close() end)
            end
        end)
    end)

    local path = tmp .. '/sample.hurl'
    vim.fn.writefile({ 'GET http://127.0.0.1:' .. port .. '/ping', 'HTTP 200' }, path)
    vim.cmd.edit(vim.fn.fnameescape(path))
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    -- Press the real keybind, the same as a user would.
    vim.api.nvim_feedkeys(vim.keycode('<leader>ha'), 'mx', false)
    local shown = vim.wait(30000, function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
            if table.concat(lines, '\n'):find('"pong": true', 1, true) then return true end
        end
        return false
    end, 200)
    check(shown, '<leader>ha sent a request and showed the formatted response')
    server:close()
end

out('== command-line tools')
for _, tool in ipairs({ 'prettier', 'pnpm' }) do
    -- Run it directly rather than through a shell, the way editors and other
    -- tools do. vim.system raises (e.g. ENOEXEC) when the file can't be
    -- executed at all, so catch that and report it as a failure.
    local ok, res = pcall(function()
        return vim.system({ tool, '--version' }, { text = true }):wait()
    end)
    local ran = ok and res.code == 0
    check(ran, tool .. ' on PATH and runs'
        .. (not ok and (' (' .. tostring(res):match('[^:]*:%s*[^\n]*$') .. ')') or ''))
end

out('== markdown')
local md = tmp .. '/README.md'
vim.fn.writefile({ '# Title', '', '- [ ] a checkbox', '', '```lua', 'print(1)', '```' }, md)
vim.cmd.edit(vim.fn.fnameescape(md))
local md_buf = vim.api.nvim_get_current_buf()
check(vim.wo.wrap and vim.wo.linebreak and vim.wo.breakindent,
    'wrap, linebreak and breakindent set (lines break between words)')
local ns = vim.api.nvim_create_namespace('render-markdown.nvim')
local rendered = vim.wait(5000, function()
    return #vim.api.nvim_buf_get_extmarks(md_buf, ns, 0, -1, {}) > 0
end, 100)
check(rendered, 'render-markdown.nvim rendered the buffer')

out('== clipboard over SSH')
-- A child nvim with SSH_TTY set should copy through OSC 52 and paste from
-- its own register.
local res = vim.system({ vim.v.progpath, '--headless',
    '+lua vim.fn.setline(1, "copied") vim.cmd("normal! yy") io.stdout:write(vim.g.clipboard.name .. "|" .. vim.fn.getreg("+"))',
    '+qa!' }, { env = { SSH_TTY = '/dev/pts/0' }, text = true }):wait(20000)
check(res.code == 0 and res.stdout:find('OSC 52', 1, true) and res.stdout:find('|copied', 1, true),
    'yank uses OSC 52 over SSH and paste reads it back')

out('')
out(failures == 0 and 'SMOKE TEST PASSED' or ('SMOKE TEST FAILED: ' .. failures .. ' check(s)'))
vim.cmd('cquit ' .. (failures == 0 and 0 or 1))
