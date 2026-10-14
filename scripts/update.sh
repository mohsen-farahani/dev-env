#!/usr/bin/env bash
# Controlled updates. Nothing changes unless you pass a flag; each flag is intentional.
#   update.sh --plugins   update plugins (backs up lazy-lock.json first; review the diff, then commit)
#   update.sh --mason     update Mason-managed tools
#   update.sh --rollback  restore lazy-lock.json from the last committed version and re-sync
# Brew-managed tools (go, dotnet, nvim, ...) are upgraded manually: `brew upgrade <name>`.
# netcoredbg is bumped by editing manifest/tools.lock (version+sha256) and re-running install.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
LOCK="$REPO_ROOT/nvim/lazy-lock.json"
case "${1:-}" in
--plugins)
  cp "$LOCK" "$DEVENV_STATE/lazy-lock.$(date +%Y%m%d-%H%M%S).json" 2>/dev/null || {
    mkdir -p "$DEVENV_STATE"
    cp "$LOCK" "$DEVENV_STATE/lazy-lock.$(date +%Y%m%d-%H%M%S).json"
  }
  nvim --headless "+Lazy! update" +qa
  git -C "$REPO_ROOT" diff --stat -- nvim/lazy-lock.json
  log "Review, run scripts/test.sh, then commit the lockfile."
  ;;
--mason) nvim --headless "+lua require('devenv.tools').install_sync(true)" +qa ;;
--rollback)
  git -C "$REPO_ROOT" checkout -- nvim/lazy-lock.json
  nvim --headless "+Lazy! restore" +qa
  pass "plugins restored to committed lockfile"
  ;;
*)
  sed -n '2,8p' "$0"
  exit 2
  ;;
esac
