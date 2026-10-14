-- Node.js via VS Code's js-debug (Mason: js-debug-adapter). TypeScript runs through its compiled output
-- (source maps enabled) or a runner such as tsx; see docs/USAGE.md.
local M = {}

function M.setup(dap)
  dap.adapters["pwa-node"] = {
    type = "server",
    host = "localhost",
    port = "${port}",
    executable = { command = "js-debug-adapter", args = { "${port}" } },
  }
  for _, ft in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
    dap.configurations[ft] = {
      {
        type = "pwa-node",
        request = "launch",
        name = "Launch file (node)",
        program = "${file}",
        cwd = "${workspaceFolder}",
        sourceMaps = true,
      },
      {
        type = "pwa-node",
        request = "attach",
        name = "Attach (pick node process)",
        processId = require("dap.utils").pick_process,
        cwd = "${workspaceFolder}",
      },
    }
  end
end

return M
