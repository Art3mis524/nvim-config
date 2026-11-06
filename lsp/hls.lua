-- Haskell, formatted with fourmolu.
return {
    cmd = { 'haskell-language-server-wrapper', '--lsp' },
    filetypes = { 'haskell', 'lhaskell' },
    root_markers = { 'stack.yaml', 'cabal.project', 'package.yaml', '*.cabal', 'hie.yaml', '.git' },
    settings = {
        haskell = {
            formattingProvider = 'fourmolu',
            plugin = { semanticTokens = { globalOn = false } },
        },
    },
}
