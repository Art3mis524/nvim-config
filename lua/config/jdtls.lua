-- Client-side pieces of jdtls support that nvim-jdtls would normally
-- provide. The server config itself is lsp/jdtls.lua.

-- Some jdtls code actions come back as this client-side command rather than
-- a plain workspace edit.
vim.lsp.commands['java.apply.workspaceEdit'] = function(command, ctx)
    local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
    for _, edit in ipairs(command.arguments or {}) do
        vim.lsp.util.apply_workspace_edit(edit, client.offset_encoding)
    end
end

-- Open jdt:// URIs (classes inside jars and the JDK) by asking jdtls for
-- their source, or a decompiled version when there's none.
vim.api.nvim_create_autocmd('BufReadCmd', {
    group = vim.api.nvim_create_augroup('my.jdtls', {}),
    pattern = 'jdt://*',
    callback = function(args)
        local client = vim.lsp.get_clients({ name = 'jdtls' })[1]
        if not client then
            vim.notify('jdtls is not running, cannot open ' .. args.match, vim.log.levels.WARN)
            return
        end
        local res = client:request_sync('java/classFileContents', { uri = args.match }, 10000, args.buf)
        if not res or res.err or type(res.result) ~= 'string' then
            vim.notify('jdtls could not load ' .. args.match, vim.log.levels.WARN)
            return
        end
        local bo = vim.bo[args.buf]
        bo.modifiable = true
        vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, vim.split(res.result, '\r?\n'))
        bo.swapfile = false
        bo.buftype = 'nofile'
        bo.modifiable = false
        bo.filetype = 'java'
        vim.lsp.buf_attach_client(args.buf, client.id)
    end,
})
