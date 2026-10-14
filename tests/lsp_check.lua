-- Headless LSP check. Env: FILE, CLIENT, SYMBOL (text to locate), BAD (line appended to induce a diagnostic),
-- DEF_FILE (basename expected for go-to-definition on SYMBOL), TIMEOUT (ms).
local file, client_name = vim.env.FILE, vim.env.CLIENT
local timeout = tonumber(vim.env.TIMEOUT or "60000")
local failures = {}
local function ok(msg)
  io.stdout:write("  ok   " .. msg .. "\n")
end
local function bad(msg)
  failures[#failures + 1] = msg
  io.stdout:write("  FAIL " .. msg .. "\n")
end

vim.cmd.edit(vim.fn.fnameescape(file))
local buf = vim.api.nvim_get_current_buf()

local function client()
  return vim.lsp.get_clients({ bufnr = buf, name = client_name })[1]
end
local attached = vim.wait(timeout, function()
  return client() ~= nil
end, 200)
if not attached then
  bad(("client '%s' never attached (have: %s)"):format(
    client_name,
    table.concat(
      vim.tbl_map(function(c)
        return c.name
      end, vim.lsp.get_clients()),
      ","
    )
  ))
  io.stdout:write("LSP CHECK FAIL\n")
  vim.cmd("cquit 1")
end
local c = client()
ok(("client %s attached (root=%s)"):format(c.name, c.root_dir or "?"))

-- locate symbol
local row, col
if vim.env.SYMBOL then
  for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local s = line:find(vim.env.SYMBOL, 1, true)
    if s then
      row, col = i - 1, s - 1
      break
    end
  end
  if not row then
    bad("symbol not found: " .. vim.env.SYMBOL)
  end
end

local function request(method, params)
  local res
  local done = false
  c:request(method, params, function(err, result)
    res = { err = err, result = result }
    done = true
  end, buf)
  vim.wait(timeout, function()
    return done
  end, 100)
  return res
end

if row then
  local params =
    { textDocument = vim.lsp.util.make_text_document_params(buf), position = { line = row, character = col } }
  -- servers may need time after attach (e.g. solution load); retry a few times
  local function retry(method, check)
    local r
    local deadline = vim.uv.now() + timeout
    repeat
      r = request(method, params)
      if r and check(r.result) then
        return r
      end
      vim.wait(1000)
    until vim.uv.now() > deadline
    return r
  end
  local h = retry("textDocument/hover", function(x)
    return x ~= nil
  end)
  if h and h.result then
    ok("hover returned content")
  else
    bad("hover returned nothing")
  end
  if vim.env.DEF_FILE then
    local d = retry("textDocument/definition", function(x)
      return x ~= nil and (not vim.islist(x) or #x > 0)
    end)
    local loc = d and d.result
    if loc and vim.islist(loc) then
      loc = loc[1]
    end
    local uri = loc and (loc.uri or loc.targetUri)
    if uri and uri:find(vim.env.DEF_FILE, 1, true) then
      ok("definition -> " .. vim.fs.basename(vim.uri_to_fname(uri)))
    else
      bad("definition did not resolve to " .. vim.env.DEF_FILE .. " (got " .. tostring(uri) .. ")")
    end
  end
end

if vim.env.BAD then
  local at = vim.env.BAD_AT_TOP and 0 or vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_lines(buf, at, at, false, { vim.env.BAD })
  local pat = vim.env.BAD_PATTERN or "."
  local hit
  local got = vim.wait(timeout, function()
    for _, d in ipairs(vim.diagnostic.get(buf)) do
      if d.message:lower():find(pat:lower()) then
        hit = d
        return true
      end
    end
    return false
  end, 200)
  if got then
    ok(("diagnostic: [%s] %s"):format(hit.source or c.name, (hit.message:gsub("\n.*", ""))))
  else
    local have = vim.tbl_map(function(d)
      return d.message
    end, vim.diagnostic.get(buf))
    bad(("no diagnostic matching '%s' (have: %s)"):format(pat, vim.inspect(have)))
  end
end

io.stdout:write((#failures == 0) and "LSP CHECK PASS\n" or "LSP CHECK FAIL\n")
vim.cmd(#failures == 0 and "qa!" or "cquit 1")
