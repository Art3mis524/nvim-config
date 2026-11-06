return {
    -- Nudges away from repeating inefficient motions (jjjj, ...).
    {
        'm4xshen/hardtime.nvim',
        dependencies = { 'MunifTanjim/nui.nvim' },
        event = 'VeryLazy',
        opts = {
            disable_mouse = false,
            -- <C-n> is multicursor's add-next-match, meant to be pressed repeatedly.
            restricted_keys = { ['<C-N>'] = {} },
        },
    },

    -- Vim motion practice game: :VimBeGood
    { 'ThePrimeagen/vim-be-good', cmd = 'VimBeGood' },
}
