# Stack Research

**Domain:** LOVE2D game polish features (effects, tutorials, commissions, popups) for web/WASM
**Researched:** 2026-04-05
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

No new frameworks or external dependencies. All four features are buildable with LOVE 12.0 built-in APIs already available in the project's pinned commit (`cdf68b3`). The project's "no external dependencies" pattern should be preserved.

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `love.graphics.setStencilMode` | LOVE 12.0 | Spotlight tutorial overlay masking | New LOVE 12.0 API replacing deprecated `love.graphics.stencil()` + `setStencilTest()`. Hardware-accelerated pixel masking with zero shader overhead. Supported in WebGL2 (OpenGL ES 3) which love-web-builder targets. Verified enum: `"off"`, `"draw"`, `"test"`, `"custom"` in LOVE source. |
| `love.graphics.SpriteBatch` | LOVE 12.0 | Particle/effects rendering | Already used in `particles.lua`. Correct approach for web performance -- single draw call for all particles. No change needed to rendering primitive, only to effect system architecture on top. |
| `love.graphics.newCanvas` | LOVE 12.0 | Off-screen rendering for overlays | Already used for main virtual canvas in `main.lua`. LOVE 12.0 auto-creates temporary stencil buffers when stencil operations are used, so no canvas config change needed for spotlight. |
| Lua table serialization (existing) | Lua 5.x | Persistent commission save/load | Existing `progression.lua` serialization handles this. Commission data needs a new key in the save schema. Same pattern as `drops_data`, `bags_data`, etc. |

### Supporting Libraries

**None to add.** Every feature maps directly to LOVE 12.0 built-in APIs.

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| (none) | -- | -- | The project has zero external Lua dependencies and this milestone does not require breaking that pattern. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| VS Code + lua-local (existing) | Debug | No change needed. |
| love-web-builder (existing) | Web builds | Test stencil features in web build early. WebGL2 supports stencil buffers per spec, but the SDL3 Emscripten port is experimental. Test on first implementation day. |

## Feature-Specific Stack Decisions

### 1. Effects System Redesign

**Current state:** `particles.lua` uses a hand-rolled active-list pool with SpriteBatch (1 draw call). 75-150 max particles. Swap-remove for O(1) deactivation. This architecture is sound for web.

**What to change:**
- Expand the effects vocabulary (not the rendering approach). The SpriteBatch + pool pattern stays.
- Add new effect types (glow pulse, scale pop, trail, screen flash) as parameterized presets on the same pool, not as separate systems.
- Effects that are NOT particles (screen flash, UI glow, button pulse) use direct `love.graphics` draw calls with alpha/scale tweening -- no SpriteBatch needed.

**What NOT to change:**
- Do NOT switch to `love.graphics.newParticleSystem` (built-in LOVE particle system). The hand-rolled pool is already optimized for this game's burst-style effects and avoids the built-in system's texture atlas limitations and draw state changes.
- Do NOT add a general-purpose tween library. The project has inline easing functions (`easeOutElastic` in `arena_screen.lua`, bounce math in `animation.lua`). A small shared tween utility (< 50 lines) covers all needs.

**Performance budget (web):** Keep max active particles at 75 for `mobile.isLowPerformance()`. Current `SPAWN_COUNT` / `MERGE_SPAWN_COUNT` values are already tuned. New effects should use the same pool, not create additional draw calls.

### 2. Spotlight Tutorial Overlay

**API: `love.graphics.setStencilMode(mode, value)`**

This is the LOVE 12.0 replacement for the deprecated `love.graphics.stencil()` + `setStencilTest()` pair. Verified in LOVE source code:

| Lua String | C++ Enum | Behavior |
|------------|----------|----------|
| `"off"` | `STENCIL_MODE_OFF` | Disable stencil (default) |
| `"draw"` | `STENCIL_MODE_DRAW` | Draw geometry writes stencil values, not pixels |
| `"test"` | `STENCIL_MODE_TEST` | Draw only where stencil matches value |
| `"custom"` | `STENCIL_MODE_CUSTOM` | Low-level control via `setStencilState` |

**Spotlight technique (verified for LOVE 12.0):**
```lua
-- 1. Draw mode: geometry writes to stencil buffer, not screen
love.graphics.setStencilMode("draw", 1)
love.graphics.circle("fill", spotlight_x, spotlight_y, spotlight_r)

-- 2. Test mode: only draw where stencil != 1 (outside the cutout)
love.graphics.setStencilMode("test", 1)
love.graphics.setColor(0, 0, 0, 0.75)
love.graphics.rectangle("fill", 0, 0, VW, VH)

-- 3. Reset
love.graphics.setStencilMode()
```

The `"test"` mode uses "notequal" comparison by default: pixels where stencil == value are NOT drawn. This creates the spotlight hole effect.

