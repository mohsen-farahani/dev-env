# Troubleshooting

Start with `./scripts/check.sh` (add `--deep` for LSP attach checks) and `:checkhealth devenv`. Then `./scripts/test.sh`.

## Install / scripts
| Symptom | Cause / fix |
|---|---|
| `Homebrew not found` | Install from https://brew.sh (bootstrap does not run the installer), open a new shell, re-run |
| `go install goimports` fails: `dial tcp: lookup package-proxy…` | Your global `GOPROXY` is unreachable. The installer overrides it with `proxy.golang.org`; if that is blocked by your network, set `GOPROXY` for a one-off manual `GOBIN=~/.local/share/dev-env/bin go install golang.org/x/tools/cmd/goimports@v0.38.0` |
| `netcoredbg checksum mismatch` | The download differs from the pinned hash. Do **not** bypass. Check the release on GitHub, compare digests, update `manifest/tools.lock` only if you trust the new asset |
| `roslyn-language-server install` failed | See `~/.local/state/dev-env/roslyn-install.log`. Note: `dotnet tool install` rejects `--prerelease` together with `--version` (the script uses `--version` only) |
| Bootstrap wants confirmation but runs non-interactively | Pass `--yes` |
| Want to see what would happen | `--dry-run` on bootstrap/install/backup |

## Neovim
| Symptom | Fix |
|---|---|
| Errors on startup after update | `./scripts/update.sh --rollback`; `:Lazy` to inspect; `:messages` |
| Syntax not highlighted | `tree-sitter` CLI or a C compiler missing → `brew install tree-sitter-cli`, `xcode-select --install`, then `:TSUpdate` |
| LSP not attaching | `:checkhealth vim.lsp`; `:LspInfo`-style info via `:lua =vim.lsp.get_clients()`; confirm the server binary: `check.sh` lists missing ones. Servers whose binary is missing are skipped silently at startup but reported by health |
| Format on save does nothing | `:ConformInfo`; missing tool shows in `check.sh`; `<Space>uf` may have toggled it off |
| Two formatters run / double format | Only `plugins/format.lua` may format on save — don't add `BufWritePre` hooks (the old `:!gofmt` hook was removed) |
| F1/F2/F10 do the wrong thing | macOS grabs them. Use `<Space>di/do/dn` or enable "Use F1, F2… as standard function keys" |

## C#
| Symptom | Fix |
|---|---|
| No C# diagnostics/completion | Is `~/.local/share/dev-env/roslyn/roslyn-language-server` present? (`check.sh`). Open a file inside a folder that has a `.sln/.slnx/.csproj` above it. A loose `.cs` file with no project is not analysed |
| `Failed to get language for textDocument/diagnostic` repeating | The file is outside any loaded solution/project (or you edited it via a path alias such as `/var` vs `/private/var`). Open it by its real path under the project |
| Wrong project picked with multiple solutions | `:Roslyn target` |
| `netcoredbg not found` when pressing F5 | `./scripts/install.sh`; on Intel see docs/DOTNET.md |
| Breakpoint stays grey/“unverified” | Normal until the module loads; if it never binds: build in **Debug** configuration, ensure PDBs exist (`DebugType` not `none`), and that you launched the project containing the code |
| Debug session starts then exits immediately | Program finished (no breakpoint hit). Check the REPL/console pane; set a breakpoint; for web apps make sure arguments/env are right |
| Build fails before debugging | Errors are in quickfix (`:copen`); fix and press F5 again |
| Debugger crashes after an SDK update | Known risk on macOS arm64 (Microsoft reported crashes with SDK 10.0.104/10.0.200 in its own debugger). Run `./scripts/test.sh`; if C# debugging fails, pin the previous SDK via `global.json` and/or bump netcoredbg |
| Architecture mismatch | `check.sh` verifies the netcoredbg binary is native; an x64 binary under Rosetta cannot debug an arm64 runtime |
| SDK selection | `dotnet --list-sdks`; a `global.json` is honoured by `dotnet` itself (untested with Roslyn here) |

## Go
| Symptom | Fix |
|---|---|
| Debug launch fails: `go: cannot find main module` | The adapter must start in the module root; this config does so — if you see it, you opened a file outside the module (`go.mod` not found above it) |
| `dlv` missing/old | `brew install delve` (tested 1.27.2) |
| gopls says package not in workspace | Open Neovim at/under the folder containing `go.mod`/`go.work` |

## Python / TypeScript / others (not fully tested)
- Python debug needs Mason's `debugpy` (health shows it). Project venv must be `.venv`/`venv` or `$VIRTUAL_ENV`.
- Node debug needs `js-debug-adapter` (Mason). TypeScript must be compiled (source maps) or run through a runner.
- ShellCheck diagnostics need `shellcheck` on PATH (`brew install shellcheck`).

## Safe reset
`./scripts/backup.sh restore <timestamp>` returns your previous config. Delete `~/.local/share/nvim` to force a clean plugin
reinstall (`./scripts/bootstrap.sh` again). The test sandbox lives in `~/.local/state/dev-env/test-sandbox` (`test.sh --fresh` rebuilds).
