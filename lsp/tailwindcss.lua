-- Tailwind CSS class completion and linting.
return {
    cmd = { 'tailwindcss-language-server', '--stdio' },
    filetypes = { 'html', 'css', 'scss', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    root_markers = { 'tailwind.config.js', 'tailwind.config.ts', 'package.json', '.git' },
}
