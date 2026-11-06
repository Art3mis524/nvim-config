-- JavaScript and TypeScript (typescript-language-server).

-- The server needs a tsserver.js and by default only looks in the project's
-- node_modules, so .ts files outside a project fail to start it. Fall back to
-- the global typescript the install scripts put next to tsc (pinned to 6.x:
-- TypeScript 7 is the native rewrite and ships no tsserver.js).
local function global_tsserver()
    local tsc = vim.fn.exepath('tsc')
    if tsc == '' then return nil end
    local lib = vim.fn.has('win32') == 1
        -- npm's Windows shims sit in the prefix dir, next to node_modules.
        and vim.fn.fnamemodify(tsc, ':h') .. '/node_modules/typescript/lib'
        or vim.fn.fnamemodify(vim.fn.resolve(tsc), ':h:h') .. '/lib'
    if vim.fn.filereadable(lib .. '/tsserver.js') == 1 then
        return { fallbackPath = lib }
    end
end

return {
    cmd = { 'typescript-language-server', '--stdio' },
    filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    root_markers = { 'package.json', 'tsconfig.json', 'jsconfig.json', '.git' },
    init_options = { tsserver = global_tsserver() },
    settings = {
        completions = { completeFunctionCalls = true },
    },
    on_init = function(client)
        -- Pull diagnostics crash in some Next.js projects; pushed ones still
        -- work (see the textDocument/diagnostic handler in config/lsp.lua).
        client.server_capabilities.diagnosticProvider = nil
        -- Leave highlighting to treesitter.
        client.server_capabilities.semanticTokensProvider = nil
    end,
}
