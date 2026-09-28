-- Treesitter parsers to keep installed. Shared by plugins/treesitter.lua, the
-- install script and tests/smoke.lua so they can install and verify them.
return {
    'lua', 'markdown', 'markdown_inline',
    'c', 'cpp', 'cmake', 'make',
}
