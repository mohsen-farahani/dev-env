-- Entry point. Everything lives in lua/devenv (settings) and lua/plugins (lazy.nvim specs).
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("devenv.options")
require("devenv.paths").setup()
require("devenv.lazy")
require("devenv.keymaps")
require("devenv.lsp")
require("devenv.run").setup()
