return {
    {
        'folke/which-key.nvim',
        event = 'VeryLazy',
        opts = {
            delay = 500,
        },
    },
    {
        'm4xshen/hardtime.nvim',
        dependencies = { 'MunifTanjim/nui.nvim' },
        event = 'VeryLazy',
        opts = {
            disable_mouse = false,
        },
    },
    {
        'ThePrimeagen/vim-be-good',
        cmd = 'VimBeGood',
    },
    {
	'ojroques/vim-oscyank',
    },
    {
	'tpope/vim-fugitive',
    },
    {
	'brenoprata10/nvim-highlight-colors',
	config = function()
	    require('nvim-highlight-colors').setup({})
	end
    },
    {
	'folke/ts-comments.nvim',
	event = 'VeryLazy',
	opts = {},
    },
    {
	'lukas-reineke/indent-blankline.nvim',
	main = 'ibl',
	opts = {},
    },
}
