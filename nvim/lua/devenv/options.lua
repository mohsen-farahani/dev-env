local o = vim.opt

o.number = true
o.relativenumber = true
o.mouse = "a"
o.clipboard = "unnamedplus"
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.signcolumn = "yes"
o.updatetime = 250
o.termguicolors = true
o.undofile = true
o.ignorecase = true
o.smartcase = true
o.splitright = true
o.splitbelow = true
o.scrolloff = 8
o.cursorline = true
o.timeoutlen = 400
o.confirm = true
o.winborder = "rounded"

vim.diagnostic.config({
  severity_sort = true,
  update_in_insert = false,
  underline = true,
  virtual_text = { source = "if_many", spacing = 2 },
  float = { source = true, border = "rounded" },
  signs = true,
})

-- Per-language indentation (Go uses gofmt's tabs).
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("devenv_indent", { clear = true }),
  pattern = {
    "lua",
    "typescript",
    "typescriptreact",
    "javascript",
    "javascriptreact",
    "json",
    "yaml",
    "sh",
    "bash",
    "html",
    "css",
  },
  callback = function()
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = "devenv_indent",
  pattern = "go",
  callback = function()
    vim.bo.expandtab = false
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
  end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank()
  end,
})
