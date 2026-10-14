-- lazy.nvim bootstrap. Plugin versions are pinned by nvim/lazy-lock.json.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { "Failed to clone lazy.nvim:\n" .. out, "ErrorMsg" } }, true, {})
    return
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins", {
  install = { missing = vim.env.DEVENV_NO_INSTALL == nil, colorscheme = { "tokyonight-night", "habamax" } },
  checker = { enabled = false },
  change_detection = { notify = false },
  rocks = { enabled = false },
  performance = { rtp = { disabled_plugins = { "netrwPlugin" } } },
})
