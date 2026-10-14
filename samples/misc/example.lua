local M = {}

function M.greet(name)
  return "hello " .. name
end

vim.print(M.greet("world"))

return M
