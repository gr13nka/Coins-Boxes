# Testing Patterns

**Analysis Date:** 2026-04-05

## Test Framework

**Runner:** None detected.

No test files exist in the repository. No test runner configuration was found (`busted.lua`, `spec/`, `test/`, `*.spec.lua`, `*.test.lua`). The project has no automated test suite.

**Assertion Library:** None.

**Run Commands:** Not applicable.

## Test File Organization

**Location:** No test files exist.

**Naming:** No convention established.

## Manual Testing Approach

The codebase uses several mechanisms as substitutes for automated tests:

**1. Persistence flag in `progression.init()`**

`progression.lua` accepts `enable_persistence` as a boolean parameter. When `false`, saves and loads are skipped — designed explicitly for testing scenarios:
```lua
--- Initialize the progression system
-- @param enable_persistence If false, don't save/load (for testing)
function progression.init(enable_persistence)
  persistenceEnabled = enable_persistence or true
  if persistenceEnabled then
    progression.load()
  end
end
```
In production (`main.lua`): `progression.init(true)`.

**2. F1 hard reset in `main.lua`**

Pressing F1 triggers a full state reset without restarting the process — useful for manually verifying fresh-game behavior:
```lua
function love.keypressed(key, scancode, isrepeat)
  if key == "f1" then
    progression.reset()
    resources.init()
    bags.init()
    powerups.init()
    drops.init()
    skill_tree.init()
    local arena = require("arena")
    arena.init()
    screens.switch("coin_sort")
    return
  end
end
```

**3. Dev-mode charges**

`powerups.lua` initializes both power-up counts to 100 (flagged as "dev/testing" in the CLAUDE.md docs), giving unlimited uses during development without a separate mock:
```lua
local auto_sort_count = 100
local hammer_count = 100
```

**4. VS Code debugger integration**

`conf.lua` and `main.lua` integrate `lldebugger.lua` (local Lua debugger) when `LOCAL_LUA_DEBUGGER_VSCODE=1` env var is set. This enables breakpoints and step-through debugging in VS Code:
```lua
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
  require("lldebugger").start()
end
```
The error handler in `main.lua` re-raises errors through the debugger when active:
```lua
function love.errorhandler(msg)
  if _G.lldebugger then
    error(msg, 2)
  end
  ...
end
```

**5. Crash log output**

`main.lua` writes crash logs to two locations on unhandled errors:
- `/tmp/love_crash.log` (absolute path)
- `crash.log` (LÖVE save directory)

This gives a persistent trace for post-crash analysis during manual testing.

## Mocking

**Framework:** None.

**Patterns:** No mocking infrastructure exists. The closest pattern is the deferred-`require` used to break circular dependencies — this is an architecture pattern, not a mock:
```lua
-- In resources.lua, deferred to avoid circular dep with skill_tree
local function getFuelCap()
  local st = require("skill_tree")
  return st.getFuelCap()
end
```

**What IS substituted in practice:**
- Platform-conditional no-ops in `yandex.lua` — all Yandex SDK calls silently no-op when not running on web:
  ```lua
  function yandex.showInterstitial()
    if not is_web or not js_eval then return end
    js_eval("window.yandexBridge.showInterstitial()")
  end
  ```
- `mobile.isLowPerformance()` returns true for both native mobile and web, enabling a single branch for performance-reduced paths

## Fixtures and Factories

**Test Data:** None (no test suite).

**In-game data initialization** uses a `getDefaultData()` local function in `progression.lua` that serves a similar role — it defines the canonical fresh-state structure:
```lua
local function getDefaultData()
  return {
    unlocks = { modes = { classic = true }, colors = { red = true, ... } },
    stats = { total_merges = 0, ... },
    powerups_data = { auto_sort = 100, hammer = 100 },
    ...
  }
end
```

**Factory functions** exist for game objects:
```lua
-- coin_utils.lua
function coin_utils.createCoin(number)
  return {number = number}
end
```

## Coverage

**Requirements:** None enforced.

**Coverage tooling:** None present.

**Untested surface area:** The entire codebase — no automated coverage exists. See CONCERNS.md for prioritized testing gaps.

## Test Types

**Unit Tests:** None.

**Integration Tests:** None.

**E2E Tests:** None. Manual playtesting is the only verification method.

## Testability Assessment

**Modules that are easiest to test** (pure data, no LÖVE calls):
- `coin_sort.lua` — all game logic, no graphics calls
- `resources.lua` — arithmetic with clear inputs/outputs
- `bags.lua` — timer and count logic
- `arena.lua` — grid operations (BFS, merge rules, order completion)
- `arena_chains.lua` — static data, rollDrop() is a pure function
- `arena_orders.lua` — static data + state machine
- `commissions.lua` — commission generation and tracking
- `drops.lua` — probability rolls
- `skill_tree.lua` — node unlock graph traversal
- `coin_utils.lua` — pure color mapping functions, no state

**Modules that require LÖVE stubs to test:**
- `progression.lua` — uses `love.filesystem`
- `sound.lua` — uses `love.audio`
- `particles.lua` — uses `love.graphics`
- `graphics.lua` — uses `love.graphics`
- `animation.lua` — uses `love.graphics` indirectly
- All `*_screen.lua` files — deeply coupled to `love.graphics`

**Circular dependency challenge:**
`resources` ↔ `skill_tree` use lazy `require()` to break the cycle. A test harness would need to handle module loading order carefully or stub one side.

## Recommended Testing Approach (if added)

**Framework:** [busted](https://lunarmodules.github.io/busted/) is the standard Lua test framework; works with Love2D projects by stubbing the `love` global.

**Stub pattern for LÖVE:**
```lua
-- test/love_stub.lua
love = {
  filesystem = { read = function() end, write = function() end },
  graphics = {},
  audio = {},
}
```

**Entry point for first tests:**
- `coin_utils.lua` — zero dependencies, pure functions
- `resources.lua` with `progression.init(false)` — disables file I/O
- `arena_chains.lua` — static data verification

---

*Testing analysis: 2026-04-05*
