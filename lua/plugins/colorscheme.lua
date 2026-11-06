return {
    -- Active theme (my own). The other theme is the calmer :colorscheme cyberpunk.
    {
        'Art3mis524/cyberpunk',
        lazy = false,
        priority = 1000, -- load before other plugins so they see its colours
        config = function()
            vim.cmd.colorscheme('cyberpunkNeon')
        end,
    },

    -- Extra themes only for browsing with <leader>ft (telescope.lua). They
    -- stay unloaded until previewed or picked with :colorscheme.
    { 'folke/tokyonight.nvim', lazy = true },
    { 'catppuccin/nvim', name = 'catppuccin', lazy = true },
    { 'ellisonleao/gruvbox.nvim', lazy = true },
    { 'sainnhe/everforest', lazy = true },
    { 'maxmx03/solarized.nvim', lazy = true },
    { 'shaunsingh/nord.nvim', lazy = true },
    { 'Mofiqul/vscode.nvim', lazy = true },
    { 'Mofiqul/dracula.nvim', lazy = true },
    { 'rebelot/kanagawa.nvim', lazy = true },
    { 'EdenEast/nightfox.nvim', lazy = true },
    { 'projekt0n/github-nvim-theme', lazy = true },
    { 'sainnhe/sonokai', lazy = true },
    { 'loctvl842/monokai-pro.nvim', lazy = true },
    { 'Rigellute/shades-of-purple.vim', lazy = true },
    { 'marko-cerovac/material.nvim', lazy = true },
    { 'oxfist/night-owl.nvim', lazy = true },
}
