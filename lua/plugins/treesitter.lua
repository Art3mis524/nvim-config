-- Treesitter parsers and highlighting (nvim-treesitter's main branch, which
-- doesn't support lazy-loading).
return {
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    config = function()
        -- tree-sitter-cli compiles parsers with Rust's cc crate, which on
        -- Windows looks for MSVC's cl.exe unless CC says otherwise. Use gcc
        -- (mingw, installed by install-windows.ps1) when MSVC isn't there.
        if vim.fn.has('win32') == 1 and not vim.env.CC
            and vim.fn.executable('cl') == 0 and vim.fn.executable('gcc') == 1 then
            vim.env.CC = 'gcc'
        end

        -- Install any parser from config/parsers.lua that's missing.
        local installed = require('nvim-treesitter.config').get_installed()
        local missing = vim.tbl_filter(function(lang)
            return not vim.list_contains(installed, lang)
        end, require('config.parsers'))
        if #missing > 0 then
            local task = require('nvim-treesitter').install(missing)
            -- Installs run in the background, and headless nvim (the install
            -- scripts) would quit before they finish, so wait there.
            if #vim.api.nvim_list_uis() == 0 then
                task:wait(600000)
            end
        end

        -- Highlight with treesitter wherever a parser exists.
        vim.api.nvim_create_autocmd('FileType', {
            group = vim.api.nvim_create_augroup('my.treesitter', {}),
            callback = function()
                pcall(vim.treesitter.start)
            end,
        })
    end,
}