**Canvas stencil support:** In LOVE 12.0, auto-generated temporary stencil buffers are created and cleared when stencil ops are used. The existing canvas `love.graphics.newCanvas(VW, VH, {dpiscale = 1})` should work without modification. If this fails on web, add `stencil = true` to the canvas options.

**Fallback if stencil fails on web:** Four-rectangle approach. Draw four black semi-transparent rectangles around the spotlight cutout area (top, bottom, left, right strips). Works for rectangular highlights (grid cells, buttons). For circular spotlights, use a canvas with `love.graphics.setBlendMode("replace")` to punch a hole. The stencil approach is preferred because it handles arbitrary shapes with zero extra canvases.

**WASM compatibility:** WebGL2 (OpenGL ES 3) guarantees 8-bit stencil buffer. The love-web-builder confirms OpenGL ES 3 shader support. Risk is limited to the experimental SDL3 port, not the WebGL spec.

### 3. Persistent Commission Tracking

**No new technology.** Pure data model change.

**Save schema addition to `progression.lua`:**
```lua
commissions_data = {
  active = {},           -- array of commission objects
  last_refresh_time = 0, -- timestamp for time-gated refresh
  completed_count = 0,   -- lifetime stats
}
```

**Current gap:** `commissions.lua` stores `active` as module-local state that is regenerated from scratch on `commissions.generate()`. To persist across sessions, it needs to read/write through `progression.getCommissionsData()` / `setCommissionsData()` -- the same getter/setter pattern used by `drops.lua`, `bags.lua`, and `resources.lua`.

**Cross-screen visibility:** Commission data is already pure data (no drawing in `commissions.lua`). Both screen modules can `require("commissions")` and call `commissions.getActive()`. This follows the existing logic/visual separation pattern.

### 4. Modal Reward Popups

**No new technology.** Immediate-mode UI with animation state.

**Approach:** A `reward_popup.lua` module that:
- Maintains a queue of pending popups (multiple rewards can fire rapidly during merges/order completion)
- Renders a centered card with backdrop dim, scale-in animation, auto-dismiss timer
- Blocks game input while visible (same pattern as `fuel_overlay_shown` in `arena_screen.lua`)
- Uses existing easing functions (`easeOutElastic`, `easeOutBack`)

**Drawing layer:** Call from `main.lua` after `screens.draw()` but before FPS counter. Single call site works for all screens:
```lua
-- In main.lua love.draw():
love.graphics.setCanvas(canvas)
love.graphics.clear()
screens.draw()
reward_popup.draw()  -- <-- here, on the virtual canvas
-- ... FPS counter, then canvas to screen
```

**No shader needed.** Backdrop is a semi-transparent black rectangle (same as `drawFuelDepletionOverlay()` in `arena_screen.lua`). Popup card is rounded rectangles + text + icon.

## Installation

