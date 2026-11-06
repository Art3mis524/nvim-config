-- Zig.
return {
    cmd = { 'zls' },
    filetypes = { 'zig', 'zir' },
    root_markers = { 'zls.json', 'build.zig', '.git' },
    settings = {
        zls = {
            enable_build_on_save = true,
            build_on_save_step = 'install',
            warn_style = false,
            enable_snippets = true,
        },
    },
}
