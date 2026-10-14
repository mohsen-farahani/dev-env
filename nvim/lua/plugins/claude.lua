-- Existing Claude Code workflow, preserved unchanged (<leader>ac).
return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    cmd = { "ClaudeCode" },
    keys = { { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude Code" } },
    config = true,
  },
  {
    "folke/snacks.nvim",
    lazy = false,
    priority = 900,
    opts = { terminal = { enabled = true } },
    keys = {
      {
        "<leader>tt",
        function()
          Snacks.terminal.toggle()
        end,
        desc = "Toggle terminal",
      },
    },
  },
}
