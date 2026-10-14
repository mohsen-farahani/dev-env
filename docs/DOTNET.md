# C# / .NET

## Components
| Piece | What | Where it comes from |
|---|---|---|
| SDK/runtime | .NET SDK (tested 10.0.401, runtime 10.0.12) | Homebrew `dotnet` or Microsoft installer; **not** installed if `dotnet` already exists |
| Language server | Roslyn LSP `roslyn-language-server` 5.13.0-1.26513.11 | Microsoft's official NuGet feed via `dotnet tool install --tool-path`, pinned, in `~/.local/share/dev-env/roslyn` |
| Neovim client | `seblyng/roslyn.nvim` (requires Neovim ≥ 0.12 and server ≥ 5.12.0-1.26453.19) | lazy.nvim, pinned in lockfile |
| Debugger | Samsung **netcoredbg** 3.2.0-1092, native arm64 | GitHub release, sha256-verified, `~/.local/share/dev-env/netcoredbg` |
| DAP client | nvim-dap + nvim-dap-ui | lazy.nvim |

Why not Mason for these? Mason's `roslyn` package is a third-party repack (Crashdummyy/roslynLanguageServer), and its
`netcoredbg` package pins 3.1.3 and, for Apple Silicon, downloads the **amd64** build (Rosetta; cannot debug a native
arm64 runtime). Both are installed by `scripts/install.sh` instead.

## Language features (verified in `scripts/test.sh` on the sample solution)
Attach to a `.slnx` solution (root = solution folder), hover, go-to-definition **from the App project into the Calc
library project**, compiler diagnostics (`CS0029` etc.), formatting on save through Roslyn. Completion, signature help,
rename, code actions and references are provided by the same server and bound to the standard LSP keys, but were
not each exercised by an automated test.
Choosing between several solutions: `:Roslyn target`. `.sln`, `.slnx` and bare `.csproj` roots are all handled by
roslyn.nvim. `global.json`/multi-SDK selection is whatever `dotnet` on PATH resolves — **untested**.

## Debugging
Open any `.cs` file in the solution, set breakpoints with `<Space>b`, press `<F5>` (or `<Space>dc`).
1. Runnable projects (Exe, Web or Worker SDK) under the solution root are listed; pick one (skipped when only one).
2. Enter program arguments (blank for none; last value is remembered).
3. `dotnet build` runs; on failure errors go to quickfix and debugging is aborted.
4. The output dll is resolved with `dotnet msbuild -getProperty:TargetPath` (works for any TFM/output path), and
   netcoredbg launches it with `cwd` = project directory and `DOTNET_ENVIRONMENT/ASPNETCORE_ENVIRONMENT=Development`.
5. Step with `<Space>dn` (over) `di` (into) `do` (out); `<Space>du` for variables/stack/watches; `<Space>de` evaluate;
   `<Space>dr` restart; `<Space>dx` terminate. `<Space>dE` picks exception filters.

### Verified behaviour (netcoredbg 3.2.0, .NET 10.0.401, arm64)
- Launch, build-then-run via F5 path; breakpoint in the **library** project hit when started from the app project.
- Call stack, locals/arguments, `evaluate`, step over, continue to normal termination, terminate.
- Exception stop: `user-unhandled` and `all` both stop with reason `exception` and expose `$exception`
  (`System.DivideByZeroException`).
- Run the sample yourself: `nvim samples/dotnet-sample/src/Calc/Calculator.cs`, `<Space>b` on the loop line,
  `<F5>`, args `5`. For the exception path use args `3 --throw` and `<Space>dE` → `user-unhandled`.

### Limitations (real, observed or documented upstream)
- netcoredbg's macOS arm64 build is labelled "community supported" upstream. Microsoft's own debugger had macOS arm64
  crashes with SDK 10.0.104/10.0.200; netcoredbg with SDK 10.0.401 works in our tests, but re-run `scripts/test.sh` after
  every SDK or netcoredbg change.
- Breakpoints are reported `verified=false` until the module loads, then bind normally.
- On an exception stop the first scope shows only `$exception`; select the parent frame to inspect locals.
- No hot reload, no Razor/Blazor debugging; no ASP.NET browser auto-launch.
- **Attach to process (`<Space>da`) is implemented but untested.**
- Intel Macs: no prebuilt macOS x64 netcoredbg release. Build it from source (needs clang, cmake; see the project
  README), place the result at `~/.local/share/dev-env/netcoredbg/netcoredbg`. Untested.
- `just my code` / symbol-server / source-link features of Visual Studio's debugger are not available.

## Build, test, format
| Action | Key | Command |
|---|---|---|
| build solution (or project if no solution) | `<Space>tb` | `:DotnetBuild` — errors parsed into quickfix |
| test current file's class | `<Space>tf` | `:DotnetTestFile` — `dotnet test --filter FullyQualifiedName~<ClassName>` |
| test current project | `<Space>tp` | `:DotnetTestProject` |
| test whole solution | – | `:DotnetTest` |
| `dotnet format` | `<Space>tF` | `:DotnetFormat` |
The plain CLI is always available via `<Space>tt`. Test output goes to a terminal split (the .NET 10 SDK prints
`Test summary: total: N, failed: N, succeeded: N`).

## Security notes
- Roslyn comes from `pkgs.dev.azure.com/azure-public/vside` (Microsoft). On macOS `dotnet tool install` prints
  "Skipping NuGet package signature verification" — NuGet signature checks are off by default outside Windows. You can
  set `DOTNET_NUGET_SIGNATURE_VERIFICATION=true` (not tested here). The version is pinned.
- netcoredbg is an unsigned third-party binary pinned by sha256 in `manifest/tools.lock`; bump deliberately.
- Both run as your user and can read your source/environment variables of the debuggee.

## Troubleshooting
See `docs/TROUBLESHOOTING.md` ("C#" section).
