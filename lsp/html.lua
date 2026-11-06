-- HTML (vscode-langservers-extracted). Formats with the buffer's indent width,
-- which after/ftplugin/html.lua sets to 2.
return {
    cmd = { 'vscode-html-language-server', '--stdio' },
    filetypes = { 'html' },
    root_markers = { 'package.json', '.git' },
    init_options = {
        provideFormatter = true,
        -- Also format and complete <style> and <script> blocks.
        embeddedLanguages = { css = true, javascript = true },
        configurationSection = { 'html', 'css', 'javascript' },
    },
}
