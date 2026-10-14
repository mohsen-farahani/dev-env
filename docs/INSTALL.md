# Installation

## Requirements
- macOS (Apple Silicon recommended), Homebrew installed (`https://brew.sh` — bootstrap never runs the Homebrew
  installer for you; it prints what to do), Xcode CLT.

## Steps
1. `git clone` the repo and `cd` into it.
2. `./scripts/bootstrap.sh --dry-run` — prints every action, changes nothing.
3. `./scripts/bootstrap.sh` — add `--yes` to skip the confirmation prompt (e.g. in automation).

## What bootstrap does (in order)
1. `install.sh --skip-plugins`: for each formula in `manifest/Brewfile` runs `brew install` **only if the command is
   not already on PATH** (so your `/usr/local/go`, nvm node etc. are respected, and nothing is upgraded). Then:
   - **netcoredbg** 3.2.0-1092 (arm64): downloaded over HTTPS, sha256 checked against `manifest/tools.lock`, installed
     to `~/.local/share/dev-env/netcoredbg`. Mismatch aborts.
   - **roslyn-language-server** 5.13.0-1.26513.11: `dotnet tool install --tool-path` from Microsoft's official
     Azure DevOps feed, into `~/.local/share/dev-env/roslyn`.
   - **goimports** v0.38.0: `go install` using `proxy.golang.org` + `sum.golang.org` for this one command only.
2. `backup.sh link`: if `~/.config/nvim` exists it is copied to `~/.local/state/dev-env/backups/<timestamp>/`, then
   replaced by a symlink to `nvim/`. Asks first. Skipped if already linked.
3. `nvim --headless "+Lazy! restore"`: installs plugins at the commits in `nvim/lazy-lock.json`.
4. Mason installs: basedpyright, ruff, bash-language-server, lua-language-server, typescript-language-server, debugpy,
   js-debug-adapter (versions float at install time; see UPGRADING).
5. `check.sh`.

The final summary lists INSTALLED / SKIPPED / FAILED / MANUAL. Exit code is non-zero if anything failed.

## Manual steps that may remain
- Homebrew itself (if missing).
- Intel Macs: netcoredbg must be built from source (docs/DOTNET.md).
- Ensure `~/.local/share/dev-env/bin` need not be on your shell PATH — Neovim adds it itself. For using `goimports` in a terminal, add it yourself.

## Environment variables (all optional)
`NVIM_TARGET` (config location, default `~/.config/nvim`), `DEVENV_DATA` (default `~/.local/share/dev-env`),
`DEVENV_STATE` (default `~/.local/state/dev-env`).

## Uninstall / revert
`./scripts/backup.sh list` then `./scripts/backup.sh restore <timestamp>` restores the previous config (the current one
is backed up first). Installed tools can be removed with `brew uninstall` and by deleting `~/.local/share/dev-env`.
