# Architecture

Last verified: 2026-10-14 on macOS 27.0.1 / arm64, Neovim 0.12.6.

## 1. Goals
Reproducible, safe-to-rerun Neovim IDE setup for macOS with first-class C#/.NET and Go debugging, minimal plugin
count, no cloud code services, every claim backed by an automated test or explicitly marked untested.

## 2. Layout
```
nvim/                    symlinked to ~/.config/nvim (originals are backed up, never overwritten)
  init.lua               loads lua/devenv/*
  lazy-lock.json         plugin pins
  lua/devenv/            options, keymaps, lsp (the only place servers are configured), run (build/test),
                         tools (Mason list), health, paths, dap/{go,dotnet,python,node}
  lua/plugins/           lazy.nvim specs, one file per concern (ui, editor, git, lsp, format, dap, claude)
scripts/                 bootstrap install check update backup test (+ lib/common.sh)
manifest/                Brewfile (what Homebrew provides) and tools.lock (URL+sha256 of downloaded binaries)
samples/                 go-hello, dotnet-sample (.slnx, App + Calc lib + xunit tests), py-hello, ts-hello, misc
tests/                   headless Lua tests and the DAP protocol client used by scripts/test.sh
docs/
```

## 3. Decisions and reasons
| Decision | Reason |
|---|---|
| Built-in `vim.lsp.config()/enable()`; nvim-lspconfig only supplies server definitions | The 0.11+/0.12 API; avoids deprecated `lspconfig.X.setup`. |
| **No mason-lspconfig** | Its only value was auto-enable/install mapping; that duplicated `vim.lsp.enable` and caused the double initialization in the previous config. Mason installs a plain package list (`devenv/tools.lua`). |
| Go tools from system/Homebrew, not Mason | Requirement; avoids version skew with the machine's `go`. |
| roslyn.nvim + Microsoft feed `dotnet tool` | Roslyn is the supported C# server (OmniSharp is legacy). The Mason registry's Roslyn package is a third-party repack; the official feed is first-party. Version pinned. |
| netcoredbg installed by the script, sha256-pinned | Mason's package pins an older version and ships the amd64 binary for darwin_arm64. Upstream 3.2.0 ships native arm64. Alternatives considered: Microsoft's vsdbg (license restricts use to Microsoft products, not allowed outside VS Code/VS) — not used. |
| conform.nvim as the single format hook | One `BufWritePre`, per-filetype tool lists, LSP fallback, visible errors. Replaced the `:!gofmt` + `edit!` hook. |
| gitsigns only for Git | Requirement: blame, no Git UI. |
| No neotest | Build/test commands are small, CLI-faithful wrappers (`devenv/run.lua`) with fewer plugins and moving parts. neotest was not evaluated; it can be added later if in-buffer result markers are wanted. |
| Explicit C# launch function instead of an nvim-dap config entry | nvim-dap resolves config fields independently; selecting a project must set `program` *and* `cwd` consistently, and a build must precede launch. |
| Servers whose binary is missing are not enabled | Avoids an error on every buffer open; health check reports them instead. |
| Tests run in an XDG sandbox against samples/temp copies | Never touches the user's config, plugins, or projects. |

## 4. Dependency inventory
Homebrew (if missing): neovim, git, ripgrep, fd, fzf, go, gopls, delve, dotnet, shellcheck, shfmt, stylua, tree-sitter-cli.
Pinned downloads: netcoredbg 3.2.0-1092 (GitHub, sha256), roslyn-language-server 5.13.0-1.26513.11 (Microsoft feed),
goimports v0.38.0 (Go proxy+sumdb). Mason: basedpyright, ruff, bash-language-server, lua-language-server,
typescript-language-server, debugpy, js-debug-adapter. Plugins: see `nvim/lazy-lock.json`.
Per-language toolchain table:

| Language | Server | Formatter | Debugger | Tests | Verified by |
|---|---|---|---|---|---|
| C# | roslyn | Roslyn LSP | netcoredbg | `dotnet test` | LSP, format, build/test, DAP (raw + nvim-dap), exception stop |
| Go | gopls | goimports+gofmt | delve | `go test` | LSP, format, test cmd, DAP (raw, test mode, nvim-dap) |
| Python | basedpyright + ruff | ruff | debugpy | pytest | LSP, format. **Debug untested** |
| TS/JS | ts_ls | project prettier / LSP | js-debug | – | LSP, format (LSP fallback). **Debug untested** |
| Bash | bashls + shellcheck | shfmt | – | – | LSP/shellcheck, format |
| Lua | lua_ls + lazydev | stylua | – | – | LSP (Neovim API aware), format |

## 5. Security
- Language servers and debuggers are native/Node programs running as **your user**: they can read any file you can,
  and the debuggee inherits your environment variables.
- Downloads: HTTPS only; sha256 verified before install (`tools.lock`); no `curl | sh`; no `sudo` anywhere.
- Go installs override the user's `GOSUMDB=off` for that command so the checksum DB is consulted.
- NuGet signature verification is off by default on macOS for `dotnet tool install` (see DOTNET.md).
- Mason downloads from GitHub/npm/PyPI registries pinned only by the registry state at install time.
- No telemetry/cloud completion. lua_ls telemetry explicitly disabled. Claude Code integration unchanged.
- Logs written by scripts (`~/.local/state/dev-env/*.log`) contain command output only; no secrets are read or written.
- Nothing in the repo contains tokens or machine-specific secrets; paths are derived from `$HOME`.

## 6. Known limitations
1. Intel Macs: no C# debugger binary; untested on Intel.
2. Not tested: Python and Node debugging, attach (.NET/Go), DAP UI visuals and interactive keymaps, `global.json`
   multi-SDK, remote/Docker debugging, Windows/Linux.
3. netcoredbg macOS arm64 is community-supported upstream; exception stops show only `$exception` in the first scope.
4. Mason package versions are not pinned (registry latest at install time).
5. Roslyn is a prerelease build from Microsoft's feed (the only channel roslyn.nvim documents).
6. The dev environment on this machine has `GOSUMDB=off` globally (not changed by this repo).
7. `treesitter` parsers compile locally (need a C compiler).
