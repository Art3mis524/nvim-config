-- Rendered markdown in the buffer, toggled with <leader>p.
return {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    ft = 'markdown',
    keys = {
        { '<leader>p', '<cmd>RenderMarkdown toggle<cr>', ft = 'markdown', desc = 'Toggle markdown preview' },
    },
    opts = {
        -- Fully rendered or fully raw: render in every mode (visual too, so
        -- selecting doesn't flip lines back to raw and shift the text), and
        -- don't reveal the raw markdown on the cursor line.
        render_modes = true,
        anti_conceal = { enabled = false },
    },
}
