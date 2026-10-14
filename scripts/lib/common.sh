#!/usr/bin/env bash
# Shared helpers. Source, do not execute.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEVENV_DATA="${DEVENV_DATA:-$HOME/.local/share/dev-env}"
DEVENV_STATE="${DEVENV_STATE:-$HOME/.local/state/dev-env}"
NVIM_TARGET="${NVIM_TARGET:-$HOME/.config/nvim}"
DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"
NETCOREDBG_DIR="$DEVENV_DATA/netcoredbg"
REPORT_FILE="$(mktemp -t devenv-report.XXXXXX)"

if [[ -t 1 ]]; then C_G=$'\e[32m'; C_Y=$'\e[33m'; C_R=$'\e[31m'; C_0=$'\e[0m'; else C_G=; C_Y=; C_R=; C_0=; fi

log()   { printf '%s\n' "$*"; }
_rec()  { printf '%s|%s\n' "$1" "$2" >>"$REPORT_FILE"; }
pass()  { printf '%s[PASS]%s %s\n' "$C_G" "$C_0" "$*"; }
warn()  { printf '%s[WARN]%s %s\n' "$C_Y" "$C_0" "$*"; }
fail()  { printf '%s[FAIL]%s %s\n' "$C_R" "$C_0" "$*"; }
installed() {
  if [[ "$DRY_RUN" == 1 ]]; then _rec INSTALLED "(would install) $1"; log "[dry-run] would install: $1"
  else _rec INSTALLED "$1"; pass "installed: $1"; fi
}
skipped()   { _rec SKIPPED "$1";   log  "[skip] $1"; }
failed()    { _rec FAILED "$1";    fail "$1"; }
manual()    { _rec MANUAL "$1";    warn "manual action: $1"; }

have() { command -v "$1" >/dev/null 2>&1; }

run() { # run a mutating command, honouring dry-run
  if [[ "$DRY_RUN" == 1 ]]; then log "[dry-run] $*"; return 0; fi
  "$@"
}

confirm() { # confirm "question"
  [[ "$ASSUME_YES" == 1 ]] && return 0
  [[ "$DRY_RUN" == 1 ]] && return 0
  [[ -t 0 ]] || { fail "needs confirmation but stdin is not a TTY (use --yes)"; return 1; }
  read -r -p "$1 [y/N] " a; [[ "$a" == y || "$a" == Y ]]
}

parse_common_flags() { # sets DRY_RUN / ASSUME_YES; leaves remaining in ARGS
  ARGS=()
  for a in "$@"; do
    case "$a" in
      --dry-run) DRY_RUN=1 ;;
      -y|--yes)  ASSUME_YES=1 ;;
      *) ARGS+=("$a") ;;
    esac
  done
}

detect_platform() {
  OS="$(uname -s)"; ARCH="$(uname -m)"
  [[ "$OS" == Darwin ]] || { fail "macOS only (found $OS)"; return 1; }
  MACOS_VERSION="$(sw_vers -productVersion)"
  if [[ -x /opt/homebrew/bin/brew ]]; then BREW=/opt/homebrew/bin/brew
  elif [[ -x /usr/local/bin/brew ]]; then BREW=/usr/local/bin/brew
  else BREW=""; fi
  [[ -n "$BREW" ]] && eval "$("$BREW" shellenv)"
  return 0
}

print_report() { # returns non-zero if anything failed
  local rc=0
  grep -q '^FAILED|' "$REPORT_FILE" 2>/dev/null && rc=1
  log ""; log "==== Summary ===="
  for k in INSTALLED SKIPPED FAILED MANUAL; do
    local items; items="$(grep "^$k|" "$REPORT_FILE" | cut -d'|' -f2-)"
    if [[ -n "$items" ]]; then log "$k:"; while IFS= read -r l; do log "  - $l"; done <<<"$items"; fi
  done
  rm -f "$REPORT_FILE"
  return $rc
}
