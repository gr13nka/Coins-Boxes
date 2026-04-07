# Coding Conventions

**Analysis Date:** 2026-04-05

## Naming Patterns

**Files:**
- `snake_case` throughout: `coin_sort.lua`, `arena_screen.lua`, `arena_chains.lua`
- Two-word pattern: `<domain>_<role>.lua` — logic modules drop the suffix (`arena.lua`, `bags.lua`), screen modules append `_screen` (`arena_screen.lua`, `coin_sort_screen.lua`), data-only modules append the domain (`arena_chains.lua`, `arena_orders.lua`)

**Module tables:**
- Same name as the file, `snake_case`: `local coin_sort = {}`, `local arena_screen = {}`, `local tab_bar = {}`

**Public functions:**
- `module.verbNoun()` camelCase verbs: `arena.tapGenerator()`, `bags.addBags()`, `resources.spendFuel()`, `skill_tree.isUnlocked()`
- Getter prefix: `get` — `arena.getCell()`, `bags.getBags()`, `layout.getGridMetrics()`
- Boolean query prefix: `is` or `can` — `arena.isBox()`, `arena.canMerge()`, `mobile.isMobile()`, `coin_utils.isCoin()`

**Private (local) functions:**
- `camelCase` or descriptive `snake_case` depending on author — `local function getWeights(n)`, `local function rollChestDrop(chest_chain_id)`, `local function weightedRandom(weights)`
- Functions only used within the file are declared `local function` (not attached to the module table)

**Variables:**
- Module-level locals that are runtime state: `camelCase` — `local fuel = 0`, `local bags_count = 0`, `local activeCount = 0`
- Single-word locals inside functions: lowercase — `local r`, `local w`, `local ok`

**Constants:**
- `SCREAMING_SNAKE_CASE` for module-level literals: `local MERGE_REWARDS`, `local STASH_SIZE = 8`, `local TOUCH_DEBOUNCE = 0.2`, `local CELL_SIZE = 140`
- Enum-like tables use the same pattern: `local STATE = { IDLE = "idle", MERGING = "merging" }`

**Types / Schemas:**
- No formal type system; schema is documented inline as comments:
  ```lua
  -- Cell states:
  --   nil = empty
  --   {state="box", chain_id=X, level=Y} = closed box
  --   {chain_id=X, level=Y}              = normal item
  ```

## Code Style

**Formatting:**
- No automated formatter detected (no `.editorconfig`, `.stylua.toml`, or similar)
- 2-space indentation in most files (`main.lua`, `arena.lua`, `resources.lua`)
- 4-space indentation in some older files (`coin_sort.lua`, `layout.lua`) — inconsistency exists
- Single blank line between functions; double blank line not used consistently

**Line length:**
- No hard limit enforced; long lines appear in data tables and condition chains

**Semicolons:**
- Not used (idiomatic Lua)

## Module Structure Pattern

Every module follows the same skeleton:

```lua
-- module_name.lua
-- One-line purpose. Role annotation (Pure data module / no drawing).

local dep1 = require("dep1")
local module = {}

-- Private constants (SCREAMING_SNAKE_CASE)
local SOME_CONST = 42

-- Private state (camelCase or snake_case)
local state_var = 0

-- Private helpers (local function)
local function helper() end

-- Public API (module.name = function)
function module.init() ... end
function module.getSomething() return state_var end

return module
```

Key rules visible across the codebase:
- All `require()` calls are at the top of the file **except** when avoiding circular dependencies — in that case, `require()` is deferred to inside the function body: `local st = require("skill_tree")`
- The module table is returned at the bottom as the sole `return` statement
- No global state — all state is local to the module file

## Logic / Visual Separation

Enforced by project rule. Modules are tagged in their header comment:
- `-- Pure data module (no drawing).` — `resources.lua`, `bags.lua`, `drops.lua`, `powerups.lua`, `coin_sort.lua`, `arena.lua`, `arena_chains.lua`, `arena_orders.lua`, `skill_tree.lua`, `commissions.lua`
- Screen modules handle all `love.graphics.*` calls: `coin_sort_screen.lua`, `arena_screen.lua`, `game_over_screen.lua`, `skill_tree_screen.lua`
- `graphics.lua` draws game objects (coins, boxes) only — not UI buttons

## Import Organization

**Order pattern:**
1. Standard library / LÖVE globals (no explicit require needed)
2. Core infrastructure: `utils`, `layout`, `screens`, `progression`
3. Data modules: `resources`, `bags`, `drops`, `powerups`, `skill_tree`
4. Domain modules: `coin_sort`, `arena`, `arena_chains`, `arena_orders`
5. Rendering helpers: `graphics`, `particles`, `animation`, `sound`
6. Platform: `mobile`, `yandex`, `tab_bar`

No path aliases — all `require()` calls use bare filenames without extensions (`require("arena_chains")`, not `require("./arena_chains")`).

