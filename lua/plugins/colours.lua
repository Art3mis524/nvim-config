return {
    {
	"Art3mis524/cyberpunk",
	config = function ()
	    require("cyberpunk").setup({
		code_style = {
		    keywords = "bold",
		},
	    })
	    vim.cmd.colorscheme "cyberpunkNeon"
	end
    },
    {
	"nvim-lualine/lualine.nvim",
	dependencies = {
	    "nvim-tree/nvim-web-devicons",
	},
	opts = {
	    theme = 'cyberpunk',
	    sections = {
		lualine_c = {
		    { 'filename', path = 1 },
		},
	    },
	}
    },
}
