-- Fuzzy finder, loaded on first use of one of its keys.
local function picker(name, opts)
    return function() require('telescope.builtin')[name](opts) end
end

return {
    'nvim-telescope/telescope.nvim',
    version = '*',
    dependencies = {
        'nvim-lua/plenary.nvim',
        { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    },
    cmd = 'Telescope',
    keys = {
        { '<leader>ff', picker('find_files'), desc = 'Find files' },
        { '<leader>fg', picker('live_grep'), desc = 'Live grep' },
        { '<leader>fb', picker('buffers'), desc = 'Find buffers' },
        { '<leader>fh', picker('help_tags'), desc = 'Help tags' },
        { '<leader>ft', picker('colorscheme', { enable_preview = true }), desc = 'Browse colorschemes (live preview)' },
    },
    config = function()
        local telescope = require('telescope')
        telescope.setup({})
        -- Native fzf sorter: faster, and understands fzf syntax ('exact ^prefix !not).
        telescope.load_extension('fzf')
    end,
}
