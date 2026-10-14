-- Project-aware build / test / format commands for .NET, Go and Python.
-- Output goes to the quickfix list (builds) or a terminal split (tests/run).
local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "devenv" })
end

--- Run in a bottom terminal split.
function M.term(cmd, cwd)
  vim.cmd("botright 14split")
  vim.fn.jobstart(cmd, { term = true, cwd = cwd })
  vim.cmd("startinsert")
end

--- Run asynchronously, parse output into quickfix with `efm`. Opens it only on problems.
function M.qf(cmd, cwd, efm, title)
  notify("Running: " .. table.concat(cmd, " "))
  vim.system(
    cmd,
    { cwd = cwd, text = true },
    vim.schedule_wrap(function(res)
      local out = (res.stdout or "") .. (res.stderr or "")
      vim.fn.setqflist({}, " ", { title = title or table.concat(cmd, " "), lines = vim.split(out, "\n"), efm = efm })
      if res.code ~= 0 then
        vim.cmd("copen")
        notify(title .. " FAILED (exit " .. res.code .. ")", vim.log.levels.ERROR)
      else
        vim.cmd("cclose")
        notify(title .. " succeeded")
      end
    end)
  )
end

-- ---------- .NET ----------
local MSBUILD_EFM = table.concat({
  "%f(%l\\,%c): %trror %m",
  "%f(%l\\,%c): %tarning %m",
  "%-G%.%#",
}, ",")

function M.dotnet_root(buf)
  local name = vim.api.nvim_buf_get_name(buf or 0)
  local start = name ~= "" and vim.fs.dirname(name) or vim.uv.cwd()
  local sln = vim.fs.find(function(n)
    return n:match("%.slnx?$") ~= nil
  end, { path = start, upward = true, type = "file" })[1]
  local proj = vim.fs.find(function(n)
    return n:match("%.csproj$") ~= nil
  end, { path = start, upward = true, type = "file" })[1]
  return sln, proj
end

local function dotnet_target(prefer_project)
  local sln, proj = M.dotnet_root()
  local target = prefer_project and (proj or sln) or (sln or proj)
  if not target then
    notify("No .sln/.slnx/.csproj found above current file", vim.log.levels.WARN)
  end
  return target
end

function M.dotnet(sub, prefer_project)
  local target = dotnet_target(prefer_project)
  if not target then
    return
  end
  local cwd = vim.fs.dirname(target)
  if sub == "build" then
    M.qf({ "dotnet", "build", target, "--nologo", "-v", "q", "-clp:NoSummary" }, cwd, MSBUILD_EFM, "dotnet build")
  elseif sub == "format" then
    M.qf({ "dotnet", "format", target, "--verbosity", "minimal" }, cwd, MSBUILD_EFM, "dotnet format")
  elseif sub == "test" then
    M.term({ "dotnet", "test", target, "--nologo" }, cwd)
  elseif sub == "test-file" then
    local class = vim.fn.expand("%:t:r")
    M.term({ "dotnet", "test", target, "--nologo", "--filter", "FullyQualifiedName~" .. class }, cwd)
  end
end

-- ---------- Go ----------
local GO_EFM = "%f:%l:%c: %m,%f:%l: %m,%-G%.%#"

local function go_root()
  return vim.fs.root(0, { "go.work", "go.mod" }) or vim.uv.cwd()
end

--- Name of the Test/Benchmark/Fuzz function at or above the cursor.
function M.go_test_name()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  for l = row, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(0, l - 1, l, false)[1]
    local name = line:match("^func%s+(Test[%w_]*)%s*%(")
      or line:match("^func%s+(Benchmark[%w_]*)%s*%(")
      or line:match("^func%s+(Fuzz[%w_]*)%s*%(")
    if name then
      return name
    end
  end
end

function M.go(sub)
  local root = go_root()
  local pkg = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  local rel = "./" .. (vim.fs.relpath(root, pkg) or "")
  if sub == "build" then
    M.qf({ "go", "build", "./..." }, root, GO_EFM, "go build")
  elseif sub == "test" then
    M.term({ "go", "test", "-v", rel }, root)
  elseif sub == "test-all" then
    M.term({ "go", "test", "./..." }, root)
  elseif sub == "test-func" then
    local name = M.go_test_name()
    if not name then
      return notify("No Test function at cursor", vim.log.levels.WARN)
    end
    M.term({ "go", "test", "-v", "-run", "^" .. name .. "$", rel }, root)
  elseif sub == "run" then
    M.term({ "go", "run", rel }, root)
  end
