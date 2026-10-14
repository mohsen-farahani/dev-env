# Everyday usage

## Starting
`nvim .` in a project root. Plugins are lazy-loaded; the first open of a C# file starts Roslyn (solution load can take
several seconds on big solutions; watch `:LspInfo`/`:checkhealth vim.lsp`).

## Project roots
- Go: nearest `go.work`, else `go.mod`.
- C#: Roslyn prefers a solution (`.sln`/`.slnx`) above the file, else the `.csproj`. With several solutions use
  `:Roslyn target` to choose. `broad_search` is off, so unrelated solutions are not scanned.
- Python: nearest `pyproject.toml`/`.git`. A `.venv` or `venv` in the root (or `$VIRTUAL_ENV`) is used for analysis,
  `pytest`, and debugging.
- TypeScript/JS: `tsconfig.json`/`package.json`/lockfile. The project's own `typescript` and `prettier` in
  `node_modules` are preferred.

## Formatting
One hook (conform.nvim) formats on save:
| Language | Tool |
|---|---|
| Go | goimports then gofmt |
| C# | Roslyn LSP formatter (honours `.editorconfig`); `dotnet format` via `<Space>tF` |
| Python | ruff (import sort + format) |
| TS/JS/JSON | project-local prettier if present, else the LSP formatter |
| Bash | shfmt (honours `.editorconfig`) |
| Lua | stylua (`stylua.toml`) |
Missing tools are reported by `scripts/check.sh` (WARN/FAIL) and conform shows a message on save; nothing fails silently.
Toggle with `<Space>uf`; `:ConformInfo` shows what applies to the current buffer.

## Diagnostics
Inline virtual text + signs; `<Space>cd` float, `<Space>cl` quickfix list, `<Space>fd` Telescope.
Bash diagnostics come from ShellCheck via bash-language-server; Python from basedpyright + ruff.

## Debugging workflow
1. Open a source file, `<Space>b` on a line.
2. `<F5>`/`<Space>dc`. Go: debugs the current file's package. C#: choose a runnable project (if >1), enter arguments,
   it builds and launches. `<Space>dt` debugs the Go/Python test at the cursor.
3. The UI opens on start. Step with `<Space>dn/di/do`, inspect in the UI panes, `<Space>de` to evaluate.
4. `<Space>dr` restart, `<Space>dx` terminate. The UI closes when the session ends.
Language specifics: `docs/GO.md`, `docs/DOTNET.md`. Python uses debugpy (Mason) — configurations from nvim-dap-python;
Node uses js-debug (`Launch file (node)`, via `:lua require('dap').continue()`); both are **untested here**.

## Terminal and Claude Code
`<Space>tt` toggles a terminal; `<Space>ac` the Claude Code integration. The normal `dotnet`, `go`, `git` CLIs remain
the primary way to do anything not listed in KEYMAPS.md.

## If a plugin fails
Core editing, navigation and `vim.lsp` work without optional plugins. `:Lazy` shows plugin state, `:checkhealth devenv`
the environment, `:messages` recent errors.
