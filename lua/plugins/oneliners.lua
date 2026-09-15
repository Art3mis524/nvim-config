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
	'lewis6991/gitsigns.nvim',
	opts = {},
    },
    {
	'mg979/vim-visual-multi',
    },
    {
	'akinsho/toggleterm.nvim',
	version = '*',
	opts = {
	    direction = 'vertical',
	    size = function(term)
		if term.direction == 'vertical' then
		    return math.floor(vim.o.columns * 0.4)
		end
	    end,
	    open_mapping = [[<c-\>]],
	},
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
    {
	'ray-x/lsp_signature.nvim',
	event = 'VeryLazy',
	opts = {
	    hint_enable = false,
	    floating_window = true,
	    max_height = 12,
	    max_width = 80,
	    debug = true,
	    log_path = vim.fn.stdpath('cache') .. '/lsp_signature.log',
	    ignore_error = function() return false end,
	},
    },
}
