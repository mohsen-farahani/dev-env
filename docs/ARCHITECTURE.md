# Architecture (draft v0, Phase A)

Status: plan written from inspection of the current machine and upstream
sources checked on 2026-10-14. Items marked **UNVERIFIED** have not been
exercised yet and must not be treated as working.

## 1. Baseline machine (inspected)

| Item | Found |
|---|---|
| OS / arch | macOS 27.0.1, arm64, zsh |
| Homebrew | 7.0.9 at /opt/homebrew |
| Neovim | 0.12.6 (Homebrew) |
| Go / gopls / dlv | go 1.25.5 (/usr/local/go), gopls 0.23.0, dlv 1.27.2 (brew) |
| .NET | SDK 10.0.401 + runtime 10.0.12 at /usr/local/share/dotnet (brew `dotnet` shim) |
| Python / Node | 3.14.7 (brew), Node 20.20.2 via nvm |
| Missing | netcoredbg, shellcheck, shfmt, stylua, gh |
| Existing nvim config | `~/.config/nvim/init.lua` (single file) + `lazy-lock.json`; Mason has basedpyright, bash-language-server, lua-language-server, typescript-language-server |

Findings about the existing config (it is NOT replaced until backed up and the new one passes checks):
- The lazy spec is malformed: `claudecode.nvim`, tokyonight, lualine, nvim-tree, telescope and nvim-dap entries are nested inside the `mason-lspconfig` spec table, and `config = function` is placed after them. It only works by accident of table layout.
- Go formatting uses `silent !gofmt -w %` + `edit!` on BufWritePre (fragile, discards undo, shells out). Replace with one formatter hook (conform.nvim).
- `vim.lsp.config("roslyn", {})` is declared but roslyn is never installed or enabled.
- Preserve: leader=Space, `<leader>ac` Claude Code, `<leader>e/ff/fg/fb`, `<leader>b`, `<leader>du`, F5/F10/F1/F2 debug keys, tokyonight-night, lualine.

## 2. Layout

```
nvim/            -> symlinked to ~/.config/nvim (never copied, never overwrites without backup)
  init.lua       -> loads lua/devenv/*
  lua/devenv/{options,keymaps,lazy,lsp,format,dap,test}.lua
  lua/devenv/lang/{go,dotnet,python,typescript,bash,lua}.lua
  lazy-lock.json -> plugin pinning (committed)
scripts/         bootstrap install check update backup test (+ lib/common.sh)
manifest/        Brewfile, tools.lock (pinned versions + sha256 of downloaded binaries)
samples/         go-hello, dotnet-sample (isolated, used by tests)
docs/
```

## 3. Key decisions (with evidence)

1. **LSP**: Neovim 0.12 built-in `vim.lsp.config()` / `vim.lsp.enable()`; nvim-lspconfig supplies server definitions only. No `lspconfig[x].setup()` (deprecated).
2. **Plugin manager**: lazy.nvim with committed `lazy-lock.json`; updates only via `scripts/update.sh`.
3. **Go tools are Homebrew/system-managed**, not Mason (gopls, dlv, gofmt, goimports). Mason is limited to tools Homebrew lacks.
4. **C# server**: `seblyng/roslyn.nvim` (README: requires Neovim >= 0.12.0 and a locally downloaded Roslyn server >= 5.12.0-1.26453.19 plus the dotnet SDK). The plugin does not ship the server. Install via Mason with the `Crashdummyy/mason-registry` (package `roslyn`), or `dotnet tool install -g roslyn-language-server --prerelease` from the official Azure DevOps feed. Decision pending: **UNVERIFIED** which is more reproducible; leaning to Mason custom registry pinned to a version, with the dotnet tool as the documented fallback. `.slnx` support is not mentioned in the README: **must be tested with a real `.slnx`**.
5. **C# debugger**: Samsung **netcoredbg**. Latest upstream release `3.2.0-1092` (2026-06-25) ships a native `netcoredbg-osx-arm64.zip`; no Intel macOS asset exists in that release. **Important:** the Mason registry package for netcoredbg still pins `3.1.3-1062` and, for `darwin_arm64`, downloads the **amd64** archive, which would run under Rosetta and cannot debug a native arm64 .NET runtime. Therefore Mason is NOT used for netcoredbg. `install.sh` downloads the release asset from GitHub, verifies a pinned sha256 from `manifest/tools.lock`, and installs it under `~/.local/share/dev-env/netcoredbg`. Upstream states macOS arm64 is "community supported and may not work as expected". Compatibility with .NET 10.0.401 is **UNVERIFIED**; the smoke test must hit a breakpoint and read a local before debugging is claimed. Intel Macs: no prebuilt asset, documented as manual (build from source) limitation.
   - Microsoft reported crashes in its own debugger on macOS arm64 with SDK 10.0.104/10.0.200; unknown whether netcoredbg is affected at 10.0.401. Test, don't assume.
6. **Formatting**: single `conform.nvim` BufWritePre hook; formatters: gofmt/goimports (Go), csharpier or `dotnet format` (C#, decide after testing), ruff (Python), prettier from the project's node_modules (TS/JS, falls back visibly), shfmt, stylua. Missing formatter = WARN in health check, never silent.
7. **Python**: basedpyright (already used) + ruff; debugpy in a dedicated venv under `~/.local/share/dev-env/`; python 3.14 is very new, so debugpy compatibility is **UNVERIFIED**.
8. **TS/JS**: ts_ls (typescript-language-server) using the project's local TypeScript; js-debug-adapter for Node debugging (Mason or pinned release).
9. **Bash/Lua**: bashls + shellcheck + shfmt; lua_ls (with Neovim runtime awareness) + stylua.
10. **Git**: gitsigns only (current-line blame with author/commit). No git UI.
11. **Claude Code**: keep `coder/claudecode.nvim` + snacks.nvim unchanged (`<leader>ac`). No other AI providers.
12. **Completion**: blink.cmp (existing, local sources only, no cloud).

## 4. Security model

- No `curl | sh`. Downloaded binaries need a pinned sha256 (recorded in `manifest/tools.lock`); mismatch aborts.
- No `sudo` anywhere in our scripts. Homebrew's own installer is not run automatically; bootstrap prints the official command and stops.
- No telemetry plugins. Mason/LSPs run as the user and can read any file the user can; documented in `docs/ARCHITECTURE.md` when finalized.
- Backups of `~/.config/nvim` go to `~/.local/state/dev-env/backups/<timestamp>/`; restore is by `scripts/backup.sh restore`.

## 5. Rollout order and gates

B: repo skeleton -> C: scripts (dry-run first) -> D: Lua config developed in the repo and tested via `NVIM_APPNAME`/`XDG_*` isolation so the live `~/.config/nvim` is untouched -> E: tests -> F: docs + report. Switching the live config happens only after backup and explicit confirmation.

## 6. Open questions for the user

1. Is `/Users/mac/Code/Personal/dev-env` the intended repo location? (assumed yes)
2. May the installer run `brew install` for: shellcheck, shfmt, stylua? (new software, no sudo)
3. Intel Mac support for the C# debugger would require a source build; acceptable to document as unsupported?
