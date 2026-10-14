-- Headless format-on-save check using temp copies. Verifies the single conform hook actually rewrites files.
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local failures = 0
local function ok(m)
  io.stdout:write("  ok   " .. m .. "\n")
end
local function bad(m)
  failures = failures + 1
  io.stdout:write("  FAIL " .. m .. "\n")
end

local function read(p)
  return table.concat(vim.fn.readfile(p), "\n")
end

local function case(name, relpath, content, must_have, must_not, wait_client)
  local path = vim.fs.joinpath(root, relpath)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(vim.split(content, "\n"), path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  if wait_client then
    if
      not vim.wait(60000, function()
        return #vim.lsp.get_clients({ bufnr = 0, name = wait_client }) > 0
      end, 200)
    then
      return bad(name .. ": LSP " .. wait_client .. " did not attach")
    end
    vim.wait(8000)
  end
  local before = read(path)
  vim.cmd("silent write")
  vim.wait(500)
  local after = read(path)
  if after == before then
    return bad(name .. ": file unchanged after save (formatter not applied)")
  end
  for _, s in ipairs(must_have or {}) do
    if not after:find(s, 1, true) then
      return bad(name .. ": expected '" .. s .. "' in output:\n" .. after)
    end
  end
  for _, s in ipairs(must_not or {}) do
    if after:find(s, 1, true) then
      return bad(name .. ": unexpected '" .. s .. "' in output:\n" .. after)
    end
  end
  ok(name .. " formatted on save")
end

case(
  "go (goimports+gofmt)",
  "g/main.go",
  'package main\nimport (\n"os"\n"fmt"\n)\nfunc main(){fmt.Println(1)}\n',
  { "func main() {" },
  { '"os"' }
)
case("python (ruff)", "p/a.py", "x=1\ndef f( a,b ):\n    return a+b\n", { "x = 1", "def f(a, b):" })
case("bash (shfmt)", "s/a.sh", "#!/usr/bin/env bash\nif true;then\necho hi\nfi\n", { "if true; then" })
case("lua (stylua)", "l/a.lua", "local x={a=1,b=2}\nreturn x\n", { "local x = { a = 1, b = 2 }" })
case(
  "typescript (prettier or ts_ls fallback)",
  "t/a.ts",
  "const x=1\nfunction f(a:number){return a}\n",
  { "x = 1" },
  nil,
  "ts_ls"
)

-- C#: needs a project for Roslyn
local sample = vim.fs.joinpath(vim.uv.cwd(), "samples", "dotnet-sample")
local dst = vim.fs.joinpath(root, "cs")
vim.fn.system({ "rsync", "-a", "--exclude", "bin", "--exclude", "obj", sample .. "/", dst .. "/" })
local prog = vim.fs.joinpath(dst, "src", "Calc", "Calculator.cs")
vim.fn.writefile(
  vim.split("namespace Calc;\npublic static class Z{public static int M(int a){if(a>1){return a;}return 0;}}\n", "\n"),
  prog
)
case(
  "csharp (Roslyn LSP format)",
  "cs/src/Calc/Calculator.cs",
  "namespace Calc;\npublic static class Z{public static int M(int a){if(a>1){return a;}return 0;}}\n",
  { "if (a > 1)" },
  nil,
  "roslyn"
)

vim.fn.delete(root, "rf")
io.stdout:write(failures == 0 and "FORMAT CHECK PASS\n" or "FORMAT CHECK FAIL\n")
vim.cmd(failures == 0 and "qa!" or "cquit 1")
