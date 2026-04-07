# Architecture

**Analysis Date:** 2026-04-05

## Pattern Overview

**Overall:** Module-per-concern with hard logic/visual separation, orchestrated by a single-active-screen state machine.

**Key Characteristics:**
- Every `.lua` file returns a single public table (module pattern). No global state except LOVE2D callbacks in `main.lua`.
- Logic modules (`coin_sort.lua`, `arena.lua`, `resources.lua`, `bags.lua`, `powerups.lua`, `drops.lua`, `skill_tree.lua`, `commissions.lua`) contain zero drawing code.
- Screen modules (`coin_sort_screen.lua`, `arena_screen.lua`, `game_over_screen.lua`, `skill_tree_screen.lua`) contain all rendering and input handling and call into logic modules.
- Persistence is centralized: all game state funnels through `progression.lua` as a single serialized Lua table written to `progression.dat`.
- No `goto` anywhere — `repeat/until` used for retries (web build constraint).

## Layers

**LOVE2D Entry Point:**
- Purpose: LOVE2D lifecycle callbacks, asset loading, coordinate transformation, touch debounce
- Location: `main.lua`
- Contains: `love.load()`, `love.update()`, `love.draw()`, `love.mousepressed()`, window/canvas setup
- Depends on: all modules
- Used by: LOVE2D runtime

**Screen Manager:**
- Purpose: Single-active-screen state machine; delegates all LOVE2D events to the current screen
- Location: `screens.lua`
- Contains: `register()`, `switch()`, `update()`, `draw()`, `mousepressed()`, `mousereleased()`, `keypressed()`, `mousemoved()`; also embeds the dormant `mode_select` screen table
- Depends on: `layout.lua`, `progression.lua`
- Used by: `main.lua`, all screen modules (call `screens.switch()`)

**Screen Modules (UI + Input):**
- Purpose: All rendering and player interaction for one mode
- Location: `coin_sort_screen.lua`, `arena_screen.lua`, `game_over_screen.lua`, `skill_tree_screen.lua`
- Contains: immediate-mode UI, hit testing, drag state, animation triggers, calls to logic modules
- Depends on: corresponding logic modules, `animation.lua`, `graphics.lua`, `input.lua`, `layout.lua`, `tab_bar.lua`, `sound.lua`, `particles.lua`
- Used by: `screens.lua`

**Logic Modules (Pure Data):**
- Purpose: Game rules, state mutation, resource accounting — no drawing
- Location: `coin_sort.lua`, `arena.lua`, `resources.lua`, `bags.lua`, `powerups.lua`, `drops.lua`, `commissions.lua`, `skill_tree.lua`
- Contains: state tables, rule functions, save/load via `progression.lua`
- Depends on: `progression.lua` (persistence), each other via lazy `require()` to avoid circular deps
- Used by: screen modules, `main.lua`

**Static Data Modules:**
- Purpose: Immutable game data tables — no runtime state, no drawing
- Location: `arena_chains.lua`, `arena_orders.lua`
- Contains: chain definitions, item lists, generator specs, drop tables, order level data
- Depends on: nothing (or lazy `require("arena")` in `arena_orders.lua` for order gating)
- Used by: `arena.lua`, `arena_screen.lua`, `coin_sort_screen.lua`

**Rendering Helpers:**
- Purpose: Shared drawing primitives (coins, boxes) and layout math
- Location: `graphics.lua`, `layout.lua`, `animation.lua`, `particles.lua`
- Contains: `graphics.drawCoin()`, layout constants and computed metrics, dual-track animation state machine, particle pool + SpriteBatch
- Depends on: `layout.lua`, `coin_utils.lua`, `mobile.lua`
- Used by: screen modules, `animation.lua`

**Input & Coordinate Layer:**
- Purpose: Hit testing, screen-to-game coordinate conversion
- Location: `input.lua`
- Contains: `toGameCoords()`, `boxAt2048()`, `isInsideButton()`, toggle hit tests
- Depends on: `layout.lua`
- Used by: `main.lua` (coord transform), screen modules (hit testing)

**Persistence Layer:**
- Purpose: Single save file for all game state; serializes/deserializes a Lua table
- Location: `progression.lua`
- Contains: `init()`, `save()`, `load()`, `reset()`, getters/setters for every subsystem's slice of data
- Depends on: nothing (no other local modules)
- Used by: every logic module

**Platform & SDK Bridges:**
- Purpose: Isolate platform-specific behavior so game code stays portable
- Location: `mobile.lua` (OS detection, haptics, safe area), `yandex.lua` (Yandex Games SDK via Emscripten FFI)
- Used by: `main.lua`, `arena_screen.lua`, `game_over_screen.lua`, `coin_sort_screen.lua`

## Data Flow

**Coin Sort merge → Arena resource gain:**

1. Player clicks merge in `coin_sort_screen.lua`
2. `coin_sort.executeMergeOnBox()` runs merge logic, returns resulting coin level
3. `resources.onCoinMerge(new_level)` adds Fuel + Stars (capped, multiplied by skill tree)
4. `drops.onCSMerge(new_level)` probabilistically rolls Chest / Fuel Surge / Star Burst / Gen Token
5. Chests land on the CS shelf (`drops.shelf`); Gen Tokens increment `drops.gen_tokens`
6. When player switches to Arena via tab bar, `drops.flushShelfToDispenser()` moves chests into `arena.dispenser_queue`
7. Player taps generator in Arena: spends 1 Fuel (or Gen Token), pulls from shuffle bag, places item on grid

**Arena order completion → Coin Sort reward:**

