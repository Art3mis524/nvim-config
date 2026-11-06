-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out,                            "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
    -- The clone gets whatever stable is today; check out the commit pinned in
    -- lazy-lock.json so a fresh install matches it (and doesn't rewrite it).
    local ok, pinned = pcall(function()
        local lock = vim.fn.readfile(vim.fn.stdpath("config") .. "/lazy-lock.json")
        return vim.json.decode(table.concat(lock, "\n"))["lazy.nvim"].commit
    end)
    if ok and pinned then
        vim.fn.system({ "git", "-C", lazypath, "checkout", "--quiet", pinned })
    end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    spec = {
        -- import your plugins
        { import = "plugins" },
    },
    change_detection = { notify = false },
    -- No plugins here need luarocks; disabling it avoids a hererocks error.
    rocks = { enabled = false },
})
