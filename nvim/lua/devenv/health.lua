-- Health checks. Used by `:checkhealth devenv` and by scripts/check.sh (headless, via M.run_cli()).
local paths = require("devenv.paths")
local M = {}

---@alias devenv.Result { level: "PASS"|"WARN"|"FAIL", msg: string }

local function sh(cmd)
  if type(cmd) == "string" then
    cmd = vim.split(cmd, " ", { trimempty = true })
  end
  local ok, res = pcall(function()
    return vim.system(cmd, { text = true }):wait(8000)
  end)
  if not ok or not res then
    return nil
  end
  return vim.trim((res.stdout or "") .. (res.stderr or ""))
end

local function first_line(s)
  return s and vim.split(s, "\n")[1] or "?"
end

function M.collect()
  local out = {}
  local function add(level, msg)
    out[#out + 1] = { level = level, msg = msg }
  end
  local function tool(name, opts)
    opts = opts or {}
    local exe = opts.exe or name
    if vim.fn.executable(exe) ~= 1 then
      add(
        opts.optional and "WARN" or "FAIL",
        ("%s: not found%s"):format(name, opts.hint and (" — " .. opts.hint) or "")
      )
      return false
    end
    local v = opts.version and first_line(sh(opts.version)) or vim.fn.exepath(exe)
    add("PASS", ("%s: %s"):format(name, v))
    return true
  end

  -- platform
  local u = vim.uv.os_uname()
  add("PASS", ("OS: %s %s (%s)"):format(u.sysname, u.release, u.machine))
  local v = vim.version()
  if vim.fn.has("nvim-0.12") == 1 then
    add("PASS", ("Neovim %d.%d.%d"):format(v.major, v.minor, v.patch))
  else
    add("FAIL", ("Neovim %d.%d.%d — need >= 0.12 (roslyn.nvim requirement)"):format(v.major, v.minor, v.patch))
  end
  tool("brew", { version = "brew --version", optional = true, hint = "needed only for installing tools" })

  -- core tools
  tool("git", { version = "git --version" })
  tool("rg", { version = "rg --version", hint = "brew install ripgrep (telescope live grep)" })
  tool("fd", { version = "fd --version", optional = true })
  tool("tree-sitter", { version = "tree-sitter --version", hint = "brew install tree-sitter-cli (syntax parsers)" })
  tool("cc", { optional = true, hint = "xcode-select --install (compile treesitter parsers)" })

  -- Go
  tool("go", { version = "go version", hint = "https://go.dev/dl or brew install go" })
  tool("gopls", { version = "gopls version" })
  tool("dlv", { version = "dlv version", hint = "brew install delve (Go debugger)" })
  tool("gofmt")
  tool("goimports", { optional = true, hint = "scripts/install.sh installs it into " .. paths.bin })

  -- .NET
  if
    tool(
      "dotnet",
      { version = "dotnet --version", hint = "brew install dotnet or https://dotnet.microsoft.com/download" }
    )
  then
    local sdks = sh({ "dotnet", "--list-sdks" })
    add("PASS", "dotnet SDKs: " .. (sdks and sdks:gsub("\n", "; ") or "?"))
  end
  if vim.fn.executable(paths.roslyn) == 1 then
    add("PASS", "roslyn-language-server: " .. paths.roslyn)
  else
    add("FAIL", "roslyn-language-server missing at " .. paths.roslyn .. " — run scripts/install.sh")
  end
  if vim.fn.executable(paths.netcoredbg) == 1 then
    local ver = first_line(sh({ paths.netcoredbg, "--version" }))
    local arch = sh({ "file", paths.netcoredbg }) or ""
    local host = vim.uv.os_uname().machine
    local native = (host == "arm64" and arch:find("arm64")) or (host == "x86_64" and arch:find("x86_64"))
    if native then
      add("PASS", ("netcoredbg: %s (native %s)"):format(ver, host))
    else
      add("FAIL", ("netcoredbg architecture mismatch (host %s): %s"):format(host, arch))
    end
  else
    local intel = vim.uv.os_uname().machine ~= "arm64"
    add(
      intel and "WARN" or "FAIL",
      "netcoredbg missing at "
        .. paths.netcoredbg
        .. (intel and " — no prebuilt Intel build; see docs/DOTNET.md" or " — run scripts/install.sh")
    )
  end

  -- Python / Node / Shell / Lua
  tool("python3", { version = "python3 --version" })
  tool("pytest", { optional = true, hint = "install in your project venv" })
  tool("node", { version = "node --version", optional = true, hint = "needed for TypeScript/JS servers & debugging" })
  tool("shellcheck", { version = "shellcheck --version", hint = "brew install shellcheck" })
  tool("shfmt", { version = "shfmt --version", hint = "brew install shfmt" })
  tool("stylua", { version = "stylua --version", hint = "brew install stylua" })
  add("PASS", "prettier: resolved per project from node_modules (not required globally)")

  -- language servers (Mason + PATH)
  local lsp = require("devenv.lsp")
  for name, exe in pairs(lsp.servers) do
    if vim.fn.executable(exe) == 1 then
      add("PASS", ("LSP %s: %s"):format(name, vim.fn.exepath(exe)))
    else
      add("FAIL", ("LSP %s: '%s' not found (scripts/install.sh installs Mason tools)"):format(name, exe))
    end
  end
  for _, d in ipairs({ "debugpy", "js-debug-adapter" }) do
    if vim.fn.executable(vim.fn.stdpath("data") .. "/mason/bin/" .. d) == 1 then
      add("PASS", "debug adapter " .. d .. " (Mason)")
    else
      add("WARN", "debug adapter " .. d .. " missing (Mason)")
    end
  end

  -- plugin manager
  local lazy_ok, lazy = pcall(require, "lazy")
  if lazy_ok then
    local st = lazy.stats()
    add("PASS", ("lazy.nvim: %d plugins, %d loaded at startup"):format(st.count, st.loaded))
    local missing = {}
    for _, p in ipairs(lazy.plugins()) do
      if not p._.installed then
        missing[#missing + 1] = p.name
      end
    end
    if #missing > 0 then
      add("FAIL", "plugins not installed: " .. table.concat(missing, ", ") .. " (run :Lazy restore)")
    end
    local lock = vim.fn.stdpath("config") .. "/lazy-lock.json"
    add(vim.uv.fs_stat(lock) and "PASS" or "WARN", "lockfile " .. lock)
  else
    add("FAIL", "lazy.nvim failed to load")
  end

  -- config syntax
  local cfg = vim.fn.stdpath("config")
  local bad = {}
  for _, f in ipairs(vim.fn.globpath(cfg, "**/*.lua", false, true)) do
    local fn, err = loadfile(f)
    if not fn then
      bad[#bad + 1] = err
    end
  end
  if #bad == 0 then
    add("PASS", "config Lua syntax OK")
  else
    for _, e in ipairs(bad) do
      add("FAIL", "syntax: " .. e)
    end
  end

  return out
end

--- :checkhealth devenv
function M.check()
  vim.health.start("devenv")
  for _, r in ipairs(M.collect()) do
    if r.level == "PASS" then
      vim.health.ok(r.msg)
    elseif r.level == "WARN" then
      vim.health.warn(r.msg)
    else
      vim.health.error(r.msg)
    end
  end
end

--- Headless: prints results, exits non-zero on FAIL.
function M.run_cli()
  io.stdout:write("\n") -- keep output on its own line even if startup printed an error without a newline
  local n = { PASS = 0, WARN = 0, FAIL = 0 }
  for _, r in ipairs(M.collect()) do
    n[r.level] = n[r.level] + 1
    io.stdout:write(("[%s] %s\n"):format(r.level, r.msg))
  end
  io.stdout:write(("\nSummary: %d PASS, %d WARN, %d FAIL\n"):format(n.PASS, n.WARN, n.FAIL))
  vim.cmd(n.FAIL == 0 and "qa!" or "cquit 1")
end

return M
