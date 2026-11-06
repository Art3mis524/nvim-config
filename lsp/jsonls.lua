-- JSON and JSONC (vscode-langservers-extracted; the older standalone
-- vscode-json-languageserver package can't format at all).
return {
    cmd = { 'vscode-json-language-server', '--stdio' },
    filetypes = { 'json', 'jsonc' },
    root_markers = { 'package.json', '.git', 'config.jsonc' },
    init_options = { provideFormatter = true }, -- only formats when asked to
}
