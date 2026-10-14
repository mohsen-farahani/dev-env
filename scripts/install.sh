#!/usr/bin/env bash
# Installs missing prerequisites only. Never upgrades existing tools. No sudo.
# Usage: install.sh [--dry-run] [--yes] [--skip-plugins]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
SKIP_PLUGINS=0
parse_common_flags "$@"
for a in "${ARGS[@]+"${ARGS[@]}"}"; do [[ "$a" == --skip-plugins ]] && SKIP_PLUGINS=1; done
if [[ -z "${DEVENV_STEP_TOTAL:-}" ]]; then STEP_TOTAL=$((SKIP_PLUGINS == 1 ? 5 : 6)); fi

banner "dev-env installer" "Neovim IDE for macOS - installs only what is missing"
[[ "$DRY_RUN" == 1 && "$CHILD" != 1 ]] && log "  ${C_Y}dry-run: nothing will be changed${C_0}"

# ---------------------------------------------------------------- 1. platform
step "Checking platform"
detect_platform || exit 1
detail "macOS $MACOS_VERSION / $ARCH"
if [[ -z "$BREW" ]]; then
  failed "Homebrew not found"
  manual 'install Homebrew from https://brew.sh (official installer; not run automatically), then re-run'
  print_report
  exit 1
fi
pass "Homebrew: $($BREW --version | head -1)"
[[ "$ARCH" == arm64 ]] || manual "Intel Mac: C# debugging needs a source-built netcoredbg (docs/DOTNET.md)"

# ---------------------------------------------------------------- 2. packages
step "Homebrew packages (only missing ones)"
formula_cmd() { case "$1" in neovim) echo nvim ;; tree-sitter-cli) echo tree-sitter ;; ripgrep) echo rg ;; delve) echo dlv ;; *) echo "$1" ;; esac }
while read -r _ name _; do
  f="${name//\"/}"
  c="$(formula_cmd "$f")"
  if have "$c"; then
    skipped "$f  ($(command -v "$c"))"
    continue
  fi
  do_step "Installing $f (brew)" "brew $f" "$BREW" install "$f" || true
done < <(grep -E '^brew "' "$REPO_ROOT/manifest/Brewfile")

# ---------------------------------------------------------------- 3. netcoredbg
# Pinned + checksum-verified; not via Mason (its darwin_arm64 asset is the amd64 build).
step "C# debugger (netcoredbg)"
do_netcoredbg() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  curl -fsSL --proto '=https' --proto-redir '=https' -o "$tmp/pkg.zip" "$NCDBG_URL"
  local got
  got="$(shasum -a 256 "$tmp/pkg.zip" | cut -d' ' -f1)"
  if [[ "$got" != "$NCDBG_SHA" ]]; then
    echo "CHECKSUM MISMATCH: expected $NCDBG_SHA, got $got - refusing to install"
    return 1
  fi
  unzip -q "$tmp/pkg.zip" -d "$tmp/x" -x '__MACOSX/*'
  mkdir -p "$DEVENV_DATA"
  rm -rf "$NETCOREDBG_DIR.new"
  mv "$tmp/x/netcoredbg" "$NETCOREDBG_DIR.new"
  rm -rf "$NETCOREDBG_DIR"
  mv "$NETCOREDBG_DIR.new" "$NETCOREDBG_DIR"
  echo "$NCDBG_VER" >"$NETCOREDBG_DIR/.version"
}
if [[ "$ARCH" != arm64 ]]; then
  skipped "netcoredbg: no prebuilt Intel macOS release"
else
  IFS='|' read -r _ NCDBG_VER NCDBG_URL NCDBG_SHA <<<"$(grep '^netcoredbg-osx-arm64|' "$REPO_ROOT/manifest/tools.lock")"
  if [[ -x "$NETCOREDBG_DIR/netcoredbg" ]] && grep -qx "$NCDBG_VER" "$NETCOREDBG_DIR/.version" 2>/dev/null; then
    skipped "netcoredbg $NCDBG_VER"
  else
    do_step "Downloading netcoredbg $NCDBG_VER and verifying sha256" "netcoredbg $NCDBG_VER (sha256 verified)" do_netcoredbg || true
  fi
fi

# ---------------------------------------------------------------- 4. roslyn
# Microsoft's official feed, pinned version, private tool-path.
step "C# language server (Roslyn)"
ROSLYN_VERSION="5.13.0-1.26513.11"
ROSLYN_FEED="https://pkgs.dev.azure.com/azure-public/vside/_packaging/vs-impl/nuget/v3/index.json"
do_roslyn() {
  local dir="$DEVENV_DATA/roslyn"
  rm -rf "$dir"
  mkdir -p "$dir"
  (cd "$HOME" && dotnet tool install roslyn-language-server --version "$ROSLYN_VERSION" --tool-path "$dir" --source "$ROSLYN_FEED")
  echo "$ROSLYN_VERSION" >"$dir/.version"
}
if ! have dotnet; then
  manual "install the .NET SDK, then re-run (Roslyn LSP needs it)"
elif [[ -f "$DEVENV_DATA/roslyn/.version" ]] && grep -qx "$ROSLYN_VERSION" "$DEVENV_DATA/roslyn/.version"; then
  skipped "roslyn-language-server $ROSLYN_VERSION"
else
  do_step "Installing roslyn-language-server $ROSLYN_VERSION" "roslyn-language-server $ROSLYN_VERSION" do_roslyn || true
fi

# ---------------------------------------------------------------- 5. goimports
# Go proxy + checksum DB are forced for this one command; your global GOPROXY/GOSUMDB are untouched.
step "Go tools (goimports)"
do_goimports() {
  mkdir -p "$DEVENV_DATA/bin"
  (cd "$HOME" && GOBIN="$DEVENV_DATA/bin" GOPROXY=https://proxy.golang.org GOSUMDB=sum.golang.org GOFLAGS='' go install golang.org/x/tools/cmd/goimports@v0.38.0)
}
if ! have go; then
  manual "install Go, then re-run (goimports needs it)"
elif [[ -x "$DEVENV_DATA/bin/goimports" ]]; then
  skipped "goimports"
else
  do_step "Installing goimports v0.38.0 (official proxy + sumdb)" "goimports v0.38.0" do_goimports || true
fi

# ---------------------------------------------------------------- 6. plugins (standalone only)
if [[ "$SKIP_PLUGINS" == 0 ]]; then
  step "Neovim plugins and language servers"
  if have nvim; then
    do_step "Restoring plugins from lazy-lock.json" "plugins (lazy-lock.json)" nvim --headless "+Lazy! restore" +qa || true
    do_step "Installing language servers / debug adapters (Mason)" "Mason tools" nvim --headless "+lua require('devenv.tools').install_sync()" +qa || true
  fi
fi

print_report
