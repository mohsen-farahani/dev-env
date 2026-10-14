#!/usr/bin/env bash
# One-command setup: ./scripts/bootstrap.sh [--dry-run] [--yes]
# Order: prerequisites -> backup + link config -> plugins/Mason tools -> health check.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib/common.sh"
parse_common_flags "$@"
FLAGS=("$@")

# One report, one log and one step counter shared with the scripts we call.
export DEVENV_REPORT="$REPORT_FILE" DEVENV_LOG="$LOG_FILE" DEVENV_CHILD=1 DEVENV_STEP_TOTAL=8
STEP_TOTAL=8
CHILD=0 # bootstrap itself prints the banner
banner "dev-env bootstrap" "Neovim IDE for macOS - safe to re-run (idempotent)"
[[ "$DRY_RUN" == 1 ]] && log "  ${C_Y}dry-run: nothing will be changed${C_0}"
log "  ${C_D}full log: $LOG_FILE${C_0}"

# steps 1-5: platform, brew packages, netcoredbg, Roslyn, goimports
"$HERE/install.sh" --skip-plugins "${FLAGS[@]+"${FLAGS[@]}"}" || true
STEP_N=5

step "Linking the Neovim config"
detail "existing $NVIM_TARGET is backed up first, never overwritten"
"$HERE/backup.sh" link "${FLAGS[@]+"${FLAGS[@]}"}" || _rec FAILED "link nvim config"

step "Plugins and language servers"
if [[ "$DRY_RUN" == 1 ]]; then
  do_step "Restoring plugins from lazy-lock.json" "plugins (lazy-lock.json)" true || true
  do_step "Installing language servers / debug adapters (Mason)" "Mason tools" true || true
elif [[ -L "$NVIM_TARGET" && "$(readlink "$NVIM_TARGET")" == "$REPO_ROOT/nvim" ]]; then
  do_step "Restoring plugins from lazy-lock.json" "plugins (lazy-lock.json)" nvim --headless "+Lazy! restore" +qa || true
  do_step "Installing language servers / debug adapters (Mason)" "Mason tools" nvim --headless "+lua require('devenv.tools').install_sync()" +qa || true
else
  manual "config not linked, so plugins were not installed (run scripts/backup.sh link, then scripts/install.sh)"
fi

step "Health check"
CHECK_RC=0
if [[ "$DRY_RUN" == 1 ]]; then
  detail "[dry-run] skipped"
else
  "$HERE/check.sh" || CHECK_RC=$?
fi

render_report
RC=0
grep -q '^FAILED|' "$REPORT_FILE" 2>/dev/null && RC=1
[[ "$CHECK_RC" -ne 0 ]] && RC=1
rm -f "$REPORT_FILE"

printf '\n'
if [[ "$DRY_RUN" == 1 ]]; then
  log "${C_B}Dry run complete.${C_0} Re-run without --dry-run to apply."
elif [[ "$RC" -eq 0 ]]; then
  log "${C_G}${C_B}${SYM_OK} All done.${C_0}  Next:"
  log "   1. Open a new terminal and run ${C_B}nvim${C_0}  ${C_D}(first launch compiles syntax parsers; give it a minute)${C_0}"
  log "   2. ${C_B}:checkhealth devenv${C_0}  ${C_D}inside Neovim, any time${C_0}"
  log "   3. Try debugging C#:  ${C_B}nvim samples/dotnet-sample/src/Calc/Calculator.cs${C_0}"
  log "      ${C_D}<Space>b on a line, then <Space>dc (or F5), arguments: 5${C_0}"
  log "   4. Keys & guides: docs/KEYMAPS.md, docs/USAGE.md"
  log "   ${C_D}Roll back anytime: ./scripts/backup.sh list && ./scripts/backup.sh restore <timestamp>${C_0}"
else
  log "${C_R}${C_B}${SYM_FAIL} Finished with problems.${C_0} See the summary above and the log: $LOG_FILE"
  log "   ${C_D}Fix and re-run - bootstrap skips what is already done.${C_0}"
fi
exit "$RC"
