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
            restricted_keys = {
                -- <C-n> is remapped to multicursor.nvim's matchAddCursor,
                -- which is meant to be pressed repeatedly; don't block it.
                ['<C-N>'] = {},
            },
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
	'jake-stewart/multicursor.nvim',
	branch = '1.0',
	config = function()
	    local mc = require('multicursor-nvim')
	    mc.setup()

	    local set = vim.keymap.set

	    -- Ctrl-n / Ctrl-Down / Ctrl-Up match vim-visual-multi's mappings,
	    -- kept the same on purpose to preserve muscle memory.
	    set({ 'n', 'x' }, '<C-n>', function() mc.matchAddCursor(1) end)
	    set({ 'n', 'x' }, '<C-Down>', function() mc.lineAddCursor(1) end)
	    set({ 'n', 'x' }, '<C-Up>', function() mc.lineAddCursor(-1) end)

	    set('n', '<C-LeftMouse>', mc.handleMouse)
	    set('n', '<C-LeftDrag>', mc.handleMouseDrag)
	    set('n', '<C-LeftRelease>', mc.handleMouseRelease)

	    -- Keyboard equivalent of Ctrl-click: add/remove a cursor at the
	    -- current cursor position.
	    set({ 'n', 'x' }, '<C-q>', mc.toggleCursor)

	    -- Only active while multiple cursors exist, so this never touches
	    -- normal Escape behaviour otherwise.
	    mc.addKeymapLayer(function(layerSet)
		layerSet({ 'n', 'x' }, '<Esc>', function()
		    if not mc.cursorsEnabled() then
			mc.enableCursors()
		    else
			mc.clearCursors()
		    end
		end)
	    end)
	end,
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
