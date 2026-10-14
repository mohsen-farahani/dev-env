#!/usr/bin/env bash
# Usage: backup.sh create | list | restore <timestamp> [--yes] | link [--yes] [--dry-run]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
parse_common_flags "$@"
set -- "${ARGS[@]+"${ARGS[@]}"}"
BACKUPS="$DEVENV_STATE/backups"

cmd_create() { # prints backup dir on stdout (last line)
  if [[ ! -e "$NVIM_TARGET" && ! -L "$NVIM_TARGET" ]]; then
    detail "no existing config at $NVIM_TARGET; nothing to back up" >&2
    return 0
  fi
  local ts dir
  ts="$(date +%Y%m%d-%H%M%S)"
  dir="$BACKUPS/$ts"
  local n=1
  while [[ -e "$dir" ]]; do # never reuse or overwrite an existing backup
    dir="$BACKUPS/$ts-$n"
    n=$((n + 1))
  done
  if [[ -L "$NVIM_TARGET" ]]; then
    run mkdir -p "$dir"
    [[ "$DRY_RUN" == 1 ]] || readlink "$NVIM_TARGET" >"$dir/symlink-target"
    detail "recorded symlink target for $NVIM_TARGET" >&2
  else
    run mkdir -p "$dir"
    run cp -a "$NVIM_TARGET" "$dir/nvim"
  fi
  if [[ "$DRY_RUN" == 1 ]]; then detail "would back up to: $dir" >&2; else detail "backup saved: $dir" >&2; fi
  echo "$dir"
}

cmd_list() { ls -1 "$BACKUPS" 2>/dev/null || log "(no backups)"; }

cmd_restore() {
  local ts="${1:?usage: restore <timestamp>}" dir="$BACKUPS/${1}"
  [[ -d "$dir" ]] || {
    fail "no such backup: $dir"
    exit 1
  }
  confirm "Replace $NVIM_TARGET with backup $ts (current config will be backed up first)?" || exit 1
  cmd_create >/dev/null
  run rm -rf "$NVIM_TARGET"
  if [[ -f "$dir/symlink-target" ]]; then
    run ln -s "$(cat "$dir/symlink-target")" "$NVIM_TARGET"
  else run cp -a "$dir/nvim" "$NVIM_TARGET"; fi
  pass "restored $ts"
}

cmd_link() { # point NVIM_TARGET at repo nvim/ (backup first, idempotent)
  local src="$REPO_ROOT/nvim"
  if [[ -L "$NVIM_TARGET" && "$(readlink "$NVIM_TARGET")" == "$src" ]]; then
    skipped "nvim config already linked"
    return 0
  fi
  if [[ -e "$NVIM_TARGET" || -L "$NVIM_TARGET" ]]; then
    confirm "Existing config at $NVIM_TARGET will be backed up and replaced by a symlink to $src. Continue?" || {
      manual "link nvim config ($NVIM_TARGET)"
      return 0
    }
    cmd_create >/dev/null
    run rm -rf "$NVIM_TARGET"
  fi
  run mkdir -p "$(dirname "$NVIM_TARGET")"
  run ln -s "$src" "$NVIM_TARGET"
  installed "nvim config symlink -> $src"
}

case "${1:-}" in
create) cmd_create ;;
list) cmd_list ;;
restore)
  shift
  cmd_restore "$@"
  ;;
link)
  cmd_link
  print_report
  ;;
*)
  sed -n '2p' "$0"
  exit 2
  ;;
esac
