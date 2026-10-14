#!/usr/bin/env bash
# Health check. Usage: check.sh [--deep]   (--deep also runs LSP attach checks on the samples)
# Exit code 1 if any FAIL. Read-only.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
detect_platform || exit 1
# Numbered steps when run alone; plain sub-headings when called from bootstrap.
if [[ "${1:-}" == "--deep" ]]; then STEP_TOTAL=3; else STEP_TOTAL=2; fi
section() {
  if [[ "$CHILD" == 1 ]]; then printf '\n  %s%s%s\n' "$C_B" "$1" "$C_0"; else step "$1"; fi
}
banner "dev-env health check" "read-only; exit code 1 on any FAIL"
section "System"
log "macOS $MACOS_VERSION / $ARCH / shell $(basename "${SHELL:-?}")"
[[ -n "$BREW" ]] && pass "Homebrew at $BREW" || warn "Homebrew not found"
[[ "$ARCH" == arm64 ]] || warn "Intel Mac: C# debugging (netcoredbg) has no prebuilt binary; see docs/DOTNET.md"
if [[ -L "$NVIM_TARGET" && "$(readlink "$NVIM_TARGET")" == "$REPO_ROOT/nvim" ]]; then
  pass "$NVIM_TARGET -> repo nvim/"
elif [[ -e "$NVIM_TARGET" ]]; then
  warn "$NVIM_TARGET is not linked to this repo (run scripts/backup.sh link)"
else warn "$NVIM_TARGET does not exist (run scripts/bootstrap.sh)"; fi

log ""
# If the live config is not (yet) this repo's, check the repo config instead (live data dir, temp config dir).
NVIM_ENV=(env DEVENV_NO_INSTALL=1) # read-only: never let lazy.nvim install plugins during a check
if [[ -L "$NVIM_TARGET" && "$(readlink "$NVIM_TARGET")" == "$REPO_ROOT/nvim" ]]; then
  section "Neovim environment (live config)"
else
  CFG_TMP="$(mktemp -d)"
  ln -s "$REPO_ROOT/nvim" "$CFG_TMP/nvim"
  NVIM_ENV=(env "XDG_CONFIG_HOME=$CFG_TMP" DEVENV_NO_INSTALL=1)
  section "Neovim environment (repo config; live config is not linked yet)"
fi

# Headless nvim with stdin closed and a watchdog, so a broken config can never hang the check.
run_nvim() {
  "$@" </dev/null &
  local pid=$!
  # The watchdog must not inherit our stdout: a leftover `sleep` holding the pipe open would make the
  # downstream `| grep` wait for the whole timeout even though nvim already exited.
  (
    sleep "${CHECK_TIMEOUT:-180}"
    kill "$pid" 2>/dev/null
  ) >/dev/null 2>&1 &
  local wd=$!
  wait "$pid"
  local r=$?
  pkill -P "$wd" 2>/dev/null
  kill "$wd" 2>/dev/null
  wait "$wd" 2>/dev/null
  return "$r"
}

run_nvim "${NVIM_ENV[@]}" nvim --headless "+lua require('devenv.health').run_cli()" 2>&1 | grep -v '^\[nvim-treesitter' | colorize_health
rc=${PIPESTATUS[0]}

if [[ "${1:-}" == "--deep" ]]; then
  log ""
  section "Deep: LSP attach on samples"
  cd "$REPO_ROOT" || exit 1
  deep() { FILE="$2" CLIENT="$3" SYMBOL="$4" BAD="$5" BAD_PATTERN="$6" DEF_FILE="$7" TIMEOUT=90000 nvim --headless -c "luafile tests/lsp_check.lua" >/dev/null 2>&1 && pass "$1" || {
    fail "$1"
    rc=1
  }; }
  deep "gopls on go sample" samples/go-hello/main.go gopls "Sum(" 'var x int = "s"' "cannot use" main.go
  deep "roslyn on C# sample" samples/dotnet-sample/src/App/Program.cs roslyn "Factorial(" 'int y = "s";' "convert" Calculator.cs
  deep "basedpyright on py" samples/py-hello/app.py basedpyright "add(" 'x: int = "s"' "not assignable" app.py
fi
exit "$rc"
