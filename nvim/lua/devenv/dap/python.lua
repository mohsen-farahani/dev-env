-- debugpy (installed by Mason in its own venv) via nvim-dap-python. Project venvs are auto-detected.
local M = {}

function M.setup(dap)
  local py = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "packages", "debugpy", "venv", "bin", "python")
  if vim.fn.executable(py) ~= 1 then
    M.missing = true
    return
  end
  require("dap-python").setup(py)
  require("dap-python").test_runner = "pytest"
end

return M
