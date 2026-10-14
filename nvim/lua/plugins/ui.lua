return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("tokyonight-night")
    end,
  },
  { "nvim-tree/nvim-web-devicons", lazy = true },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      sections = {
        lualine_c = { { "filename", path = 1 } },
        lualine_x = {
          function()
            local ok, dap = pcall(require, "dap")
            if ok and dap.session() then
              return " " .. dap.status()
            end
            return ""
          end,
          "encoding",
          "filetype",
        },
      },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      spec = {
        { "<leader>f", group = "find" },
        { "<leader>c", group = "code" },
        { "<leader>d", group = "debug" },
        { "<leader>t", group = "test/build/terminal" },
        { "<leader>g", group = "git" },
        { "<leader>a", group = "ai" },
        { "<leader>u", group = "toggles" },
      },
    },
  },
}
