#!/usr/bin/env bash
# Installs missing prerequisites only. Never upgrades existing tools. No sudo.
# Usage: install.sh [--dry-run] [--yes] [--skip-plugins]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
SKIP_PLUGINS=0
parse_common_flags "$@"
for a in "${ARGS[@]+"${ARGS[@]}"}"; do [[ "$a" == --skip-plugins ]] && SKIP_PLUGINS=1; done

detect_platform || exit 1
log "macOS $MACOS_VERSION / $ARCH (dry-run=$DRY_RUN)"

if [[ -z "$BREW" ]]; then
  failed "Homebrew not found"
  manual 'install Homebrew from https://brew.sh (official installer; not run automatically), then re-run'
  print_report
  exit 1
fi
pass "Homebrew: $($BREW --version | head -1)"

formula_cmd() { case "$1" in neovim) echo nvim ;; tree-sitter-cli) echo tree-sitter ;; ripgrep) echo rg ;; delve) echo dlv ;; *) echo "$1" ;; esac }
while read -r _ name _; do
  f="${name//\"/}"
  c="$(formula_cmd "$f")"
  if have "$c"; then
    skipped "$f ($c already on PATH: $(command -v "$c"))"
    continue
  fi
  if run "$BREW" install "$f"; then installed "brew $f"; else failed "brew install $f"; fi
done < <(grep -E '^brew "' "$REPO_ROOT/manifest/Brewfile")

# --- netcoredbg (pinned, checksum-verified, not via Mason: its darwin_arm64 asset is amd64) ---
install_netcoredbg() {
  if [[ "$ARCH" != arm64 ]]; then
    manual "netcoredbg: no prebuilt Intel macOS release; build from source (see docs/DOTNET.md). C# debugging unsupported until then"
    return 0
  fi
  local line name ver url sha
  line="$(grep '^netcoredbg-osx-arm64|' "$REPO_ROOT/manifest/tools.lock")"
  IFS='|' read -r name ver url sha <<<"$line"
  if [[ -x "$NETCOREDBG_DIR/netcoredbg" ]] && grep -qx "$ver" "$NETCOREDBG_DIR/.version" 2>/dev/null; then
    skipped "netcoredbg $ver"
    return 0
  fi
  if [[ "$DRY_RUN" == 1 ]]; then
    log "[dry-run] download $url, verify sha256, install to $NETCOREDBG_DIR"
    return 0
  fi
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  curl -fsSL --proto '=https' -o "$tmp/pkg.zip" "$url" || {
    failed "netcoredbg download"
    return 0
  }
  local got
  got="$(shasum -a 256 "$tmp/pkg.zip" | cut -d' ' -f1)"
  if [[ "$got" != "$sha" ]]; then
    failed "netcoredbg checksum mismatch (expected $sha, got $got)"
    return 0
  fi
  unzip -q "$tmp/pkg.zip" -d "$tmp/x" -x '__MACOSX/*'
  mkdir -p "$DEVENV_DATA"
  rm -rf "$NETCOREDBG_DIR.new"
  mv "$tmp/x/netcoredbg" "$NETCOREDBG_DIR.new"
  rm -rf "$NETCOREDBG_DIR"
  mv "$NETCOREDBG_DIR.new" "$NETCOREDBG_DIR"
  echo "$ver" >"$NETCOREDBG_DIR/.version"
  installed "netcoredbg $ver (sha256 verified)"
}
install_netcoredbg

# --- Roslyn language server: Microsoft's official feed, pinned version, private tool-path ---
ROSLYN_VERSION="5.13.0-1.26513.11"
ROSLYN_FEED="https://pkgs.dev.azure.com/azure-public/vside/_packaging/vs-impl/nuget/v3/index.json"
install_roslyn() {
  local dir="$DEVENV_DATA/roslyn"
  if ! have dotnet; then
    manual "install the .NET SDK, then re-run (Roslyn LSP needs it)"
    return 0
  fi
  if [[ -f "$dir/.version" ]] && grep -qx "$ROSLYN_VERSION" "$dir/.version"; then
    skipped "roslyn-language-server $ROSLYN_VERSION"
    return 0
  fi
  if [[ "$DRY_RUN" == 1 ]]; then
    log "[dry-run] dotnet tool install roslyn-language-server $ROSLYN_VERSION -> $dir"
    return 0
  fi
  rm -rf "$dir"
  mkdir -p "$dir" "$DEVENV_STATE"
  if (cd "$HOME" && dotnet tool install roslyn-language-server --version "$ROSLYN_VERSION" --tool-path "$dir" --source "$ROSLYN_FEED" >"$DEVENV_STATE/roslyn-install.log" 2>&1); then
    echo "$ROSLYN_VERSION" >"$dir/.version"
    installed "roslyn-language-server $ROSLYN_VERSION"
  else failed "roslyn-language-server install (see $DEVENV_STATE/roslyn-install.log)"; fi
}
install_roslyn

# --- goimports (module proxy + sumdb verified by the Go toolchain), pinned ---
install_goimports() {
  have go || return 0
  local bin="$DEVENV_DATA/bin"
  if [[ -x "$bin/goimports" ]]; then
    skipped "goimports"
    return 0
  fi
  if [[ "$DRY_RUN" == 1 ]]; then
    log "[dry-run] GOBIN=$bin go install golang.org/x/tools/cmd/goimports@v0.38.0"
    return 0
  fi
  mkdir -p "$bin" "$DEVENV_STATE"
  if (cd "$HOME" && GOBIN="$bin" GOPROXY=https://proxy.golang.org GOSUMDB=sum.golang.org GOFLAGS='' go install golang.org/x/tools/cmd/goimports@v0.38.0 2>"$DEVENV_STATE/goimports.err"); then installed "goimports v0.38.0 (official proxy + sumdb; your global GOPROXY/GOSUMDB are untouched)"; else failed "goimports (see $DEVENV_STATE/goimports.err)"; fi
}
install_goimports

# --- plugins + Mason tools (uses the lockfile; does not update) ---
if [[ "$SKIP_PLUGINS" == 0 ]]; then
  if [[ "$DRY_RUN" == 1 ]]; then
    log "[dry-run] nvim --headless: Lazy restore + Mason ensure_installed"
  elif have nvim; then
    if nvim --headless "+Lazy! restore" +qa 2>&1 | tail -5; then installed "plugins restored from lazy-lock.json"; fi
    if nvim --headless "+lua require('devenv.tools').install_sync()" +qa 2>&1 | tail -20; then installed "Mason tools"; else failed "Mason tools"; fi
  fi
fi
print_report