1. Player satisfies an order (items removed from grid in `arena.lua`)
2. `arena_orders.completeOrder()` computes XP + bags + stars, calls `drops.onArenaOrderComplete(difficulty)`
3. `drops.onArenaOrderComplete()` probabilistically adds Hammer/AutoSort/BagBundle/DoubleMerge to `pending_cs_drops`
4. Next time player is in Coin Sort, `coin_sort_screen.enter()` applies pending drops

**Persistence flow (save batching):**

- Individual saves: each logic module calls `progression.setXData()` then `progression.save()` (disk write).
- Batched saves (`arena.save()`): calls `bags.sync()` + `resources.sync()` + `drops.sync()` (memory only) then single `progression.save()`.

**State Management:**
- All persistent state lives inside `progression.lua`'s `data` table and is serialized to `progression.dat` via a custom Lua table serializer (`loadstring`-compatible format).
- Transient (per-session) state lives in module-local variables inside each logic module (e.g., `local grid = {}` in `arena.lua`).
- Animation state is entirely transient in `animation.lua`.

## Key Abstractions

**Screen Table:**
- Purpose: Uniform interface for any game screen
- Examples: `coin_sort_screen.lua`, `arena_screen.lua`, `game_over_screen.lua`, `skill_tree_screen.lua`
- Pattern: Table with optional methods `enter()`, `exit()`, `update(dt)`, `draw()`, `mousepressed(x, y, button)`, `mousereleased(x, y, button)`, `keypressed(key, scancode, isrepeat)`, `mousemoved(x, y)`. Missing methods are silently skipped by `screens.lua`.

**Cell State (Arena grid):**
- Purpose: Represents one of the 56 arena grid cells
- Pattern: `nil` = empty, `{state="box", chain_id, level}` = closed box, `{state="sealed", chain_id, level}` = visible-immovable, `{chain_id, level}` = normal item, `{state="chest", charges, chain_id}` = chest item, generators are normal items with `level >= chain.generator_threshold`

**Coin Object (Coin Sort):**
- Purpose: Represents a single coin in a box slot
- Pattern: `{number = N}` where N is 1–50. Color derived at render time via `coin_utils.numberToColor(N)`.

**Lazy require (circular dependency breaker):**
- Pattern: When module A needs module B and B needs A, the `require()` call is deferred inside a function body rather than at module top level. Examples: `skill_tree.lua` ↔ `resources.lua`, `arena_orders.lua` → `arena.lua`.

## Entry Points

**`love.load()` in `main.lua`:**
- Triggers: LOVE2D runtime on startup
- Responsibilities: init all systems in dependency order (`progression` → `resources` → `bags` → `powerups` → `drops` → `skill_tree` → `arena` → `sound` → `yandex`), load assets, create fonts, init and register all screens, call `screens.switch("coin_sort")`

**`love.update(dt)` in `main.lua`:**
- Triggers: every frame
- Responsibilities: delegates to `screens.update(dt)` which calls the current screen's `update(dt)`; `bags.update(dt)` ticks the free-bag timer from within screen update methods

**`love.draw()` in `main.lua`:**
- Triggers: every frame after update
- Responsibilities: draws to off-screen canvas at virtual 1080×1920 resolution, then scales+letterboxes onto real window; delegates content to `screens.draw()`

**`love.mousepressed()` / `love.mousereleased()` in `main.lua`:**
- Triggers: mouse button or touch event
- Responsibilities: touch debounce (SDL+Emscripten double-fire), coordinate conversion via `input.toGameCoords()`, delegate to `screens.mousepressed(gx, gy, button)`

**`love.focus(false)` / `love.quit()` in `main.lua`:**
- Triggers: window loses focus or app quit
- Responsibilities: save `coin_sort` and `arena` state to disk

## Error Handling

**Strategy:** Crash-safe logging. Errors are not silently swallowed in gameplay logic; the custom error handler ensures crashes are recorded.

**Patterns:**
- `love.errorhandler` override in `main.lua`: writes crash trace to `/tmp/love_crash.log` and `love.filesystem`'s `crash.log` before re-invoking the default LOVE2D error screen.
- `pcall` used in `yandex.lua` for FFI initialization (graceful no-op if Emscripten not available) and in `progression.lua` for deserialization (returns `nil` on corrupt save).
- Logic modules do not use `pcall` internally — errors propagate up.
- VS Code debug adapter: `lldebugger.lua` attached via `conf.lua` when `LOCAL_LUA_DEBUGGER_VSCODE=1` is set; `love.errorhandler` re-raises for the debugger to catch.

## Cross-Cutting Concerns

**Logging:** None (no structured logging). Debug output via `print()` during development; `lldebugger.lua` for breakpoint debugging.

**Validation:** Input validation is minimal and inline. Grid bounds checked in `arena.lua` functions. Coin placement validity checked in `coin_sort.lua`.

**Authentication:** None.

**Coordinate System:** All game coordinates are in the 1080×2400 virtual canvas. `input.toGameCoords(x, y, ox, oy, scale)` converts real window pixels to virtual coords. The virtual canvas is rendered to a LOVE2D `Canvas` then scaled + letterboxed onto the actual window.

**Performance:**
- `mobile.isLowPerformance()` (true for Android/iOS/Web) gates particle counts, lifetime, and bounce count.
- `particles.lua` uses an active-list pool + `SpriteBatch` for O(1) alloc and single draw call.
- `graphics.lua` caches font metrics per font object to avoid per-frame `getWidth()`/`getHeight()` calls.
- No FPS cap; browser provides ~50-60fps natively.

---

*Architecture analysis: 2026-04-05*
