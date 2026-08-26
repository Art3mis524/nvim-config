return {
    {
	"navarasu/onedark.nvim",
	config = function ()
	    require("onedark").setup({
		style = "dark",
	    })
	    vim.cmd.colorscheme "onedark"
	end
    },
    {
	"nvim-lualine/lualine.nvim",
	dependencies = {
	    "nvim-tree/nvim-web-devicons",
	},
	opts = {
	    theme = 'onedark',
	    sections = {
		lualine_c = {
		    { 'filename', path = 1 },
		},
	    },
	}
    },
}
