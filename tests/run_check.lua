-- Headless check of the build/test commands (devenv.run) on temp copies of the samples.
local run = require("devenv.run")
local failures = 0
local function ok(m)
  io.stdout:write("  ok   " .. m .. "\n")
end
local function bad(m)
  failures = failures + 1
  io.stdout:write("  FAIL " .. m .. "\n")
end

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
root = vim.uv.fs_realpath(root) -- avoid /var -> /private/var symlink mismatch
vim.fn.system({
  "rsync",
  "-a",
  "--exclude",
  "bin",
  "--exclude",
  "obj",
  vim.uv.cwd() .. "/samples/dotnet-sample/",
  root .. "/cs/",
})
vim.fn.system({ "rsync", "-a", vim.uv.cwd() .. "/samples/go-hello/", root .. "/go/" })

local function wait_term(pattern, timeout)
  return vim.wait(timeout or 120000, function()
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[b].buftype == "terminal" then
        local text = table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), "\n")
        if text:find(pattern) then
          return true
        end
      end
    end
    return false
  end, 300)
end

-- 1. build with a compile error -> quickfix has a parsed CS error with file + line
local calc = root .. "/cs/src/Calc/Calculator.cs"
local good = vim.fn.readfile(calc)
local broken = vim.deepcopy(good)
table.insert(broken, #broken, '    int broken = "s";')
vim.fn.writefile(broken, calc)
vim.cmd.edit(vim.fn.fnameescape(root .. "/cs/src/App/Program.cs"))
run.dotnet("build")
local got = vim.wait(120000, function()
  return #vim.fn.getqflist() > 0 and vim.fn.getqflist({ title = 1 }).title == "dotnet build"
end, 300)
local hit
for _, e in ipairs(vim.fn.getqflist()) do
  if e.valid == 1 and e.lnum > 0 and e.text:find("CS%d%d%d%d") then
    hit = e
    break
  end
end
if got and hit then
  ok(
    ("dotnet build error parsed into quickfix: %s:%d %s"):format(
      vim.fs.basename(vim.fn.bufname(hit.bufnr)),
      hit.lnum,
      hit.text:sub(1, 60)
    )
  )
else
  bad("dotnet build error not parsed into quickfix: " .. vim.inspect(vim.fn.getqflist()))
end

-- 2. fix, build succeeds (qf closes, no valid entries)
vim.fn.writefile(good, calc)
vim.fn.setqflist({}, "r")
run.dotnet("build")
vim.wait(120000, function()
  return #vim.fn.getqflist() == 0 and vim.uv.fs_stat(root .. "/cs/src/App/bin/Debug/net10.0/App.dll") ~= nil
end, 300)
if vim.uv.fs_stat(root .. "/cs/src/App/bin/Debug/net10.0/App.dll") then
  ok("dotnet build succeeded after fix")
else
  bad("dotnet build did not produce App.dll")
end

-- 3. dotnet test for the test project's class
vim.cmd.edit(vim.fn.fnameescape(root .. "/cs/tests/Calc.Tests/CalculatorTests.cs"))
run.dotnet("test-file", true)
if wait_term("failed: 0, succeeded: 2") then
  ok("dotnet test (file/class filter) passed in terminal")
else
  bad("dotnet test output missing success summary")
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buftype == "terminal" then
      io.stdout:write(table.concat(vim.api.nvim_buf_get_lines(b, 0, 30, false), "\n") .. "\n")
    end
  end
end

-- 4. go test at cursor
vim.cmd.edit(vim.fn.fnameescape(root .. "/go/main_test.go"))
vim.api.nvim_win_set_cursor(0, { 6, 0 })
if run.go_test_name() == "TestSum" then
  ok("go test name detected at cursor: TestSum")
else
  bad("go_test_name failed")
end
run.go("test-func")
if wait_term("PASS") then
  ok("go test (function at cursor) passed in terminal")
else
  bad("go test output missing PASS")
end

vim.fn.delete(root, "rf")
io.stdout:write(failures == 0 and "RUN CHECK PASS\n" or "RUN CHECK FAIL\n")
vim.cmd(failures == 0 and "qa!" or "cquit 1")
