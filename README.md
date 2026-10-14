# dev-env — reproducible Neovim IDE for macOS

A Git-managed Neovim 0.12 setup (Lua, lazy.nvim) with first-class **C#/.NET** and **Go** debugging, plus Python,
TypeScript/JavaScript, Bash and Lua. Installation, health checks, updates, backup/rollback and smoke tests are scripts.

## Supported platforms

| | Status |
|---|---|
| macOS on Apple Silicon (arm64) | **Fully supported and tested** (macOS 27, Neovim 0.12.6, .NET SDK 10.0.401, Go 1.25.5) |
| macOS on Intel | Everything except **C# debugging**: upstream netcoredbg publishes no Intel macOS binary (build from source, see `docs/DOTNET.md`). Untested on Intel hardware. |
| Linux / Windows | Not supported |

Prerequisites: macOS, [Homebrew](https://brew.sh), Xcode Command Line Tools (`xcode-select --install`, needed for `git` and compiling treesitter parsers), network access.

## Install (one command)

```sh
git clone <this repo> ~/Code/Personal/dev-env && cd ~/Code/Personal/dev-env
./scripts/bootstrap.sh --dry-run   # preview: nothing is changed
./scripts/bootstrap.sh             # install; asks before replacing ~/.config/nvim (it is backed up first)
```

Bootstrap: installs only what is missing (never upgrades), installs a checksum-verified netcoredbg, the Roslyn
language server and goimports, backs up and symlinks `~/.config/nvim` → `nvim/`, restores plugins from `lazy-lock.json`,
installs Mason tools, and runs the health check. It ends with a report of installed / skipped / failed / manual items.
It is idempotent. See `docs/INSTALL.md`.

## Daily use

| Task | How |
|---|---|
| Open Neovim | `nvim` (or `nvim .`) |
| Find file / grep / buffers | `<Space>ff` / `<Space>fg` / `<Space>fb` |
| File explorer | `<Space>e` |
| Go to definition / references / hover / rename / code action | `gd` / `gr` / `K` / `<Space>rn` / `<Space>ca` |
| Format | automatic on save; manual `<Space>cf`; toggle `<Space>uf` |
| Build / test | `<Space>tb` / `<Space>tn` (Go, Python) `<Space>tf` `<Space>tp` — see `docs/KEYMAPS.md` |
| Debug (Go or C#) | `<Space>b` breakpoint, `<F5>` or `<Space>dc` start/continue, `<Space>dn/di/do` step |
| Claude Code | `<Space>ac` (unchanged) |
| Terminal | `<Space>tt` |
| Blame current line | shown inline; `<Space>gb` for the full commit |

Full list: [`docs/KEYMAPS.md`](docs/KEYMAPS.md) · usage: [`docs/USAGE.md`](docs/USAGE.md).

## Check, update, roll back

```sh
./scripts/check.sh [--deep]        # PASS/WARN/FAIL health report (read-only)
./scripts/test.sh [--quick]        # automated smoke tests in an isolated sandbox
./scripts/update.sh --plugins      # intentional plugin update (review lockfile diff, test, commit)
./scripts/update.sh --rollback     # back to the committed lockfile
./scripts/backup.sh list|restore   # restore a previous ~/.config/nvim
```

Details: `docs/UPGRADING.md`, `docs/TROUBLESHOOTING.md`.

## Docs

`docs/INSTALL.md` · `USAGE.md` · `KEYMAPS.md` · `DOTNET.md` · `GO.md` · `ARCHITECTURE.md` · `UPGRADING.md` · `TROUBLESHOOTING.md`

## What has and hasn't been verified

`scripts/test.sh` (25 checks) verified on the author's Apple Silicon machine: LSP attach/hover/definition/diagnostics for
Go, C# (multi-project `.slnx`), Python, TypeScript, Bash, Lua; format-on-save for all six; git blame; `dotnet build`/`test`
and `go test` commands; **real debug sessions** (breakpoint hit, call stack, locals, evaluate, step, exception stop,
terminate) for Go (incl. test mode) and C#, both at the raw DAP level and through nvim-dap using this repo's config.

**Not tested:** Python and Node debug sessions, attach-to-process (.NET and Go), DAP UI rendering and interactive
keymaps by hand, `global.json`/multiple-SDK selection, Intel Macs. See `docs/ARCHITECTURE.md` §Known limitations.

## Privacy

No telemetry or cloud completion plugins. The only AI integration is your existing Claude Code (`claudecode.nvim`).
Language servers and debuggers run locally with your user's permissions — see `docs/ARCHITECTURE.md` §Security.
