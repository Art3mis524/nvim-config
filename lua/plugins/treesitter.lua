return {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
        local wanted = {
            'typescript', 'tsx', 'javascript',
            'html', 'css', 'json', 'jsonc',
            'lua', 'markdown', 'markdown_inline', 'bash',
            'c', 'cpp', 'cmake', 'make', 'glsl',
        }
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
            vim.cmd('TSInstall ' .. table.concat(missing, ' '))
        end

        vim.api.nvim_create_autocmd('FileType', {
            callback = function()
                pcall(vim.treesitter.start)
            end,
        })
    end,
}
