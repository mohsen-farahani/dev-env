-- Locations of tools installed by scripts/install.sh (outside Mason, pinned & verified).
local M = {}

M.data = vim.env.DEVENV_DATA or vim.fs.joinpath(vim.env.HOME, ".local", "share", "dev-env")
M.bin = vim.fs.joinpath(M.data, "bin")
M.netcoredbg = vim.fs.joinpath(M.data, "netcoredbg", "netcoredbg")
M.roslyn = vim.fs.joinpath(M.data, "roslyn", "roslyn-language-server")

function M.setup()
  if not vim.env.PATH:find(M.bin, 1, true) then
    vim.env.PATH = M.bin .. ":" .. vim.env.PATH
  end
end

return M
