-- ESLint (vscode-langservers-extracted).
return {
    cmd = { 'vscode-eslint-language-server', '--stdio' },
    filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    root_markers = { 'eslint.config.js', '.eslintrc.json', '.eslintrc.js', 'package.json', '.git' },
    settings = {
        workingDirectory = { mode = 'auto' },
    },
    -- Pull diagnostics crash in some Next.js projects; pushed ones still
    -- work (see the textDocument/diagnostic handler in config/lsp.lua).
    on_init = function(client)
        client.server_capabilities.diagnosticProvider = nil
    end,
}
