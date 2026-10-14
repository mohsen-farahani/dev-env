-- LSP setup using the built-in Neovim 0.11+/0.12 API: vim.lsp.config() + vim.lsp.enable().
-- This is the ONLY place servers are configured/enabled. Servers whose executable is missing are
-- skipped here (and reported by :checkhealth devenv) instead of erroring on every buffer open.
local paths = require("devenv.paths")
local M = {}

local function python_path(root)
  local venv = vim.env.VIRTUAL_ENV
  if venv and vim.uv.fs_stat(venv .. "/bin/python") then
    return venv .. "/bin/python"
  end
  if root then
    for _, d in ipairs({ ".venv", "venv" }) do
      local p = vim.fs.joinpath(root, d, "bin", "python")
      if vim.uv.fs_stat(p) then
        return p
      end
    end
  end
end

local has_blink, blink = pcall(require, "blink.cmp")
vim.lsp.config("*", {
  capabilities = has_blink and blink.get_lsp_capabilities() or nil,
})

vim.lsp.config("gopls", {
  settings = {
    gopls = {
      staticcheck = true,
      usePlaceholders = true,
      analyses = { unusedparams = true, shadow = true },
    },
  },
})

vim.lsp.config("lua_ls", {
  settings = { Lua = { workspace = { checkThirdParty = false }, telemetry = { enable = false } } },
})

vim.lsp.config("basedpyright", {
  on_init = function(client)
    local py = python_path(client.root_dir)
    if py then
      client.settings = vim.tbl_deep_extend("force", client.settings or {}, { python = { pythonPath = py } })
      client:notify("workspace/didChangeConfiguration", { settings = client.settings })
    end
  end,
  settings = { basedpyright = { analysis = { typeCheckingMode = "standard" } } },
})

vim.lsp.config("roslyn", {
  cmd = {
    paths.roslyn,
    "--logLevel",
    "Information",
    "--extensionLogDirectory",
    vim.fs.joinpath(vim.fn.stdpath("state"), "roslyn_ls"),
    "--stdio",
  },
  settings = {
    ["csharp|background_analysis"] = {
      dotnet_analyzer_diagnostics_scope = "fullSolution",
      dotnet_compiler_diagnostics_scope = "fullSolution",
    },
    ["csharp|completion"] = { dotnet_show_completion_items_from_unimported_namespaces = true },
    ["csharp|inlay_hints"] = { csharp_enable_inlay_hints_for_parameters = false },
  },
})

-- name -> executable that must exist. "roslyn" is enabled by roslyn.nvim itself.
M.servers = {
  gopls = "gopls",
  basedpyright = "basedpyright-langserver",
  ruff = "ruff",
  ts_ls = "typescript-language-server",
  bashls = "bash-language-server",
  lua_ls = "lua-language-server",
}
M.missing = {}

for name, exe in pairs(M.servers) do
  if vim.fn.executable(exe) == 1 then
    vim.lsp.enable(name)
  else
    M.missing[#M.missing + 1] = name .. " (" .. exe .. ")"
  end
end
if vim.fn.executable(paths.roslyn) ~= 1 then
  M.missing[#M.missing + 1] = "roslyn (" .. paths.roslyn .. ")"
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("devenv_lsp_attach", { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client.name == "ruff" then
      client.server_capabilities.hoverProvider = false
    end
    local map = function(lhs, rhs, desc, mode)
      vim.keymap.set(mode or "n", lhs, rhs, { buffer = ev.buf, silent = true, desc = "LSP: " .. desc })
    end
    map("gd", vim.lsp.buf.definition, "go to definition")
    map("gD", vim.lsp.buf.declaration, "go to declaration")
    map("gr", vim.lsp.buf.references, "references")
    map("gi", vim.lsp.buf.implementation, "implementation")
    map("gy", vim.lsp.buf.type_definition, "type definition")
    map("K", vim.lsp.buf.hover, "hover")
    map("<leader>rn", vim.lsp.buf.rename, "rename symbol")
    map("<leader>ca", vim.lsp.buf.code_action, "code action", { "n", "v" })
    map("<leader>cs", vim.lsp.buf.signature_help, "signature help")
    map("<leader>cd", vim.diagnostic.open_float, "line diagnostics")
    map("<leader>cl", function()
      vim.diagnostic.setqflist()
    end, "diagnostics -> quickfix")
    if client and client:supports_method("textDocument/inlayHint") then
      map("<leader>ch", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
      end, "toggle inlay hints")
    end
  end,
})

return M
