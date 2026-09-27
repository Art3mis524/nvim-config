return {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
        -- tree-sitter-cli compiles parsers via Rust's cc crate, which on
        -- Windows looks for MSVC's cl.exe unless CC says otherwise. Point it
        -- at gcc (mingw, installed by install-windows.ps1) when MSVC isn't
        -- available.
        if vim.fn.has('win32') == 1 and not vim.env.CC
            and vim.fn.executable('cl') == 0 and vim.fn.executable('gcc') == 1 then
            vim.env.CC = 'gcc'
        end

        local wanted = require('config.parsers')
        local ts_config = require('nvim-treesitter.config')
        local installed = ts_config.get_installed()
        local installed_set = {}
        for _, p in ipairs(installed) do
            installed_set[p] = true
        end
        local missing = {}
        for _, p in ipairs(wanted) do
            if not installed_set[p] then
                table.insert(missing, p)
            end
        end
        if #missing > 0 then
            local task = require('nvim-treesitter').install(missing)
            -- Installs run in the background; headless nvim (the install
            -- script) would quit before they finish, so block there instead.
            if #vim.api.nvim_list_uis() == 0 then
                task:wait(600000)
            end
        end

        vim.api.nvim_create_autocmd('FileType', {
            callback = function()
                pcall(vim.treesitter.start)
            end,
        })
    end,
}
