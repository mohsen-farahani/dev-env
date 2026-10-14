-- Headless end-to-end debug test THROUGH nvim-dap using the repo's own adapter/config modules.
-- Env: KIND=go|cs. Verifies: session starts, breakpoint hit, call stack, locals, step over, terminate.
local kind = vim.env.KIND
local failures = 0
local function ok(m)
  io.stdout:write("  ok   " .. m .. "\n")
end
local function bad(m)
  failures = failures + 1
  io.stdout:write("  FAIL " .. m .. "\n")
end
local function finish()
  io.stdout:write(failures == 0 and "NVIM-DAP " .. kind .. " PASS\n" or "NVIM-DAP " .. kind .. " FAIL\n")
  vim.cmd(failures == 0 and "qa!" or "cquit 1")
end

local lazy = require("lazy")
lazy.load({ plugins = { "nvim-dap" } })
local dap = require("dap")

local function open(path, line)
  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.api.nvim_win_set_cursor(0, { line, 0 })
end

local cwd = vim.uv.cwd()
local want_var, want_frame
if kind == "go" then
  open(cwd .. "/samples/go-hello/main.go", 8)
  dap.toggle_breakpoint()
  want_var, want_frame = "total", "Sum"
  require("dap").run(vim.tbl_extend("force", {}, dap.configurations.go[1]))
elseif kind == "cs" then
  open(cwd .. "/samples/dotnet-sample/src/Calc/Calculator.cs", 10)
  dap.toggle_breakpoint()
  open(cwd .. "/samples/dotnet-sample/src/App/Program.cs", 1)
  vim.ui.input = function(_, cb)
    cb("5")
  end -- program arguments
  want_var, want_frame = "result", "Factorial"
  require("devenv.dap").continue() -- same path as pressing F5
else
  error("KIND must be go|cs")
end

local stopped = vim.wait(120000, function()
  local s = dap.session()
  return s ~= nil and s.stopped_thread_id ~= nil and s.current_frame ~= nil
end, 200)
if not stopped then
  bad("never stopped at breakpoint (session=" .. tostring(dap.session() ~= nil) .. ")")
  return finish()
end
local s = dap.session()
ok("stopped at breakpoint in frame '" .. tostring(s.current_frame.name) .. "' line " .. tostring(s.current_frame.line))
if not tostring(s.current_frame.name):find(want_frame, 1, true) then
  bad("unexpected top frame, wanted " .. want_frame)
end

local function request(cmd, args)
  local res, done = nil, false
  s:request(cmd, args, function(err, body)
    res = { err = err, body = body }
    done = true
  end)
  vim.wait(20000, function()
    return done
  end, 50)
  return res
end

local frames = request("stackTrace", { threadId = s.stopped_thread_id }).body.stackFrames
ok("call stack depth " .. #frames .. ": " .. table.concat(
  vim.tbl_map(function(f)
    return f.name
  end, vim.list_slice(frames, 1, 3)),
  " <- "
))

local vars = {}
for _, sc in ipairs(request("scopes", { frameId = s.current_frame.id }).body.scopes) do
  for _, v in ipairs(request("variables", { variablesReference = sc.variablesReference }).body.variables) do
    vars[v.name] = v.value
  end
end
if vars[want_var] then
  ok("variable " .. want_var .. " = " .. vars[want_var])
else
  bad("variable " .. want_var .. " not visible; have " .. vim.inspect(vars))
end

local line_before = s.current_frame.line
dap.step_over()
local stepped = vim.wait(20000, function()
  return dap.session() and dap.session().current_frame and dap.session().current_frame.line ~= line_before
end, 100)
if stepped then
  ok("step over advanced line " .. line_before .. " -> " .. dap.session().current_frame.line)
else
  bad("step over did not advance")
end

dap.terminate()
local ended = vim.wait(20000, function()
  return dap.session() == nil
end, 100)
if ended then
  ok("session terminated cleanly")
else
  bad("session did not terminate")
end
finish()