```bash
# No installation needed. Zero new dependencies.
# All features use LOVE 12.0 built-in APIs.
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `setStencilMode` spotlight | 4-rectangle masking | If stencil buffer fails on web build. Simpler, but only works for rectangular cutouts (no circles, no complex shapes). |
| `setStencilMode` spotlight | Canvas compositing with `"multiply"` blend | If both stencil AND 4-rect approach are insufficient. More expensive (extra canvas + blend switch) but avoids stencil buffer entirely. |
| `setStencilMode` spotlight | GLSL shader with SDF circle | Never for this project. Shader compilation latency on web, more code, harder to debug. |
| Inline easing functions | hump.timer / flux tween library | Never for this project. Max ~5 active tweens at once. A 30-line utility covers all needs. |
| SpriteBatch particle pool | `love.graphics.newParticleSystem` (built-in) | Never for this project. Built-in system is for continuous emitters, not discrete bursts. Current pool is already tuned. |
| `progression.dat` Lua serialization | JSON via custom parser | Defer to post-release. The `loadstring()` security concern (in CONCERNS.md) is negligible on sandboxed Yandex web platform. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| External UI libraries (SUIT, Gspot, nuklear) | Project uses immediate-mode rectangle UI. Adding a framework for 1 popup and 1 overlay creates dependency mismatch and Emscripten compatibility risk. | Hand-rolled popup with existing drawing patterns (`love.graphics.rectangle`, `love.graphics.printf`). |
| `love.graphics.newParticleSystem` | Designed for continuous emission, not discrete bursts. Requires texture atlas. More draw state changes per frame. | Keep existing SpriteBatch pool in `particles.lua`. Extend with new spawn presets. |
| General tween/animation libraries (hump, flux, anim8) | Adds external dependency. Project needs are simple: scale pop, slide in/out, alpha fade. | Extract a shared `tween()` utility from existing inline easing functions. |
| Per-pixel blur shader for popup backdrop | GPU-expensive on WASM. Requires multi-pass rendering with temporary canvases. Unnecessary for a merge puzzle game. | `love.graphics.setColor(0, 0, 0, 0.7)` + `rectangle("fill")`. Already used for fuel depletion overlay. |
| `love.graphics.setBlendState` (LOVE 12.0 low-level blend) | More control than needed. High-level `setBlendMode` covers all popup/overlay needs. | `love.graphics.setBlendMode("alpha")` (default) handles everything. |
| Deprecated stencil API (`love.graphics.stencil()` + `setStencilTest()`) | Deprecated in LOVE 12.0. Still works but uses callback pattern that is harder to reason about. | `love.graphics.setStencilMode("draw", 1)` / `setStencilMode("test", 1)` -- linear, no callbacks. |

## New Modules to Create

| Module | Role | Pattern |
|--------|------|---------|
| `effects.lua` | Effect presets + spawn orchestration | Data + logic, no drawing. Calls `particles.lua` for burst effects. Defines preset tables (spawn count, speed range, lifetime, color per effect type). |
| `tween_utils.lua` | Shared easing functions + tween helper | Pure math utility. Extract `easeOutElastic`, `easeOutBack` from `arena_screen.lua`. Add `tween(elapsed, duration, easing_fn)` helper returning 0-1. |
| `spotlight.lua` | Tutorial spotlight overlay system | Drawing module. Manages stencil masking, cutout shapes, dimming, tooltip positioning, input blocking region. |
| `reward_popup.lua` | Modal reward popup queue | Data + drawing (popup IS a visual feature). Queue management, animation state, rendering. Called from `main.lua`. |

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| `love.graphics.setStencilMode` | LOVE 12.0+ only | Not in 11.x. Project pinned to 12.0, safe. |
| `setStencilMode` on web | WebGL2 via love-web-builder SDL3 port | WebGL2 spec guarantees 8-bit stencil. SDL3 port is "experimental" -- test early. |
| Canvas auto-stencil | LOVE 12.0 | Auto-creates temporary stencil buffer. May need explicit `{stencil = true}` on web as fallback. |
| `SpriteBatch:bind/unbind` | LOVE 0.9.0+ | Long-standing API. No compatibility concern. |
| `love.graphics.setBlendMode("multiply")` | LOVE 0.9.0+ | Stencil fallback. Universally available. |

## Sources

- [LOVE changes.txt (changelog)](https://github.com/love2d/love/blob/main/changes.txt) -- verified `setStencilMode` addition, Canvas stencil changes, deprecated functions (HIGH confidence)
- [LOVE renderstate.h](https://github.com/love2d/love/blob/main/src/modules/graphics/renderstate.h) -- verified StencilMode enum: `STENCIL_MODE_OFF`, `STENCIL_MODE_DRAW`, `STENCIL_MODE_TEST`, `STENCIL_MODE_CUSTOM` (HIGH confidence)
- [LOVE renderstate.cpp](https://github.com/love2d/love/blob/main/src/modules/graphics/renderstate.cpp) -- verified Lua string mappings: `"off"`, `"draw"`, `"test"`, `"custom"` (HIGH confidence)
- [LOVE Graphics.cpp](https://github.com/love2d/love/blob/main/src/modules/graphics/Graphics.cpp) -- verified `setStencilMode(mode, value)` signature and `"test"` uses notequal comparison (HIGH confidence)
- [love-web-builder repository](https://github.com/rozenmad/love-web-builder) -- confirmed OpenGL ES 3 shader support, SDL3 Emscripten port (MEDIUM confidence -- "experimental" qualifier)
- [WebGL 2.0 browser support (caniuse)](https://caniuse.com/webgl2) -- 92/100 compatibility, stencil buffer in spec (HIGH confidence)
- [Emscripten OpenGL support docs](https://emscripten.org/docs/porting/multimedia_and_graphics/OpenGL-support.html) -- WebGL2 via `-sMAX_WEBGL_VERSION=2` (HIGH confidence)
- [LOVE wiki: love.graphics.stencil](https://love2d.org/wiki/love.graphics.stencil) -- deprecated API docs, useful for understanding the pattern (HIGH confidence)
- [LOVE wiki: BlendMode Formulas](https://love2d.org/wiki/BlendMode_Formulas) -- multiply blend as stencil fallback (HIGH confidence)
- [LOVE forum: SpriteBatch performance](https://love2d.org/forums/viewtopic.php?t=78271) -- bind/unbind optimization (MEDIUM confidence)
- [LOVE forum: Overlay techniques](https://love2d.org/forums/viewtopic.php?t=88854) -- community patterns for dimmed overlays (MEDIUM confidence)
- Existing codebase: `particles.lua`, `arena_screen.lua`, `commissions.lua`, `progression.lua`, `main.lua` -- verified current patterns (HIGH confidence)

---
*Stack research for: LOVE2D v1.0 Release Polish features*
*Researched: 2026-04-05*
