return {
    "hrsh7th/cmp-nvim-lsp",
    dependencies = {
        "hrsh7th/nvim-cmp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        { "L3MON4D3/LuaSnip", build = "make install_jsregexp" },
        "saadparwaiz1/cmp_luasnip",
    },
    config = function()
        local cmp = require("cmp")
        local luasnip = require("luasnip")

        cmp.setup({
            snippet = {
                expand = function(args)
                    luasnip.lsp_expand(args.body)
                end,
            },
            mapping = cmp.mapping.preset.insert({
                ['<C-Space>'] = cmp.mapping.complete(),
                ['<C-e>']     = cmp.mapping.abort(),
                ['<CR>']      = cmp.mapping.confirm({ select = false }),
                ['<Tab>']     = cmp.mapping(function(fallback)
                    if cmp.visible() then cmp.select_next_item()
                    elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
                    else fallback() end
                end, { 'i', 's' }),
                ['<S-Tab>']   = cmp.mapping(function(fallback)
                    if cmp.visible() then cmp.select_prev_item()
                    elseif luasnip.jumpable(-1) then luasnip.jump(-1)
                    else fallback() end
                end, { 'i', 's' }),
            }),
            sources = cmp.config.sources({
                { name = 'nvim_lsp' },
                { name = 'luasnip' },
            }, {
                { name = 'buffer' },
                { name = 'path' },
            }),
        })

        vim.lsp.config('*', {
            root_markers = { '.git' },
        })

        vim.diagnostic.config({
            virtual_text  = true,
            severity_sort = true,
            float         = {
                style  = 'minimal',
                border = 'rounded',
                source = 'if_many',
                header = '',
                prefix = '',
            },
            signs         = {
                text = {
                    [vim.diagnostic.severity.ERROR] = '✘',
                    [vim.diagnostic.severity.WARN]  = '▲',
                    [vim.diagnostic.severity.HINT]  = '⚑',
                    [vim.diagnostic.severity.INFO]  = '»',
                },
            },
        })

        local orig = vim.lsp.util.open_floating_preview
        ---@diagnostic disable-next-line: duplicate-set-field
        function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
            opts            = opts or {}
            opts.border     = opts.border or 'rounded'
            opts.max_width  = opts.max_width or 80
            opts.max_height = opts.max_height or 24
            opts.wrap       = opts.wrap ~= false
            return orig(contents, syntax, opts, ...)
        end

        -- nvim-lspconfig normally provides :LspRestart; this config doesn't use
        -- that plugin, so replicate it: stop attached clients, then reload the
        -- buffer so vim.lsp.enable()'s autostart reattaches a fresh one.
        vim.api.nvim_create_user_command('LspRestart', function()
            local buf = vim.api.nvim_get_current_buf()
            local clients = vim.lsp.get_clients({ bufnr = buf })
            if #clients == 0 then
                vim.notify('No LSP clients attached to this buffer', vim.log.levels.WARN)
                return
            end
            local names = {}
            for _, client in ipairs(clients) do
                table.insert(names, client.name)
                client:stop(true)
            end
            vim.defer_fn(function()
                vim.cmd.edit()
                vim.notify('Restarted: ' .. table.concat(names, ', '))
            end, 200)
        end, {})

        vim.api.nvim_create_autocmd('LspAttach', {
            group = vim.api.nvim_create_augroup('my.lsp', {}),
            callback = function(args)
                local client = assert(vim.lsp.get_client_by_id(args.data.client_id))

                local buf    = args.buf
                local map    = function(mode, lhs, rhs) vim.keymap.set(mode, lhs, rhs, { buffer = buf }) end

                map('n', 'K', vim.lsp.buf.hover)
                map('n', 'gd', vim.lsp.buf.definition)
                map('n', 'gD', vim.lsp.buf.declaration)
                map('n', 'gi', vim.lsp.buf.implementation)
                map('n', 'go', vim.lsp.buf.type_definition)
                map('n', 'gr', vim.lsp.buf.references)
                map('n', 'gs', vim.lsp.buf.signature_help)
                map('n', 'gl', vim.diagnostic.open_float)
                map('n', '<F2>', vim.lsp.buf.rename)
                map('n', '<leader>rn', vim.lsp.buf.rename)
                map({ 'n', 'x' }, '<F3>', function() vim.lsp.buf.format({ async = true }) end)
                map({ 'n', 'x' }, '<leader>f', function() vim.lsp.buf.format({ async = true }) end)
                local function code_action_line()
                    local line = vim.api.nvim_win_get_cursor(0)[1] - 1
                    local line_len = #vim.api.nvim_buf_get_lines(0, line, line + 1, false)[1]
                    vim.lsp.buf.code_action({
                        range = {
                            ['start'] = { line, 0 },
                            ['end'] = { line, line_len },
                        },
                    })
                end
                map('n', '<F4>', code_action_line)
                map('n', '<leader>ca', code_action_line)
                map('n', '<leader>lr', vim.cmd.LspRestart)

                if client:supports_method('textDocument/documentHighlight') then
                    local highlight_augroup = vim.api.nvim_create_augroup('my.lsp.highlight', { clear = false })
                    vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
                        buffer = buf,
                        group = highlight_augroup,
                        callback = vim.lsp.buf.document_highlight,
                    })
                    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
                        buffer = buf,
                        group = highlight_augroup,
                        callback = vim.lsp.buf.clear_references,
                    })
                end

                local excluded_filetypes = { c = true }
                if not client:supports_method('textDocument/willSaveWaitUntil')
                    and client:supports_method('textDocument/formatting')
                    and not excluded_filetypes[vim.bo[buf].filetype]
                then
                    -- Use a buffer-scoped augroup with clear=true so that each new
                    -- attaching client replaces the previous formatter. Without this,
                    -- every client that supports formatting adds its own BufWritePre
                    -- autocmd and they all run sequentially on every save.
                    vim.api.nvim_create_autocmd('BufWritePre', {
                        group = vim.api.nvim_create_augroup('my.lsp.format.' .. buf, { clear = true }),
                        buffer = buf,
                        callback = function()
                            vim.lsp.buf.format({ bufnr = buf, id = client.id, timeout_ms = 1000 })
                        end,
                    })
                end
            end,
        })

        local caps = require("cmp_nvim_lsp").default_capabilities()

        vim.lsp.config['luals'] = {
            cmd = { 'lua-language-server' },
            filetypes = { 'lua' },
            root_markers = { { '.luarc.json', '.luarc.jsonc' }, '.git' },
            capabilities = caps,
            settings = {
                Lua = {
                    runtime = { version = 'LuaJIT' },
                    diagnostics = { globals = { 'vim' } },
                    workspace = {
                        checkThirdParty = false,
                        library = vim.api.nvim_get_runtime_file('', true),
                    },
                    telemetry = { enable = false },
                },
            },
        }

        vim.lsp.config['cmake'] = {
            cmd = { 'cmake-language-server' },
            filetypes = { 'cmake' },
            root_markers = { 'CMakeLists.txt', 'CMakePresets.json', '.git' },
            capabilities = caps,
            init_options = {
                buildDirectory = 'build',
            },
        }

        -- Compilers clangd may run to discover system include paths. On
        -- Windows they live wherever Scoop/MSYS2 put them, so use the ones on
        -- PATH (forward slashes: query-driver takes globs).
        local query_driver = '/usr/bin/clang*,/usr/bin/clang++*,/usr/bin/gcc*,/usr/bin/g++*,/usr/bin/cc*,/usr/bin/c++*'
        if vim.fn.has('win32') == 1 then
            local drivers = {}
            for _, exe in ipairs({ 'gcc', 'g++', 'clang', 'clang++' }) do
                local path = vim.fn.exepath(exe)
                if path ~= '' then table.insert(drivers, (path:gsub('\\', '/'))) end
            end
            query_driver = table.concat(drivers, ',')
        end

        vim.lsp.config['clangd'] = {
            cmd = {
                'clangd',
                '--background-index',
                '--clang-tidy',
                '--header-insertion=never',
                '--completion-style=detailed',
                '--function-arg-placeholders',
                '--query-driver=' .. query_driver,
            },
            filetypes = { 'c', 'cpp', 'objc', 'objcpp' },
            root_markers = { 'compile_commands.json', '.clangd', 'configure.ac', 'Makefile', '.git' },
            capabilities = caps,
            init_options = {
                fallbackFlags = { '-std=c++17' },
            },
        }

        vim.filetype.add({
            extension = {
                h = 'cpp',
            },
        })

        ---@diagnostic disable-next-line: invisible
        for name, _ in pairs(vim.lsp.config._configs) do
            if name ~= '*' then
                vim.lsp.enable(name)
            end
        end
    end,
}
