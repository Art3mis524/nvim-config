return {
    -- Statusline, coloured by the cyberpunk theme's lualine palette.
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        opts = {
            options = { theme = 'cyberpunk' },
            sections = {
                lualine_c = { { 'filename', path = 1 } }, -- path relative to cwd
            },
        },
    },

    -- Popup listing the keys that can follow a partly typed mapping.
    {
        'folke/which-key.nvim',
        event = 'VeryLazy',
        opts = { delay = 500 },
    },

    -- Indent guides.
    {
        'lukas-reineke/indent-blankline.nvim',
        main = 'ibl',
        opts = {},
    },

    -- Colour previews behind hex codes, rgb() etc.
    {
        'brenoprata10/nvim-highlight-colors',
        opts = {},
    },
}
