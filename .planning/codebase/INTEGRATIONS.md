# External Integrations

**Analysis Date:** 2026-04-05

## APIs & External Services

**Ad Network / Game Platform:**
- Yandex Games SDK v2 — monetization and platform integration for the web build.
  - SDK/Client: CDN script `https://yandex.ru/games/sdk/v2` injected in `love-web-builder-main/lovejs_source/template.html`. Lua bridge: `yandex.lua`.
  - Auth: None (no API key required; SDK initializes via `YaGames.init()` in the browser context).
  - Ad types supported:
    - Interstitial (fullscreen): `yandex.showInterstitial()` / `yandex.getInterstitialResult()` / `yandex.resetInterstitialResult()`
    - Rewarded video: `yandex.showRewarded()` / `yandex.getRewardedResult()` / `yandex.resetRewardedResult()`
    - Sticky banner: `yandex.showBanner()` / `yandex.hideBanner()` (called at startup from `main.lua`)
  - Communication mechanism: Lua calls `ffi.C.emscripten_run_script()` to invoke JavaScript on `window.yandexBridge`, which is a thin wrapper defined in the HTML template. Results are polled by Lua via `emscripten_run_script_string()`.
  - Platform guard: All Yandex calls are no-ops on non-web platforms. `yandex.init()` bails early if `mobile.isWeb()` returns false or if the `ffi` module is unavailable.
  - SDK ready check: `yandex.isReady()` polls `window.yandexBridge.sdkReady`.

## Data Storage

**Databases:**
- None. No external database.

**Local persistence:**
- LÖVE filesystem (`love.filesystem`) — single flat save file `progression.dat` in the platform's LÖVE save directory (e.g., `~/.local/share/love/` on Linux, `AppData/Roaming/LOVE/` on Windows).
- Format: serialized Lua table (custom `serialize`/`deserialize` using `loadstring`/`load`), not JSON or binary.
- Written by: `progression.save()` in `progression.lua`.
- Read by: `progression.load()` called once at startup in `main.lua` via `progression.init(true)`.
- Contents: all persistent game state — skill tree, resources, bags, arena grid, coin sort state, drops, powerups, achievements, stats, unlocks.

**File Storage:**
- Local filesystem only. All assets (sprites, sounds, fonts) are bundled with the game directory:
  - `assets/` — PNG sprites (`ball.png`, button images, color variants)
  - `sfx/` — OGG/WAV sound effects (33 files)
  - `bgnd_music/` — MP3 background music tracks
  - `comic shanns.otf` — custom font

**Caching:**
- None (no external cache layer). In-memory caches only: font metric caches in `graphics.lua` (`fontHeightCache`, `fontWidthCache`), ball image dimensions.

## Authentication & Identity

**Auth Provider:**
- None. No user accounts, login, or authentication system.

## Monitoring & Observability

**Error Tracking:**
- Custom crash logger in `main.lua` (`love.errorhandler`): on unhandled Lua error, writes stack trace to `/tmp/love_crash.log` (system temp) and `crash.log` (LÖVE save directory) via `pcall`-guarded `io.open` and `love.filesystem.write`.
- No remote error reporting service.

**Logs:**
- `print()` statements throughout codebase for development debugging. No structured logging framework.
- FPS counter rendered on-screen at bottom-left of virtual canvas (always visible, drawn in `main.lua`).
- VS Code Local Lua Debugger (`lldebugger.lua`) for interactive breakpoint debugging in development.

## CI/CD & Deployment

**Hosting:**
- Yandex Games — primary web distribution target. Game is packaged via `love-web-builder-main/` into a WebAssembly bundle and hosted on the Yandex Games platform.
- No CI pipeline detected (no GitHub Actions, no `.gitlab-ci.yml`, no other CI config files).

**CI Pipeline:**
- None detected.

**Build process:**
- Web: run `love-web-builder-main/build.bat <game-folder> <output-folder>` (Windows) or `build.sh` (Unix). Produces a static WebAssembly site in the output folder. Serve with `python -m http.server 8080` for local testing.
- Android: manual `love-android` Gradle build (`./gradlew assembleRelease`). See `MOBILE_BUILD.md`.
- iOS: manual Xcode archive build. See `MOBILE_BUILD.md`.

## Environment Configuration

**Required env vars:**
- `LOCAL_LUA_DEBUGGER_VSCODE=1` — optional, development only. Enables VS Code Lua debugger via `lldebugger.lua`. Checked in `conf.lua` before LÖVE initializes.

**Secrets location:**
- None. No secrets, API keys, or credentials exist in this codebase. The Yandex SDK loads from a public CDN URL with no authentication token.

## Webhooks & Callbacks

**Incoming:**
- None. The game has no HTTP server or webhook endpoints.

**Outgoing:**
- None. The game makes no outbound HTTP requests from Lua code. Yandex SDK ad calls are routed through the browser's JavaScript context (not direct HTTP from the game).

---

*Integration audit: 2026-04-05*
