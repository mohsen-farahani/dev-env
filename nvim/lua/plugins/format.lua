-- The ONLY formatting hook. Do not add BufWritePre formatters elsewhere.
return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    opts = {
      formatters_by_ft = {
        go = { "goimports", "gofmt" },
        python = { "ruff_organize_imports", "ruff_format" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        lua = { "stylua" },
        javascript = { "prettier", lsp_format = "fallback" },
        javascriptreact = { "prettier", lsp_format = "fallback" },
        typescript = { "prettier", lsp_format = "fallback" },
        typescriptreact = { "prettier", lsp_format = "fallback" },
        json = { "prettier", lsp_format = "fallback" },
        -- cs: no external formatter; Roslyn LSP formats (lsp_format = "fallback" below)
      },
      format_on_save = function(bufnr)
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return
        end
        return { timeout_ms = 3000, lsp_format = "fallback" }
      end,
      notify_on_error = true,
      notify_no_formatters = false,
    },
    init = function()
      vim.keymap.set({ "n", "v" }, "<leader>cf", function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end, { desc = "Format buffer/selection" })
      vim.keymap.set("n", "<leader>uf", function()
        vim.g.disable_autoformat = not vim.g.disable_autoformat
        vim.notify("Format on save: " .. (vim.g.disable_autoformat and "OFF" or "ON"))
      end, { desc = "Toggle format on save" })
    end,
  },
}
