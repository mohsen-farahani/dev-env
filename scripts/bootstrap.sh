#!/usr/bin/env bash
# One-command setup: ./scripts/bootstrap.sh [--dry-run] [--yes]
# Order: prerequisites -> backup + link config -> plugins/Mason tools -> health check.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAGS=("$@")
"$HERE/install.sh" --skip-plugins "${FLAGS[@]+"${FLAGS[@]}"}"
"$HERE/backup.sh" link "${FLAGS[@]+"${FLAGS[@]}"}"
if [[ " ${FLAGS[*]-} " == *" --dry-run "* ]]; then
  echo "[dry-run] skipping plugin install and health check"
  exit 0
fi
nvim --headless "+Lazy! restore" +qa
nvim --headless "+lua require('devenv.tools').install_sync()" +qa
"$HERE/check.sh"
