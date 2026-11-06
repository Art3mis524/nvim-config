-- PHP (intelephense).
return {
    cmd = { 'intelephense', '--stdio' },
    filetypes = { 'php' },
    root_markers = { 'composer.json', '.git' },
    settings = {
        intelephense = {
            files = { maxSize = 5000000 },
        },
    },
}
