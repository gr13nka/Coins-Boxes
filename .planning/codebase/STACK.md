# Technology Stack

**Analysis Date:** 2026-04-05

## Languages

**Primary:**
- Lua 5.x (LuaJIT-compatible) - All game logic, rendering, UI, and input handling. Every `.lua` file in the root.

**Secondary:**
- JavaScript - Yandex Games SDK bridge embedded in the web HTML template (`love-web-builder-main/lovejs_source/template.html`)
- Python 3.10+ - Web build tooling only (`love-web-builder-main/build.py`)

## Runtime

**Environment:**
- LÖVE 12.0 (love2d) — game framework providing the Lua VM, graphics (OpenGL ES 3), audio, filesystem, and event loop. Targets the `main` branch at commit `cdf68b3`.
- Emscripten / WebAssembly — web target via the bundled `love-web-builder-main/` toolchain, which is an SDL3-based Emscripten port of LÖVE 12.0.

**Package Manager:**
- None. No dependency manager (no LuaRocks manifest, no package.json). All code is vendored or part of the LÖVE standard library.
- Lockfile: Not applicable.

## Frameworks

**Core:**
- LÖVE 12.0 — provides the entire platform layer: `love.graphics`, `love.audio`, `love.filesystem`, `love.system`, `love.window`, `love.timer`, `love.mouse`, `love.touch`. Entry point is `main.lua` with standard LÖVE callbacks.

**Testing:**
- None detected. No test runner or test files exist.

**Build/Dev:**
- `love-web-builder-main/build.py` + `build.bat`/`build.sh` — packages the game as a `.love` file and wraps it in a WebAssembly build for browser deployment.
- `makelove` (referenced in `.vscode/tasks.json` with `--config make_all.toml`) — cross-platform desktop/mobile packaging tool. Config file `make_all.toml` is not present in the repository.
- VS Code with `lua-local` debugger extension — debug config in `.vscode/launch.json` runs `love .` directly.
- `lldebugger.lua` (vendored) — Local Lua Debugger for VS Code integration, activated via `LOCAL_LUA_DEBUGGER_VSCODE=1` env var in `conf.lua`.

## Key Dependencies

**Critical (vendored/built-in):**
- `lldebugger.lua` — VS Code Lua debugger adapter, loaded conditionally in `conf.lua` when `LOCAL_LUA_DEBUGGER_VSCODE == "1"`.

**Infrastructure (LÖVE built-ins used):**
- `love.graphics` — canvas rendering, sprite batches, font rendering, OpenGL ES 3 shaders.
- `love.audio` — streaming MP3 background music, static OGG/WAV sound effects.
- `love.filesystem` — save/load of `progression.dat` via `love.filesystem.write` / `love.filesystem.read`.
- `love.system` — OS detection (`getOS()`) used by `mobile.lua` for platform branching.
- `ffi` (LuaJIT FFI / Emscripten FFI) — used in `yandex.lua` to call `emscripten_run_script` for Yandex SDK interop on web builds only.

## Configuration

**Environment:**
- `LOCAL_LUA_DEBUGGER_VSCODE=1` — enables VS Code debug adapter in `conf.lua` and `lldebugger.lua`.
- No `.env` files. No secrets or API keys in code (Yandex SDK is loaded from a public CDN URL in the HTML template).

**Build:**
- `conf.lua` — LÖVE window configuration: resizable, HiDPI (`highdpi = true`, `usedpiscale = true`), vsync on, console disabled when debugger active.
- `.vscode/settings.json` — Lua language server globals (`love`), disable `undefined-global` diagnostic.
- `.vscode/launch.json` — two launch configs (`Debug`, `Release`) both run `love .`.
- `.vscode/tasks.json` — default build task calls `makelove --config make_all.toml`.
- `love-web-builder-main/build.py` — web packaging: bundles game files, injects Yandex SDK HTML template, sets memory limit (default 16 MB).

## Platform Requirements

**Development:**
- LÖVE 12.0 installed and accessible as `love` command.
- VS Code + `lua-local` debugger extension for debugging.
- Python 3.10+ for web builds.

**Production:**
- **Desktop:** Any OS with LÖVE 12.0 installed. Window is resizable, letterboxed to 1080×1920 virtual canvas.
- **Mobile (Android):** `love-android` + Java JDK 17+ + Android SDK. Portrait orientation enforced via `AndroidManifest.xml`.
- **Mobile (iOS):** `love-ios` + macOS + Xcode 14+ + Apple Developer account.
- **Web:** Emscripten/WebAssembly via `love-web-builder-main`. Requires a static HTTP server; SDL3 experimental port. Targets Yandex Games platform.

---

*Stack analysis: 2026-04-05*
