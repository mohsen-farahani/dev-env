#!/usr/bin/env bash
# Automated smoke tests. Everything runs against samples/ and temp copies; your real config/projects are untouched.
# Neovim runs in an isolated XDG sandbox (own plugins, Mason tools, state) under $DEVENV_STATE/test-sandbox.
# Usage: test.sh [--quick] [--fresh]    --quick: static checks + startup + health only; --fresh: rebuild sandbox
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
QUICK=0
FRESH=0
for a in "$@"; do
  [[ "$a" == --quick ]] && QUICK=1
  [[ "$a" == --fresh ]] && FRESH=1
done
cd "$REPO_ROOT" || exit 1

PASSED=0
FAILED=0
RESULTS=()
t() { # t "name" cmd...
  local name="$1"
  shift
  local out
  out="$("$@" 2>&1)"
  local rc=$?
  if [[ $rc -eq 0 ]]; then
    PASSED=$((PASSED + 1))
    RESULTS+=("PASS  $name")
    pass "$name"
  else
    FAILED=$((FAILED + 1))
    RESULTS+=("FAIL  $name")
    fail "$name"
    printf '%s\n' "$out" | grep -v '^\[nvim-treesitter' | tail -15 | sed 's/^/        /'
  fi
}
skip() {
  RESULTS+=("SKIP  $1 ($2)")
  warn "skipped: $1 ($2)"
}

# ---- static ----
log "== Static checks =="
SH_FILES=(scripts/*.sh scripts/lib/common.sh)
if have shellcheck; then t "shellcheck scripts" shellcheck -x "${SH_FILES[@]}"; else skip "shellcheck" "not installed"; fi
if have shfmt; then t "shfmt scripts" shfmt -d -i 2 "${SH_FILES[@]}"; else skip "shfmt" "not installed"; fi
if have stylua; then t "stylua nvim config" stylua --check nvim tests; else skip "stylua" "not installed"; fi
t "python syntax (dap_smoke)" python3 -I -c "import ast,sys; ast.parse(open('tests/dap_smoke.py').read())"

# ---- sandbox ----
SANDBOX="${DEVENV_TEST_SANDBOX:-$DEVENV_STATE/test-sandbox}"
[[ "$FRESH" == 1 ]] && rm -rf "$SANDBOX"
mkdir -p "$SANDBOX"/{config,data,state,cache}
ln -sfn "$REPO_ROOT/nvim" "$SANDBOX/config/nvim"
export XDG_CONFIG_HOME="$SANDBOX/config" XDG_DATA_HOME="$SANDBOX/data" XDG_STATE_HOME="$SANDBOX/state" XDG_CACHE_HOME="$SANDBOX/cache"
log ""
log "== Sandbox: $SANDBOX =="
t "plugins restore from lockfile" nvim --headless "+Lazy! restore" +qa
t "mason tools installed" nvim --headless "+lua require('devenv.tools').install_sync()" +qa

log ""
log "== Startup & health =="
t "starts without errors" bash -c '
  out=$(nvim --headless "+lua if vim.v.errmsg ~= \"\" then io.stderr:write(vim.v.errmsg) vim.cmd(\"cquit 1\") end" +qa 2>&1); rc=$?
  [[ $rc -eq 0 && -z "$(grep -iE "error|E5[0-9]{3}" <<<"$out" | grep -v nvim-treesitter)" ]] || { echo "$out"; exit 1; }'
t "health check (no FAIL)" nvim --headless "+lua require('devenv.health').run_cli()" +qa

if [[ "$QUICK" == 0 ]]; then
  log ""
  log "== Sample projects build =="
  t "dotnet build sample solution (.slnx)" dotnet build samples/dotnet-sample/Sample.slnx --nologo -v q
  t "go test sample" bash -c 'cd samples/go-hello && go test ./...'

  log ""
  log "== LSP: attach, hover, definition, diagnostics =="
  lsp() { # name file client symbol bad pattern deffile [timeout]
    t "$1" env FILE="$2" CLIENT="$3" SYMBOL="$4" BAD="$5" BAD_PATTERN="$6" DEF_FILE="$7" TIMEOUT="${8:-60000}" nvim --headless -c "luafile tests/lsp_check.lua"
  }
  lsp "Go (gopls)" samples/go-hello/main.go gopls "Sum(" 'var x int = "s"' "cannot use" main.go
  lsp "C# (roslyn, .slnx, cross-project definition)" samples/dotnet-sample/src/App/Program.cs roslyn "Factorial(" 'int y = "s";' "convert" Calculator.cs 120000
  lsp "Python (basedpyright)" samples/py-hello/app.py basedpyright "add(" 'x: int = "s"' "not assignable" app.py
  lsp "TypeScript (ts_ls)" samples/ts-hello/index.ts ts_ls "greet(" 'const n: number = "s";' "not assignable" index.ts
  lsp "Bash (bashls+shellcheck)" samples/misc/hello.sh bashls "" 'echo $a' "referenced but not assigned" ""
  t "Lua (lua_ls, Neovim API aware)" env FILE=samples/misc/example.lua CLIENT=lua_ls BAD='vim.api.nvim_get_current_buf(1, 2, 3)' BAD_PATTERN=maximum BAD_AT_TOP=1 TIMEOUT=60000 nvim --headless -c "luafile tests/lsp_check.lua"

  log ""
  log "== Formatting on save =="
  t "format on save (go, python, bash, lua, ts, C#)" nvim --headless -c "luafile tests/format_check.lua"

  log ""
  log "== Build / test commands =="
  t "dotnet build (qf errors), dotnet test, go test at cursor" nvim --headless -c "luafile tests/run_check.lua"

  log ""
  log "== Git blame =="
  t "gitsigns inline blame shows author/commit" nvim --headless -c "luafile tests/blame_check.lua"

  log ""
  log "== Debug adapters (raw DAP protocol) =="
  for cfg in go_break go_test cs_break cs_exception; do
    tmp="$(mktemp -t dapcfg.XXXXXX)"
    sed -e "s|@REPO@|$REPO_ROOT|g" -e "s|@HOME@|$HOME|g" "tests/dap/$cfg.json" >"$tmp"
    if [[ "$cfg" == cs_* && "$(uname -m)" != arm64 ]]; then
      skip "$cfg" "netcoredbg arm64 only"
      rm -f "$tmp"
      continue
    fi
    t "$(python3 -I -c "import json;print(json.load(open('$tmp'))['name'])")" python3 -I tests/dap_smoke.py "$tmp"
    rm -f "$tmp"
  done

  log ""
  log "== Debugging through nvim-dap (real keymap path, repo adapter config) =="
  t "nvim-dap: Go session" env KIND=go nvim --headless -c "luafile tests/dap_nvim.lua"
  if [[ "$(uname -m)" == arm64 ]]; then
    t "nvim-dap: C# session (build -> launch -> breakpoint -> locals -> step)" env KIND=cs nvim --headless -c "luafile tests/dap_nvim.lua"
  else skip "nvim-dap: C# session" "netcoredbg arm64 only"; fi
fi

log ""
log "==== Test summary ===="
printf '%s\n' "${RESULTS[@]}"
log "passed=$PASSED failed=$FAILED"
log ""
log "NOT covered by automated tests: Python/Node debug sessions, .NET attach-to-process, Go attach, DAP UI rendering,"
log "interactive keymaps, multi-SDK/global.json selection."
[[ $FAILED -eq 0 ]]
