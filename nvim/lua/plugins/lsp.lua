return {
  {
    -- Provides server definitions (lsp/*.lua); activation uses the built-in vim.lsp.enable().
    "neovim/nvim-lspconfig",
    lazy = false,
  },
  {
    "mason-org/mason.nvim",
    lazy = false,
    priority = 800,
    opts = {},
  },
  {
    -- Neovim API awareness for lua_ls
    "folke/lazydev.nvim",
    ft = "lua",
    opts = { library = { { path = "${3rd}/luv/library", words = { "vim%.uv" } } } },
  },
  {
    -- Roslyn C# language server client. Server binary comes from scripts/install.sh (see devenv/lsp.lua).
    "seblyng/roslyn.nvim",
    ft = { "cs" },
    opts = { filewatching = "auto", broad_search = false },
  },
}
