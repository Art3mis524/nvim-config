-- Treesitter parsers to keep installed. Shared by plugins/treesitter.lua, the
-- install scripts and tests/smoke.lua so they can install and verify them.
-- (jsonc files use the json parser, so it isn't listed separately.)
return {
    'typescript', 'tsx', 'javascript',
    'html', 'css', 'json',
    'lua', 'markdown', 'markdown_inline', 'bash',
    'c', 'cpp', 'cmake', 'make', 'glsl',
    'java', 'hurl',
}
