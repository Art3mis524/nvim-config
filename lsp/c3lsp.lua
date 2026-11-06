-- C3.
return {
    -- Upstream's binary is c3lsp; some packages name it c3-lsp.
    cmd = { vim.fn.executable('c3lsp') == 1 and 'c3lsp' or 'c3-lsp' },
    filetypes = { 'c3' },
    root_markers = { 'project.json', '.git' },
}
