-- CSS, SCSS and Less (vscode-langservers-extracted).
return {
    cmd = { 'vscode-css-language-server', '--stdio' },
    filetypes = { 'css', 'scss', 'less' },
    root_markers = { 'package.json', '.git' },
    init_options = { provideFormatter = true }, -- only formats when asked to
    settings = {
        css = { validate = true },
        scss = { validate = true },
        less = { validate = true },
    },
}