end

-- ---------- Python ----------
function M.pytest(scope)
  local root = vim.fs.root(0, { "pyproject.toml", "pytest.ini", "setup.cfg", ".git" }) or vim.uv.cwd()
  local file = vim.api.nvim_buf_get_name(0)
  local cmd = { "pytest" }
  local venv_py = vim.fs.joinpath(root, ".venv", "bin", "pytest")
  if vim.uv.fs_stat(venv_py) then
    cmd = { venv_py }
  end
  if scope == "file" then
    cmd[#cmd + 1] = file
  end
  if scope == "func" then
    local row = vim.api.nvim_win_get_cursor(0)[1]
    for l = row, 1, -1 do
      local n = vim.api.nvim_buf_get_lines(0, l - 1, l, false)[1]:match("^%s*def%s+(test_[%w_]*)")
      if n then
        cmd[#cmd + 1] = file .. "::" .. n
        break
      end
    end
  end
  M.term(cmd, root)
end

function M.setup()
  local u = vim.api.nvim_create_user_command
  u("DotnetBuild", function()
    M.dotnet("build")
  end, { desc = "dotnet build (solution or project)" })
  u("DotnetTest", function()
    M.dotnet("test")
  end, { desc = "dotnet test (solution)" })
  u("DotnetTestProject", function()
    M.dotnet("test", true)
  end, { desc = "dotnet test (current project)" })
  u("DotnetTestFile", function()
    M.dotnet("test-file", true)
  end, { desc = "dotnet test filtered to current file's class" })
  u("DotnetFormat", function()
    M.dotnet("format")
  end, { desc = "dotnet format" })
  u("GoBuild", function()
    M.go("build")
  end, {})
  u("GoTest", function()
    M.go("test")
  end, { desc = "go test current package" })
  u("GoTestAll", function()
    M.go("test-all")
  end, {})
  u("GoTestFunc", function()
    M.go("test-func")
  end, { desc = "go test function at cursor" })
  u("GoRun", function()
    M.go("run")
  end, {})
  u("Pytest", function(o)
    M.pytest(o.args ~= "" and o.args or "all")
  end, { nargs = "?", desc = "pytest [file|func]" })

  -- Filetype-specific, consistent leader bindings: tb build, tn nearest test, tf file, tp project/package, tr run
  local grp = vim.api.nvim_create_augroup("devenv_run_keys", { clear = true })
  local function bind(ft, maps)
    vim.api.nvim_create_autocmd("FileType", {
      group = grp,
      pattern = ft,
      callback = function(ev)
        for lhs, spec in pairs(maps) do
          vim.keymap.set("n", lhs, spec[1], { buffer = ev.buf, desc = spec[2] })
        end
      end,
    })
  end
  bind("cs", {
    ["<leader>tb"] = {
      function()
        M.dotnet("build")
      end,
      "dotnet build",
    },
    ["<leader>tf"] = {
      function()
        M.dotnet("test-file", true)
      end,
      "dotnet test (file's class)",
    },
    ["<leader>tp"] = {
      function()
        M.dotnet("test", true)
      end,
      "dotnet test (project)",
    },
    ["<leader>tF"] = {
      function()
        M.dotnet("format")
      end,
      "dotnet format",
    },
  })
  bind("go", {
    ["<leader>tb"] = {
      function()
        M.go("build")
      end,
      "go build ./...",
    },
    ["<leader>tn"] = {
      function()
        M.go("test-func")
      end,
      "go test (function at cursor)",
    },
    ["<leader>tp"] = {
      function()
        M.go("test")
      end,
      "go test (package)",
    },
    ["<leader>tr"] = {
      function()
        M.go("run")
      end,
      "go run (package)",
    },
  })
  bind("python", {
    ["<leader>tn"] = {
      function()
        M.pytest("func")
      end,
      "pytest (function at cursor)",
    },
    ["<leader>tf"] = {
      function()
        M.pytest("file")
      end,
      "pytest (file)",
    },
    ["<leader>tp"] = {
      function()
        M.pytest("all")
      end,
      "pytest (project)",
    },
  })
end

return M
