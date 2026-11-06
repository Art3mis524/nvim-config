-- Java (eclipse.jdt.ls), set up natively rather than with nvim-jdtls. Its
-- client-side extras (opening jdt:// class files, workspace-edit commands)
-- are in lua/config/jdtls.lua.
return {
    -- jdtls keeps its project index in a "workspace" (-data) directory, and
    -- two projects sharing one confuse it, so give each project root its own
    -- under Neovim's cache dir. That depends on the root, hence a function.
    cmd = function(dispatchers, config)
        local root = config.root_dir or vim.fn.getcwd()
        local data_dir = vim.fn.stdpath('cache') .. '/jdtls/'
            .. vim.fn.fnamemodify(root, ':t') .. '-' .. vim.fn.sha256(root):sub(1, 8)
        return vim.lsp.rpc.start({ 'jdtls', '-data', data_dir }, dispatchers, {
            cwd = config.cmd_cwd,
            env = config.cmd_env,
            detached = config.detached,
        })
    end,
    filetypes = { 'java' },
    -- Build-wrapper/settings files first, so a multi-module project's top
    -- level wins over a submodule's own pom.xml/build.gradle. With no marker,
    -- use the file's own directory: without a root, jdtls treats the file as
    -- a "non-project file" and only reports syntax errors.
    root_dir = function(bufnr, on_dir)
        local root = vim.fs.root(bufnr, {
            { 'mvnw', 'gradlew', 'settings.gradle', 'settings.gradle.kts', '.git' },
            { 'pom.xml', 'build.gradle', 'build.gradle.kts', 'build.xml' },
        })
        on_dir(root or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
    end,
    init_options = {
        -- Lets go-to-definition into JDK/library classes return jdt:// URIs,
        -- which lua/config/jdtls.lua knows how to open.
        extendedClientCapabilities = { classFileContentsSupport = true },
    },
    settings = {
        java = {
            signatureHelp = { enabled = true },
            -- Decompile classes that have no source jar.
            contentProvider = { preferred = 'fernflower' },
        },
    },
}
