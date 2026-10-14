#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables are consumed by the scripts that source this file
# Shared helpers (logic + terminal UI). Source, do not execute.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEVENV_DATA="${DEVENV_DATA:-$HOME/.local/share/dev-env}"
DEVENV_STATE="${DEVENV_STATE:-$HOME/.local/state/dev-env}"
NVIM_TARGET="${NVIM_TARGET:-$HOME/.config/nvim}"
DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"
NETCOREDBG_DIR="$DEVENV_DATA/netcoredbg"
# bootstrap.sh exports these so the scripts it calls share one report, one log and one step counter.
REPORT_FILE="${DEVENV_REPORT:-$(mktemp -t devenv-report.XXXXXX)}"
LOG_FILE="${DEVENV_LOG:-$DEVENV_STATE/logs/$(basename "$0" .sh)-$(date +%Y%m%d-%H%M%S).log}"
STEP_N="${DEVENV_STEP_START:-0}"
STEP_TOTAL="${DEVENV_STEP_TOTAL:-5}"
CHILD="${DEVENV_CHILD:-0}" # 1 = called from bootstrap: no banner / final summary

# ---------- terminal capabilities ----------
IS_TTY=0
if [[ -t 1 && "${TERM:-dumb}" != dumb && -z "${NO_COLOR:-}" ]]; then IS_TTY=1; fi

if [[ "$IS_TTY" == 1 ]]; then
  C_0=$'\e[0m'
  C_B=$'\e[1m'
  C_D=$'\e[2m'
  C_R=$'\e[31m'
  C_G=$'\e[32m'
  C_Y=$'\e[33m'
  C_C=$'\e[36m'
  SYM_OK="✔"
  SYM_WARN="⚠"
  SYM_FAIL="✘"
  SYM_SKIP="○"
  SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
else
  C_0='' C_B='' C_D='' C_R='' C_G='' C_Y='' C_C=''
  SYM_OK="[PASS]"
  SYM_WARN="[WARN]"
  SYM_FAIL="[FAIL]"
  SYM_SKIP="[skip]"
  SPIN=()
fi

# ---------- output primitives ----------
log() { printf '%s\n' "$*"; }
_rec() { printf '%s|%s\n' "$1" "$2" >>"$REPORT_FILE"; }
pass() { printf '  %s%s%s %s\n' "$C_G" "$SYM_OK" "$C_0" "$*"; }
warn() { printf '  %s%s%s %s\n' "$C_Y" "$SYM_WARN" "$C_0" "$*"; }
fail() { printf '  %s%s%s %s\n' "$C_R" "$SYM_FAIL" "$C_0" "$*"; }

banner() { # banner "title" "subtitle"
  [[ "$CHILD" == 1 ]] && return 0
  local w=58
  if [[ "$IS_TTY" == 1 ]]; then
    printf '\n%s╭%s╮%s\n' "$C_C" "$(printf '─%.0s' $(seq 1 $w))" "$C_0"
    printf '%s│%s  %s%-*s%s%s│%s\n' "$C_C" "$C_0" "$C_B" $((w - 2)) "$1" "$C_0" "$C_C" "$C_0"
    printf '%s│%s  %s%-*s%s%s│%s\n' "$C_C" "$C_0" "$C_D" $((w - 2)) "$2" "$C_0" "$C_C" "$C_0"
    printf '%s╰%s╯%s\n' "$C_C" "$(printf '─%.0s' $(seq 1 $w))" "$C_0"
  else
    printf '== %s - %s ==\n' "$1" "$2"
  fi
}

step() { # step "title"  -> "▸ [2/8] title"
  STEP_N=$((STEP_N + 1))
  printf '\n%s%s[%d/%d]%s %s%s%s\n' "$C_C" "$C_B" "$STEP_N" "$STEP_TOTAL" "$C_0" "$C_B" "$1" "$C_0"
}

detail() { printf '    %s%s%s\n' "$C_D" "$*" "$C_0"; }

installed() { # record + print an install that already happened (or would happen in dry-run)
  if [[ "$DRY_RUN" == 1 ]]; then
    _rec INSTALLED "(would install) $1"
    printf '  %s○%s %swould install:%s %s\n' "$C_Y" "$C_0" "$C_D" "$C_0" "$1"
  else
    _rec INSTALLED "$1"
    printf '  %s%s%s installed: %s\n' "$C_G" "$SYM_OK" "$C_0" "$1"
  fi
}
skipped() {
  _rec SKIPPED "$1"
  printf '  %s%s %s%s\n' "$C_D" "$SYM_SKIP" "$1" "$C_0"
}
failed() {
  _rec FAILED "$1"
  printf '  %s%s%s %s\n' "$C_R" "$SYM_FAIL" "$C_0" "$1"
}
manual() {
  _rec MANUAL "$1"
  printf '  %s%s%s manual action: %s\n' "$C_Y" "$SYM_WARN" "$C_0" "$1"
}

have() { command -v "$1" >/dev/null 2>&1; }

run() { # run a mutating command, honouring dry-run
  if [[ "$DRY_RUN" == 1 ]]; then
    detail "[dry-run] $*"
    return 0
  fi
  "$@"
}

