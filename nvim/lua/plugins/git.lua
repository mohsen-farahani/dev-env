-- Git inside the editor is limited to line blame/gutter signs. Use the git CLI for everything else.
return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      current_line_blame = true,
      current_line_blame_opts = { delay = 400, virt_text_pos = "eol" },
      current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary> (<abbrev_sha>)",
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local map = function(lhs, rhs, desc)
          vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc })
        end
        map("<leader>gb", function()
          gs.blame_line({ full = true })
        end, "Blame line (full commit)")
        map("<leader>gB", gs.toggle_current_line_blame, "Toggle inline blame")
        map("]h", function()
          gs.nav_hunk("next")
        end, "Next hunk")
        map("[h", function()
          gs.nav_hunk("prev")
        end, "Previous hunk")
        map("<leader>gp", gs.preview_hunk, "Preview hunk")
      end,
    },
  },
}
