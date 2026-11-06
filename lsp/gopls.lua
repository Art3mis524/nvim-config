-- Go.
return {
    cmd = { 'gopls' },
    filetypes = { 'go', 'gomod', 'gowork' },
    root_markers = { 'go.mod', 'go.work', '.git' },
    settings = {
        gopls = {
            analyses = {
                unusedparams = false,
                ST1003 = false, -- naming style
                ST1000 = false, -- package comments
            },
            staticcheck = true,
        },
    },
}
