return {
    -- Treesitter-aware comment strings for gc/gcc (e.g. JSX vs JS in one file).
    {
        'folke/ts-comments.nvim',
        event = 'VeryLazy',
        opts = {},
    },

    -- Multiple cursors.
    {
        'jake-stewart/multicursor.nvim',
        branch = '1.0',
        config = function()
            local mc = require('multicursor-nvim')
            mc.setup()
            local set = vim.keymap.set

            -- Same keys as vim-visual-multi, kept for muscle memory.
            set({ 'n', 'x' }, '<C-n>', function() mc.matchAddCursor(1) end, { desc = 'Add cursor at next match' })
            set({ 'n', 'x' }, '<C-Down>', function() mc.lineAddCursor(1) end, { desc = 'Add cursor below' })
            set({ 'n', 'x' }, '<C-Up>', function() mc.lineAddCursor(-1) end, { desc = 'Add cursor above' })
            set('n', '<C-LeftMouse>', mc.handleMouse)
            set('n', '<C-LeftDrag>', mc.handleMouseDrag)
            set('n', '<C-LeftRelease>', mc.handleMouseRelease)
            -- Keyboard version of Ctrl-click: add/remove a cursor here.
            set({ 'n', 'x' }, '<C-q>', mc.toggleCursor, { desc = 'Toggle cursor here' })

            -- Only while several cursors exist, so normal Esc is untouched.
            mc.addKeymapLayer(function(layer_set)
                layer_set({ 'n', 'x' }, '<Esc>', function()
                    if mc.cursorsEnabled() then mc.clearCursors() else mc.enableCursors() end
                end)
            end)
        end,
    },
}
