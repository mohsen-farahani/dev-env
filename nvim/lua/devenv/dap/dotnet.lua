-- netcoredbg (Samsung) over DAP (stdio, --interpreter=vscode).
-- Binary: scripts/install.sh installs a pinned, checksum-verified native arm64 build (NOT Mason; its
-- darwin_arm64 package ships the amd64 binary).
local paths = require("devenv.paths")
local M = {}

local last = { project = nil, args = nil }

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "dotnet debug" })
end

--- Directory to search for projects: solution root, else project root, else cwd.
local function search_root()
  local sln, proj = require("devenv.run").dotnet_root()
  if sln then
    return vim.fs.dirname(sln)
  end
  if proj then
    return vim.fs.dirname(proj)
  end
  return vim.uv.cwd()
end

--- All runnable (Exe / Web / Worker) projects under root.
function M.runnable_projects(root)
  local found = vim.fs.find(function(name, path)
    if not name:match("%.csproj$") then
      return false
    end
    return not path:find("/bin/") and not path:find("/obj/")
  end, { path = root, type = "file", limit = math.huge })
  local out = {}
  for _, f in ipairs(found) do
    local text = table.concat(vim.fn.readfile(f), "\n")
    if
      text:match("<OutputType>%s*Exe")
      or text:match('Sdk="Microsoft%.NET%.Sdk%.Web"')
      or text:match('Sdk="Microsoft%.NET%.Sdk%.Worker"')
    then
      out[#out + 1] = f
    end
  end
  return out
end

--- Build a project, then resolve its output dll via MSBuild (works for any TFM/output path).
local function build_and_resolve(proj, cb)
  notify("Building " .. vim.fs.basename(proj) .. " …")
  vim.system(
    { "dotnet", "build", proj, "--nologo", "-v", "q", "-clp:NoSummary" },
    { text = true },
    vim.schedule_wrap(function(b)
      if b.code ~= 0 then
        vim.fn.setqflist({}, " ", {
          title = "dotnet build",
          lines = vim.split((b.stdout or "") .. (b.stderr or ""), "\n"),
          efm = "%f(%l\\,%c): %trror %m,%f(%l\\,%c): %tarning %m,%-G%.%#",
        })
        vim.cmd("copen")
        return notify("Build failed; debugging aborted", vim.log.levels.ERROR)
      end
      vim.system(
        { "dotnet", "msbuild", proj, "-getProperty:TargetPath", "-nologo" },
        { text = true },
        vim.schedule_wrap(function(r)
          local dll = vim.trim(r.stdout or "")
          if r.code ~= 0 or dll == "" or not vim.uv.fs_stat(dll) then
            return notify("Could not resolve output dll for " .. proj .. "\n" .. (r.stderr or ""), vim.log.levels.ERROR)
          end
          cb(dll)
        end)
      )
    end)
  )
end

local function run_session(proj, args)
  build_and_resolve(proj, function(dll)
    require("dap").run({
      type = "coreclr",
      name = "Launch " .. vim.fs.basename(proj),
      request = "launch",
      program = dll,
      args = args,
      cwd = vim.fs.dirname(proj),
      stopAtEntry = false,
      env = { DOTNET_ENVIRONMENT = "Development", ASPNETCORE_ENVIRONMENT = "Development" },
    })
  end)
end

function M.launch()
  if vim.fn.executable(paths.netcoredbg) ~= 1 then
    return notify("netcoredbg not found at " .. paths.netcoredbg .. "\nRun scripts/install.sh", vim.log.levels.ERROR)
  end
  local projects = M.runnable_projects(search_root())
  if #projects == 0 then
    return notify("No runnable (Exe/Web/Worker) .csproj found under " .. search_root(), vim.log.levels.WARN)
  end

  local function with_project(proj)
    if not proj then
      return
    end
    last.project = proj
    vim.ui.input({ prompt = "Arguments: ", default = last.args or "" }, function(input)
      if input == nil then
        return
      end
      last.args = input
      run_session(proj, input == "" and {} or vim.split(input, "%s+"))
    end)
  end
  if #projects == 1 then
    return with_project(projects[1])
  end
  vim.ui.select(projects, {
    prompt = "Debug which project?",
    format_item = function(p)
      return vim.fs.relpath(search_root(), p) or p
    end,
  }, with_project)
end

function M.attach()
  require("dap").run({
    type = "coreclr",
    name = "Attach",
    request = "attach",
    processId = require("dap.utils").pick_process({ filter = "dotnet" }),
  })
end

function M.setup(dap)
  dap.adapters.coreclr = {
    type = "executable",
    command = paths.netcoredbg,
    args = { "--interpreter=vscode" },
  }
  -- Listed so :DapContinue / telescope-dap style pickers show something; F5 uses M.launch() instead.
  dap.configurations.cs = {
    {
      type = "coreclr",
      name = "Attach (pick dotnet process)",
      request = "attach",
      processId = require("dap.utils").pick_process,
    },
  }
end

return M
