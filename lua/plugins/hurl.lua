-- REST client: write requests in .hurl files and run them with the hurl CLI
-- (installed by the install scripts, along with jq for pretty-printing JSON
-- responses). Keys only exist in .hurl buffers.

-- hurl.nvim finds the request under the cursor from the treesitter tree, and
-- reports "no HTTP method found" if that tree hasn't been built yet (e.g.
-- right after opening a file), so build it first.
local function at_cursor(cmd)
    return function()
        local ok, parser = pcall(vim.treesitter.get_parser)
        if ok and parser then parser:parse() end
        vim.cmd(cmd)
    end
end

return {
    'jellydn/hurl.nvim',
    dependencies = {
        'MunifTanjim/nui.nvim',
        'nvim-lua/plenary.nvim',
        'nvim-treesitter/nvim-treesitter',
    },
    ft = 'hurl',
    opts = {
        -- Response opens in a split on the right; q closes it.
        mode = 'split',
    },
    keys = {
        { '<leader>ha', at_cursor('HurlRunnerAt'),       ft = 'hurl', desc = 'Hurl: run request under cursor' },
        { '<leader>ha', ':HurlRunner<CR>',               ft = 'hurl', desc = 'Hurl: run selected requests',   mode = 'x' },
        { '<leader>hA', '<cmd>HurlRunner<CR>',           ft = 'hurl', desc = 'Hurl: run all requests in file' },
        { '<leader>hv', at_cursor('HurlVerbose'),        ft = 'hurl', desc = 'Hurl: run request under cursor (verbose)' },
        { '<leader>hl', '<cmd>HurlShowLastResponse<CR>', ft = 'hurl', desc = 'Hurl: show last response' },
        { '<leader>hm', '<cmd>HurlToggleMode<CR>',       ft = 'hurl', desc = 'Hurl: toggle split/popup' },
    },
}
