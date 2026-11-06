-- Native LSP (vim.lsp.config/vim.lsp.enable, no nvim-lspconfig). Each
-- server has its own file in lsp/, and every file there is enabled below.
-- This file holds what all servers share.

-- Defaults merged into every server: nvim-cmp's completion capabilities,
-- and the git root as the project root unless the server says otherwise.
vim.lsp.config('*', {
    capabilities = require('cmp_nvim_lsp').default_capabilities(),
    root_markers = { '.git' },
})

vim.diagnostic.config({
    virtual_text = true,
    severity_sort = true,
    float = { style = 'minimal', border = 'rounded', source = 'if_many', header = '', prefix = '' },
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = '✘',
            [vim.diagnostic.severity.WARN] = '▲',
            [vim.diagnostic.severity.HINT] = '⚑',
            [vim.diagnostic.severity.INFO] = '»',
        },
    },
})

-- eslint and ts_ls crash answering pull diagnostics (textDocument/diagnostic)
-- in Next.js projects with an undefined plugin path. Their on_init turns the
-- capability off, and this swallows the errors if they register it anyway;
-- both still push diagnostics normally.
local pull_diagnostics = vim.lsp.handlers['textDocument/diagnostic']
vim.lsp.handlers['textDocument/diagnostic'] = function(err, result, ctx, config)
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    if err and client and (client.name == 'ts_ls' or client.name == 'eslint') then
        return
    end
    if pull_diagnostics then
        return pull_diagnostics(err, result, ctx, config)
    end
end

local float = { border = 'rounded', max_width = 80, max_height = 24 }

local function format()
    vim.lsp.buf.format({ async = true })
end

-- Code actions for the whole cursor line, not just the cursor column.
local function line_code_actions()
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
    vim.lsp.buf.code_action({ range = { start = { row, 0 }, ['end'] = { row, #line } } })
end

local function set_keymaps(buf)
    local function map(mode, lhs, rhs, desc, opts)
        vim.keymap.set(mode, lhs, rhs, vim.tbl_extend('force', { buffer = buf, desc = desc }, opts or {}))
    end
    map('n', 'K', function() vim.lsp.buf.hover(float) end, 'Hover docs')
    map('n', 'gd', vim.lsp.buf.definition, 'Go to definition')
    map('n', 'gD', vim.lsp.buf.declaration, 'Go to declaration')
    map('n', 'gi', vim.lsp.buf.implementation, 'Go to implementation')
    map('n', 'go', vim.lsp.buf.type_definition, 'Go to type definition')
    -- nowait: Neovim's default grn/grr/gri/... maps would otherwise make gr
    -- wait 'timeoutlen' for a possible next key.
    map('n', 'gr', vim.lsp.buf.references, 'References', { nowait = true })
    map('n', 'gs', function() vim.lsp.buf.signature_help(float) end, 'Signature help')
    map('n', 'gl', vim.diagnostic.open_float, 'Line diagnostics')
    map('n', '<F2>', vim.lsp.buf.rename, 'Rename symbol')
    map('n', '<leader>rn', vim.lsp.buf.rename, 'Rename symbol')
    map({ 'n', 'x' }, '<F3>', format, 'Format')
    map({ 'n', 'x' }, '<leader>f', format, 'Format')
    map('n', '<F4>', line_code_actions, 'Code actions (line)')
    map('n', '<leader>ca', line_code_actions, 'Code actions (line)')
    map('n', '<leader>lr', '<cmd>lsp restart<cr>', 'Restart LSP')
end

-- Highlight other uses of the symbol under the cursor while idle.
local function highlight_references(client, buf)
    if not client:supports_method('textDocument/documentHighlight') then return end
    local group = vim.api.nvim_create_augroup('my.lsp.highlight', { clear = false })
    vim.api.nvim_clear_autocmds({ group = group, buffer = buf })
    vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        group = group, buffer = buf, callback = vim.lsp.buf.document_highlight,
    })
    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        group = group, buffer = buf, callback = vim.lsp.buf.clear_references,
    })
end

-- Format on save, except for these filetypes.
local no_format_on_save = { c = true, php = true }

local function format_on_save(client, buf)
    -- Servers implementing willSaveWaitUntil handle saving themselves. jdtls
    -- is the exception: it only uses that for its own save actions, and it
    -- registers formatting a moment after attaching, hence the check at
    -- save time rather than now.
    local formats = client.name == 'jdtls'
        or (not client:supports_method('textDocument/willSaveWaitUntil')
            and client:supports_method('textDocument/formatting'))
    if not formats or no_format_on_save[vim.bo[buf].filetype] then return end
    -- One group per buffer, cleared on every attach, so only the most
    -- recently attached formatter runs instead of each one in turn.
    vim.api.nvim_create_autocmd('BufWritePre', {
        group = vim.api.nvim_create_augroup('my.lsp.format.' .. buf, { clear = true }),
        buffer = buf,
        callback = function()
            if client:supports_method('textDocument/formatting', buf) then
                vim.lsp.buf.format({ bufnr = buf, id = client.id, timeout_ms = 1000 })
            end
        end,
    })
end

vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('my.lsp', {}),
    callback = function(args)
        local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
        set_keymaps(args.buf)
        highlight_references(client, args.buf)
        format_on_save(client, args.buf)
    end,
})

require('config.jdtls')

-- Enable every server configured in lsp/ (only this config's directory, so a
-- plugin shipping its own lsp/*.lua files can't enable servers by accident).
local servers = vim.tbl_map(function(path)
    return vim.fn.fnamemodify(path, ':t:r')
end, vim.fn.globpath(vim.fn.stdpath('config'), 'lsp/*.lua', false, true))
vim.lsp.enable(servers)
