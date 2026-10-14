-- Delve via `dlv dap`. IMPORTANT: dlv builds relative to ITS OWN cwd, so the adapter process must start in
-- the module root (verified: launching from elsewhere fails with "go: cannot find main module").
local M = {}

local function module_root()
  return vim.fs.root(0, { "go.work", "go.mod" }) or vim.uv.cwd()
end

function M.setup(dap)
  dap.adapters.go = function(callback, _)
    callback({
      type = "server",
      host = "127.0.0.1",
      port = "${port}",
      executable = {
        command = "dlv",
        args = { "dap", "-l", "127.0.0.1:${port}" },
        cwd = module_root(),
      },
    })
  end

  dap.configurations.go = {
    {
      type = "go",
      name = "Debug package of current file",
      request = "launch",
      mode = "debug",
      program = "${fileDirname}",
    },
    { type = "go", name = "Debug current file (main)", request = "launch", mode = "debug", program = "${file}" },
    { type = "go", name = "Debug tests in package", request = "launch", mode = "test", program = "${fileDirname}" },
    {
      type = "go",
      name = "Attach to process",
      request = "attach",
      mode = "local",
      processId = require("dap.utils").pick_process,
    },
  }
end

--- Debug the Test function at the cursor.
function M.debug_test()
  local name = require("devenv.run").go_test_name()
  if not name then
    return vim.notify("No Test function at cursor", vim.log.levels.WARN)
  end
  require("dap").run({
    type = "go",
    name = "Debug " .. name,
    request = "launch",
    mode = "test",
    program = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
    args = { "-test.run", "^" .. name .. "$" },
  })
end

return M
