return {
    -- Completion from LSP, snippets, the buffer and file paths.
    {
        'hrsh7th/nvim-cmp',
        dependencies = {
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-buffer',
            'hrsh7th/cmp-path',
            { 'L3MON4D3/LuaSnip', build = 'make install_jsregexp' },
            'saadparwaiz1/cmp_luasnip',
        },
        config = function()
            local cmp = require('cmp')
            local luasnip = require('luasnip')

            -- Tab/Shift-Tab: move through the menu if it's open, else
            -- expand or jump through a snippet, else insert a normal Tab.
            local function tab(direction)
                return cmp.mapping(function(fallback)
                    if cmp.visible() then
                        if direction > 0 then cmp.select_next_item() else cmp.select_prev_item() end
                    elseif direction > 0 and luasnip.expand_or_jumpable() then
                        luasnip.expand_or_jump()
                    elseif direction < 0 and luasnip.jumpable(-1) then
                        luasnip.jump(-1)
                    else
                        fallback()
                    end
                end, { 'i', 's' })
            end

            cmp.setup({
                snippet = {
                    expand = function(args) luasnip.lsp_expand(args.body) end,
                },
                mapping = cmp.mapping.preset.insert({
                    ['<C-Space>'] = cmp.mapping.complete(),
                    ['<C-e>'] = cmp.mapping.abort(),
                    ['<CR>'] = cmp.mapping.confirm({ select = false }), -- only confirm an explicit selection
                    ['<Tab>'] = tab(1),
                    ['<S-Tab>'] = tab(-1),
                }),
                -- Buffer words and paths only show when LSP/snippets have nothing.
                sources = cmp.config.sources(
                    { { name = 'nvim_lsp' }, { name = 'luasnip' } },
                    { { name = 'buffer' }, { name = 'path' } }
                ),
            })
        end,
    },

    -- Parameter hints in a float while typing a call.
    {
        'ray-x/lsp_signature.nvim',
        event = 'VeryLazy',
        opts = {
            hint_enable = false, -- no virtual-text hint next to the cursor
            max_width = 80,
        },
    },
}
