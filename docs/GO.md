# Go

| Piece | Source |
|---|---|
| Go toolchain | whichever `go` is on PATH (yours: `/usr/local/go`); Homebrew `go` only if missing |
| gopls | Homebrew (tested v0.23.0), staticcheck + unused-params + shadow analyses enabled |
| Delve (`dlv`) | Homebrew `delve` (tested 1.27.2) |
| gofmt / goimports | gofmt ships with Go; goimports v0.38.0 installed by `scripts/install.sh` |
Mason is intentionally **not** used for any of these.

## Features
Diagnostics, hover, definition, references, rename, code actions via gopls (`gd gr K <Space>rn <Space>ca`).
Roots: `go.work` then `go.mod`. Format on save: goimports → gofmt (one hook, no `:!gofmt`).

## Build & test
`<Space>tb` `go build ./...` (errors → quickfix) · `<Space>tn` test function at cursor · `<Space>tp` `go test -v`
current package · `<Space>tr` `go run` · `:GoTestAll`.

## Debugging
- `<Space>b` breakpoint, `<F5>`/`<Space>dc`: pick *Debug package of current file*, *Debug current file (main)*,
  *Debug tests in package*, or *Attach to process*.
- `<Space>dt` debugs the Test function at the cursor (`-test.run ^Name$`).
- **Important implementation detail:** `dlv dap` compiles relative to its own working directory, so the adapter is started
  with `cwd` = module root. Starting `dlv dap` from elsewhere fails with "go: cannot find main module".
- Verified (headless, `scripts/test.sh`): breakpoint hit, call stack, locals, step over, termination, and **debugging a
  test (mode=test)**, both at DAP level and through nvim-dap.
- **Not tested:** attach, remote debugging, `go.work` multi-module debugging, build tags.

## Your Go environment (heads-up)
`go env` on this machine has `GOPROXY` pointing at a private mirror list and `GOSUMDB=off` (in
`~/Library/Application Support/go/env`). That disables checksum-database verification for all your `go install`/`go get`
runs. This repo does not touch it; its own `go install goimports` overrides both for that single command.
