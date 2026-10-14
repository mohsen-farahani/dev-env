-- Mason-managed tools (only things Homebrew / pinned installers don't cover).
-- Go tools, shellcheck, shfmt, stylua come from Homebrew; netcoredbg & roslyn from scripts/install.sh.
local M = {}

M.packages = {
  "basedpyright",
  "ruff",
  "bash-language-server",
  "lua-language-server",
  "typescript-language-server",
  "debugpy",
  "js-debug-adapter",
}

--- Install missing packages synchronously (headless use). With update=true, also upgrade.
function M.install_sync(update)
  local registry = require("mason-registry")
  local done, err = false, nil
  registry.refresh(function(ok, e)
    done, err = true, (not ok) and e or nil
  end)
  vim.wait(60000, function()
    return done
  end, 100)
  if err then
    io.stderr:write("mason registry refresh failed: " .. tostring(err) .. "\n")
  end
  local failed = {}
  for _, name in ipairs(M.packages) do
    local ok, pkg = pcall(registry.get_package, name)
    if not ok then
      failed[#failed + 1] = name .. " (not in registry)"
    else
      local need = not pkg:is_installed()
      if not need and update then
        local latest = pkg:get_latest_version()
        local cur = pkg:get_installed_version()
        need = latest ~= cur
      end
      if need then
        io.stdout:write("mason: installing " .. name .. "\n")
        local finished = false
        local handle = pkg:install()
        handle:once("closed", function()
          finished = true
        end)
        vim.wait(600000, function()
          return finished
        end, 200)
        if not pkg:is_installed() then
          failed[#failed + 1] = name
        end
      end
    end
  end
  if #failed > 0 then
    io.stderr:write("mason: FAILED: " .. table.concat(failed, ", ") .. "\n")
    vim.cmd("cquit 1")
  end
end

return M
