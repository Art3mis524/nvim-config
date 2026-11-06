-- Options and the leader key come first, so plugins see them as they load;
-- LSP comes last because it uses nvim-cmp's capabilities.
require('config.options')
require('config.keybinds')
require('config.lazy')
require('config.lsp')
