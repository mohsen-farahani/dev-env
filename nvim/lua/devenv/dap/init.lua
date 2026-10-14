-- nvim-dap wiring. Adapters per language live in sibling modules.
local M = {}

function M.setup()
  local dap = require("dap")
  local dapui = require("dapui")
  dapui.setup()

  dap.listeners.after.event_initialized["devenv_ui"] = function()
    dapui.open()
  end
  dap.listeners.before.event_terminated["devenv_ui"] = function()
    dapui.close()
  end
  dap.listeners.before.event_exited["devenv_ui"] = function()
    dapui.close()
  end

  vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
  vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticOk", linehl = "Visual" })

  require("devenv.dap.go").setup(dap)
  require("devenv.dap.dotnet").setup(dap)
  require("devenv.dap.python").setup(dap)
  require("devenv.dap.node").setup(dap)
end

--- F5 / <leader>dc: continue if a session exists, else start one for the current filetype.
function M.continue()
  local dap = require("dap")
  if dap.session() then
    return dap.continue()
  end
  if vim.bo.filetype == "cs" then
    return require("devenv.dap.dotnet").launch()
  end
  dap.continue()
end

function M.attach()
  if vim.bo.filetype == "cs" then
    return require("devenv.dap.dotnet").attach()
  end
  require("dap").continue()
end

function M.debug_test()
  local ft = vim.bo.filetype
  if ft == "go" then
    return require("devenv.dap.go").debug_test()
  end
  if ft == "python" then
    return require("dap-python").test_method()
  end
  vim.notify("Debug test: not implemented for filetype '" .. ft .. "'", vim.log.levels.WARN)
end

return M
