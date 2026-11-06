-- C and C++. Formatting follows the nearest .clang-format (the install
-- scripts copy assets/clang-format-global to ~/.clang-format).

-- Compilers clangd may run to discover system include paths. On Windows
-- they live wherever Scoop/MSYS2 put them, so use whichever are on PATH
-- (forward slashes: --query-driver takes globs).
local function query_driver()
    if vim.fn.has('win32') == 0 then
        return '/usr/bin/clang*,/usr/bin/clang++*,/usr/bin/gcc*,/usr/bin/g++*,/usr/bin/cc*,/usr/bin/c++*'
    end
    local drivers = {}
    for _, exe in ipairs({ 'gcc', 'g++', 'clang', 'clang++' }) do
        local path = vim.fn.exepath(exe)
        if path ~= '' then table.insert(drivers, (path:gsub('\\', '/'))) end
    end
    return table.concat(drivers, ',')
end

return {
    cmd = {
        'clangd',
        '--background-index',
        '--clang-tidy',
        '--header-insertion=never',
        '--completion-style=detailed',
        '--function-arg-placeholders',
        '--query-driver=' .. query_driver(),
    },
    filetypes = { 'c', 'cpp', 'objc', 'objcpp' },
    root_markers = { 'compile_commands.json', '.clangd', 'configure.ac', 'Makefile', '.git' },
    init_options = {
        fallbackFlags = { '-std=c++17' },
    },
}
