# Upgrading and rollback

## What is pinned
| Component | Mechanism | How to change on purpose |
|---|---|---|
| Neovim plugins (incl. lazy.nvim) | `nvim/lazy-lock.json` (commit hashes) | `./scripts/update.sh --plugins`, review `git diff nvim/lazy-lock.json`, `./scripts/test.sh`, commit |
| netcoredbg | version + sha256 in `manifest/tools.lock` | edit both, re-run `install.sh` (it re-downloads when the version differs), run tests |
| Roslyn LSP | `ROSLYN_VERSION` in `scripts/install.sh` | edit, re-run `install.sh` (reinstalls when the pinned version differs), run tests |
| goimports | version in `scripts/install.sh` | edit; remove `~/.local/share/dev-env/bin/goimports`; re-run `install.sh` (it skips if the binary exists) |
| Mason tools | **not pinned** (latest at first install) | `./scripts/update.sh --mason` to upgrade; record versions with `:Mason` if you need exact reproducibility |
| Homebrew tools (nvim, go, dotnet, gopls, dlv…) | not pinned; never upgraded by scripts | `brew upgrade <name>` yourself, then `./scripts/test.sh` |
`install.sh` never upgrades anything that already exists, so routine runs cannot cause major-version jumps.

## Recommended upgrade routine
1. `git status` clean. 2. `./scripts/update.sh --plugins` (lockfile backup saved to `~/.local/state/dev-env/`).
3. `./scripts/test.sh`. 4. Commit if green, `./scripts/update.sh --rollback` if not.

After a **.NET SDK or netcoredbg change** always re-run `./scripts/test.sh` — debugger/SDK compatibility on macOS arm64
has broken before.

## Rollback
- Plugins: `./scripts/update.sh --rollback` (checks out the committed lockfile, `Lazy restore`).
- Whole config: `./scripts/backup.sh list` / `restore <timestamp>` returns `~/.config/nvim` to what it was before
  bootstrap (your original `init.lua` + lockfile are in the first backup). The current state is backed up first and
  backup directories are never overwritten.
- Tool binaries: delete `~/.local/share/dev-env/<tool>` and re-run `install.sh` with the older pin.
