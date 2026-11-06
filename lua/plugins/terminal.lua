-- Terminal docked on the right (40% wide), toggled with Ctrl-\.
return {
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
        -- Windows defaults to cmd.exe; prefer PowerShell 7, then 5.1.
        shell = vim.fn.has('win32') == 1
            and (vim.fn.executable('pwsh') == 1 and 'pwsh' or 'powershell')
            or vim.o.shell,
    },
}