# spin "label" cmd...   Runs cmd with a spinner; all output goes to the log file.
# Prints a result line; on failure shows the tail of the output. Returns the command's status.
# In dry-run mode only prints what would run.
spin() {
  local label="$1"
  shift
  if [[ "$DRY_RUN" == 1 ]]; then
    printf '  %s○%s %s[dry-run]%s %s\n' "$C_Y" "$C_0" "$C_D" "$C_0" "$label"
    return 0
  fi
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '\n$ %s\n' "$*" >>"$LOG_FILE"
  local start=$SECONDS rc=0 mark
  mark="$(wc -l <"$LOG_FILE" | tr -d ' ')"
  "$@" >>"$LOG_FILE" 2>&1 </dev/null &
  local pid=$!
  if [[ "$IS_TTY" == 1 ]]; then
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
      printf '\r  %s%s%s %s %s(%ds)%s' "$C_C" "${SPIN[$((i % 10))]}" "$C_0" "$label" "$C_D" $((SECONDS - start)) "$C_0"
      i=$((i + 1))
      sleep 0.1
    done
    printf '\r\033[K'
  else
    printf '  ... %s\n' "$label"
  fi
  wait "$pid" || rc=$?
  local secs=$((SECONDS - start))
  if [[ $rc -eq 0 ]]; then
    printf '  %s%s%s %s %s(%ds)%s\n' "$C_G" "$SYM_OK" "$C_0" "$label" "$C_D" "$secs" "$C_0"
  else
    printf '  %s%s%s %s %s(failed after %ds)%s\n' "$C_R" "$SYM_FAIL" "$C_0" "$label" "$C_D" "$secs" "$C_0"
    tail -n +"$((mark + 1))" "$LOG_FILE" | tail -n 12 | sed "s/^/      ${C_D}| /;s/\$/${C_0}/"
    printf '      %sfull log: %s%s\n' "$C_D" "$LOG_FILE" "$C_0"
  fi
  return $rc
}

# do_step "spinner label" "report text" cmd...   spin + record INSTALLED / FAILED in the report.
do_step() {
  local label="$1" text="$2"
  shift 2
  if spin "$label" "$@"; then
    if [[ "$DRY_RUN" == 1 ]]; then _rec INSTALLED "(would install) $text"; else _rec INSTALLED "$text"; fi
    return 0
  fi
  _rec FAILED "$text"
  return 1
}

confirm() { # confirm "question"
  [[ "$ASSUME_YES" == 1 ]] && return 0
  [[ "$DRY_RUN" == 1 ]] && return 0
  [[ -t 0 ]] || {
    fail "needs confirmation but stdin is not a TTY (use --yes)"
    return 1
  }
  local a
  read -r -p "  ${C_Y}?${C_0} $1 [y/N] " a
  [[ "$a" == y || "$a" == Y ]]
}

parse_common_flags() { # sets DRY_RUN / ASSUME_YES; leaves remaining in ARGS
  ARGS=()
  for a in "$@"; do
    case "$a" in
    --dry-run) DRY_RUN=1 ;;
    -y | --yes) ASSUME_YES=1 ;;
    *) ARGS+=("$a") ;;
    esac
  done
}

detect_platform() {
  OS="$(uname -s)"
  ARCH="$(uname -m)"
  [[ "$OS" == Darwin ]] || {
    fail "macOS only (found $OS)"
    return 1
  }
  MACOS_VERSION="$(sw_vers -productVersion)"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    BREW=/opt/homebrew/bin/brew
  elif [[ -x /usr/local/bin/brew ]]; then
    BREW=/usr/local/bin/brew
  else BREW=""; fi
  [[ -n "$BREW" ]] && eval "$("$BREW" shellenv)"
  return 0
}

# Colorize "[PASS]/[WARN]/[FAIL]" lines coming from the Lua health check (stdin -> stdout).
colorize_health() {
  if [[ "$IS_TTY" != 1 ]]; then
    cat
    return
  fi
  sed -e "s/^\[PASS\]/  ${C_G}${SYM_OK}${C_0}/" \
    -e "s/^\[WARN\]/  ${C_Y}${SYM_WARN}${C_0}/" \
    -e "s/^\[FAIL\]/  ${C_R}${SYM_FAIL}${C_0}/" \
    -e "s/^Summary:/${C_B}Summary:${C_0}/"
}

print_report() { # returns non-zero if anything failed. Skipped when called from bootstrap.
  local rc=0
  grep -q '^FAILED|' "$REPORT_FILE" 2>/dev/null && rc=1
  [[ "$CHILD" == 1 ]] && return $rc
  render_report
  rm -f "$REPORT_FILE"
  return $rc
}

render_report() {
  printf '\n%s%s Summary%s\n' "$C_B" "─────────" "$C_0"
  local k items label color sym n
  for k in INSTALLED SKIPPED FAILED MANUAL; do
    items="$(grep "^$k|" "$REPORT_FILE" 2>/dev/null | cut -d'|' -f2- || true)"
    [[ -z "$items" ]] && continue
    n="$(printf '%s\n' "$items" | wc -l | tr -d ' ')"
    case "$k" in
    INSTALLED) label="Installed" color=$C_G sym=$SYM_OK ;;
    SKIPPED) label="Already present" color=$C_D sym=$SYM_SKIP ;;
    FAILED) label="Failed" color=$C_R sym=$SYM_FAIL ;;
    MANUAL) label="Needs manual action" color=$C_Y sym=$SYM_WARN ;;
    esac
    printf '  %s%s%s %s%s (%s)%s\n' "$color" "$sym" "$C_0" "$C_B" "$label" "$n" "$C_0"
    [[ "$k" == SKIPPED ]] && continue # just the count; details were shown per step
    while IFS= read -r l; do printf '      %s%s%s\n' "$C_D" "$l" "$C_0"; done <<<"$items"
  done
  if [[ -n "${LOG_FILE:-}" && -f "$LOG_FILE" ]]; then printf '\n  %slog: %s%s\n' "$C_D" "$LOG_FILE" "$C_0"; fi
  return 0
}