## Error Handling

**Strategy:** Silent fail with fallback, not exception propagation.

**Patterns observed:**

1. **Guard and return nil** — most common pattern in logic modules:
   ```lua
   function bags.useBag()
     if free_bags_queued > 0 then ... return coins end
     if bags_count > 0 then ... return coins end
     return nil  -- caller checks for nil
   end
   ```

2. **Boolean return for spend operations** — resource spends return `true/false`:
   ```lua
   function resources.spendFuel(n)
     if fuel >= n then
       fuel = fuel - n
       resources.save()
       return true
     end
     return false
   end
   ```

3. **`pcall` for risky I/O** — file operations and FFI wrapped in `pcall`:
   ```lua
   local ok, ffi = pcall(require, "ffi")
   pcall(function()
     ffi.C.emscripten_run_script(code)
   end)
   ```
   Seen in `yandex.lua` and `main.lua` error handler.

4. **`error()` for programmer mistakes** — used at boundaries where wrong usage is a bug:
   ```lua
   error("Screen not found: " .. name)  -- screens.lua
   ```

5. **Crash logging** — `main.lua` overrides `love.errorhandler` to write crash logs to `/tmp/love_crash.log` and `crash.log`.

6. **No goto** — the explicit project rule. Retry loops use `repeat/until`:
   ```lua
   repeat
     box_idx = active[math.random(num_active)]
     attempts = attempts + 1
   until (temp_box_counts[box_idx] or 0) < BOX_ROWS or attempts > 100
   ```

## Save Batching Pattern

To avoid redundant disk writes, modules expose both a saving variant and a no-save variant:
- Normal: `resources.addFuel(n)` — mutates state + calls `progression.save()`
- No-save: `resources.addFuelNoSave(n)` — mutates state only
- Sync: `resources.sync()` — pushes state to `progression` in-memory without disk write

Callers that perform multiple operations batch with `NoSave` variants then call `progression.save()` once via `arena.save()`.

## Logging

**Framework:** `print()` only (no logging library).

**Patterns:**
- Used for save/load failures: `print("Failed to save progression:", err)`
- No debug logging in hot paths
- FPS counter drawn on-canvas as a debug overlay in `main.lua`

## Comments

**When to comment:**
- File header: every file starts with `-- filename.lua` then a purpose line
- Section dividers: `--` dashes for major sections (especially in larger screen files):
  ```lua
  --------------------------------------------------------------------------------
  -- Draw helpers
  --------------------------------------------------------------------------------
  ```
- Complex algorithms explained inline (deal algorithm, BFS, shuffle bag)
- Non-obvious decisions prefixed with `-- NOTE:` or `-- NOTE(reason):`
  ```lua
  -- NOTE: love.touchpressed / love.touchreleased are intentionally NOT defined.
  ```

**LDoc/EmmyLua style:**
- Used inconsistently; `input.lua` and `graphics.lua` have it, most others do not:
  ```lua
  --- Convert window/screen coordinates to virtual game coordinates
  -- @param x Screen x coordinate
  -- @return Game x, Game y
  function input.toGameCoords(x, y, ox, oy, scale)
  ```

## Function Design

**Size:** No strict limit enforced; `arena.completeOrder()` and `arena.tapGenerator()` exceed 40 lines. The project rule flags files over 1,500 lines for refactoring (not individual functions).

**Parameters:**
- Simple value parameters, no options-table pattern
- Callbacks passed as last parameter: `startMerge(merge_data, onComplete, onBoxMerge, particles)`

**Return values:**
- Single value or `nil` for getters
- `true/false` for operations that can fail
- Tables for compound results: `resources.onCoinMerge()` returns `{fuel=N, stars=N}`
- Arrays for lists: `drops.rollMergeDrops()` returns array of drop descriptors

## Screen Interface Pattern

Screens are plain tables with optional duck-typed methods. The screen manager (`screens.lua`) calls them if they exist:
```lua
-- Required by screens.lua:
screen.enter()         -- called on switch-in
screen.exit()          -- called on switch-out
screen.update(dt)      -- called every frame
screen.draw()          -- called every frame
screen.mousepressed(x, y, button)
screen.mousereleased(x, y, button)
screen.keypressed(key, scancode, isrepeat)
screen.mousemoved(x, y)
```
All methods are optional — `screens.lua` guards every call with `if current_screen and current_screen.method then`.

## Layout Constants in Screen Files

Screen modules cache layout values in module-level locals at the top, even when `layout.lua` already has them — this avoids repeated table lookups in the draw loop:
```lua
local VW, VH = layout.VW, layout.VH
local TOP_Y = layout.GRID_TOP_Y
local COIN_R = layout.COIN_R
```
After calling `layout.applyMetrics()`, `graphics.updateMetrics()` and `input.updateMetrics()` must be called to refresh cached values.

---

*Convention analysis: 2026-04-05*
