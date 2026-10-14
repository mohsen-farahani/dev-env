# Keymaps

Leader is `<Space>`. Press `<Space>` and wait: which-key shows the available continuations with descriptions.
Mappings marked *buffer* exist only while an LSP/filetype applies.

## General
| Keys | Action |
|---|---|
| `<Esc>` | clear search highlight |
| `<C-h/j/k/l>` | move between windows |
| `<S-h>` / `<S-l>` | previous / next buffer |
| `<Space>bd` | delete buffer |
| `<Space>w` / `<Space>q` | save / quit window |
| `<Space>tt` | toggle terminal (`<Esc><Esc>` leaves terminal-insert mode) |
| `<Space>ac` | toggle Claude Code (unchanged from your previous config) |
| `<Space>uf` | toggle format-on-save |

## Find & explore
| Keys | Action |
|---|---|
| `<Space>e` / `<Space>E` | file explorer / reveal current file |
| `<Space>ff` `fg` `fb` | files / live grep / buffers |
| `<Space>fr` `fh` `fd` | recent files / help / diagnostics |
| `<Space>fs` `fS` `f.` | document symbols / workspace symbols / resume last search |

## LSP (*buffer*)
| Keys | Action |
|---|---|
| `gd` `gD` `gr` `gi` `gy` | definition / declaration / references / implementation / type definition |
| `K` | hover |
| `<Space>rn` | rename |
| `<Space>ca` | code action (normal & visual) |
| `<Space>cs` | signature help |
| `<Space>cd` | line diagnostics (float) |
| `<Space>cl` | all diagnostics → quickfix |
| `<Space>ch` | toggle inlay hints (when supported) |
| `<Space>cf` | format buffer/selection |
| `[d` `]d` | previous/next diagnostic (Neovim built-in) |
| `grn` `gra` `grr` `gri` `gO` | Neovim 0.11+ built-in LSP defaults |

## Git (blame only — use the git CLI for everything else)
Inline blame is always shown at end of line: `author, date - summary (sha)`.
| Keys | Action |
|---|---|
| `<Space>gb` | full blame popup for current line |
| `<Space>gB` | toggle inline blame |
| `]h` `[h` `<Space>gp` | next/previous hunk, preview hunk |

## Debugging
macOS often intercepts F-keys (F1/F2/F10 change brightness/volume etc. unless you hold `fn` or enable "Use F1, F2, etc. keys as standard function keys"). Every F-key has a reliable leader alternative.

| Keys | Alternative | Action |
|---|---|---|
| `<Space>b` | – | toggle breakpoint (kept from your config) |
| `<F5>` | `<Space>dc` | start (or continue if a session is running). C#: pick project → build → launch |
| `<F10>` | `<Space>dn` | step over |
| `<F1>` | `<Space>di` | step into |
| `<F2>` | `<Space>do` | step out |
| – | `<Space>dp` | pause |
| – | `<Space>dB` | conditional breakpoint |
| – | `<Space>dC` | clear all breakpoints |
| – | `<Space>dr` / `dx` / `dl` | restart / terminate / run last |
| `<Space>du` | – | toggle debugger UI (variables, stack, breakpoints, watches, REPL) |
| – | `<Space>de` | evaluate expression under cursor / selection |
| – | `<Space>dE` | choose exception breakpoint filters |
| – | `<Space>da` | attach to process (C#; **untested**) |
| – | `<Space>dt` | debug test at cursor (Go, Python; not C#) |

## Build & test (by filetype, *buffer*)
| Keys | C# | Go | Python |
|---|---|---|---|
| `<Space>tb` | `dotnet build` (solution, errors → quickfix) | `go build ./...` | – |
| `<Space>tn` | – | test function at cursor | pytest function at cursor |
| `<Space>tf` | `dotnet test` filtered to this file's class | – | pytest file |
| `<Space>tp` | `dotnet test` current project | `go test -v` current package | pytest all |
| `<Space>tr` | – | `go run` package | – |
| `<Space>tF` | `dotnet format` | – | – |

Commands: `:DotnetBuild` `:DotnetTest` `:DotnetTestProject` `:DotnetTestFile` `:DotnetFormat` `:GoBuild` `:GoTest`
`:GoTestAll` `:GoTestFunc` `:GoRun` `:Pytest [file|func]`.

## Completion (blink.cmp, default preset)
`<C-space>` open menu · `<C-n>/<C-p>` or `<Down>/<Up>` select · `<C-y>` accept · `<C-e>` close.
