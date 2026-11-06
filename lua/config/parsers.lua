-- Treesitter parsers to keep installed: plugins/treesitter.lua installs them,
-- scripts/check-parsers.lua (the install scripts) and tests/smoke.lua verify
-- them. (jsonc files use the json parser, so it isn't listed separately.)
return {
    'typescript', 'tsx', 'javascript',
    'html', 'css', 'json',
    'lua', 'markdown', 'markdown_inline', 'bash',
    'c', 'cpp', 'cmake', 'make', 'glsl',
    'java', 'hurl',
}
