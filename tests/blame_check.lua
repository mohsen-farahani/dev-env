-- Headless check that gitsigns shows inline blame (author, date, summary, sha) in a real throwaway git repo.
local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
local function git(...)
  local r = vim
    .system({ "git", "-C", dir, ... }, {
      text = true,
      env = {
        GIT_AUTHOR_NAME = "Ada Tester",
        GIT_AUTHOR_EMAIL = "ada@example.invalid",
        GIT_COMMITTER_NAME = "Ada Tester",
        GIT_COMMITTER_EMAIL = "ada@example.invalid",
        GIT_CONFIG_GLOBAL = "/dev/null",
        GIT_CONFIG_SYSTEM = "/dev/null",
      },
    })
    :wait()
  assert(r.code == 0, (r.stderr or "git failed"))
end
git("init", "-q")
vim.fn.writefile({ "line one", "line two" }, dir .. "/f.txt")
git("add", ".")
git("commit", "-q", "-m", "Add f.txt for blame test")

require("lazy").load({ plugins = { "gitsigns.nvim" } })
vim.cmd.edit(vim.fn.fnameescape(dir .. "/f.txt"))
vim.wait(2000)
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 })
local ns = vim.api.nvim_get_namespaces()["gitsigns_blame"]
local text
vim.wait(10000, function()
  if not ns then
    ns = vim.api.nvim_get_namespaces()["gitsigns_blame"]
  end
  if not ns then
    return false
  end
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
    local vt = m[4].virt_text
    if vt then
      text = table.concat(vim.tbl_map(function(c)
        return c[1]
      end, vt))
      return true
    end
  end
  return false
end, 200)

local good = text
  and text:find("Ada Tester", 1, true)
  and text:find("Add f.txt for blame test", 1, true)
  and text:match("%(%x%x%x%x%x%x%x+%)")
io.stdout:write(("  blame text: %s\n"):format(tostring(text)))
io.stdout:write(good and "BLAME CHECK PASS\n" or "BLAME CHECK FAIL\n")
vim.fn.delete(dir, "rf")
vim.cmd(good and "qa!" or "cquit 1")
