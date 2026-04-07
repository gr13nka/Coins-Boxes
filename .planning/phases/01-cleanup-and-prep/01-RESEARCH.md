# Phase 1: Cleanup and Prep - Research

**Researched:** 2026-04-05
**Domain:** Dead code removal, save schema versioning, feature implementation in LOVE2D/Lua merge puzzle game
**Confidence:** HIGH

## Summary

Phase 1 addresses five concrete requirements: deleting 6 dead classic-mode files, cleaning stale progression schema fields, removing a duplicate merge function, adding save schema versioning with migration support, and implementing the double merge mechanic that is already wired into the drop system but never consumed.

The codebase investigation confirmed all five issues exactly as described in REQUIREMENTS.md and CONCERNS.md. The critical ordering constraint is that the `arena_chains.lua:286` `require("upgrades")` call must be fixed BEFORE deleting `upgrades.lua`, because the call is live (executes on every generator tap when quality bonus is non-zero). The double merge implementation is straightforward -- the drop/consume infrastructure already exists in `drops.lua`; the missing piece is consuming a charge inside `coin_sort.executeMergeOnBox()` to double the output coins, and showing the charge count in the CS screen UI.

No new libraries or external dependencies are needed. All changes are within existing Lua files and follow established module patterns. The save schema versioning pattern is a well-understood migration table approach that the prior research already outlined.

**Primary recommendation:** Fix the `arena_chains.lua` dead reference first (prevents crash), then delete dead files, clean schema, add versioning, remove dead merge, implement double merge -- in that dependency order.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CLN-01 | Dead code removed -- 6 classic mode files deleted, `arena_chains.lua:286` fixed | Verified: 6 files identified (game.lua, game_screen.lua, upgrades.lua, upgrades_screen.lua, currency.lua, emoji.lua). arena_chains.lua:286 confirmed calling `require("upgrades").getMaxCoinReached()`. No other live code references these dead modules. |
| CLN-02 | Stale progression schema cleaned -- unused fields removed | Verified: `currency`, `unlocks` (modes/colors/backgrounds/powerups/cosmetics), `upgrades_data` (houses, extra_rows, extra_columns, etc.), `achievements`, and classic-mode stats are not used by active game loop. Only `upgrades_data.max_coin_reached` is read by `coin_sort.lua`. |
| CLN-03 | Dead `coin_sort.merge()` removed | Verified: `coin_sort.merge()` (lines 612-683) is defined but zero callers exist in the entire codebase. It duplicates `executeMergeOnBox()`. |
| CLN-04 | Save schema versioning added | No existing versioning. `progression.lua` uses `mergeWithDefaults()` which is fragile for arrays. Migration table pattern is the standard approach. |
| CLN-05 | Double merge mechanic implemented | Verified: `drops.lua` has full charge tracking (`getDoubleMergeCharges()`, `useDoubleMerge()`). `applyPendingCSDrops()` clears charges but doesn't hand them off. `coin_sort.executeMergeOnBox()` needs to check and consume a charge, doubling `MERGE_OUTPUT`. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **No goto** -- use `repeat/until` loops for retries. Goto breaks the web build. [VERIFIED: CLAUDE.md]
- **Logic/visual separation** -- data modules have zero drawing code; screen modules handle all rendering. [VERIFIED: CLAUDE.md]
- **Module exports** -- each module returns a table of public functions. [VERIFIED: CLAUDE.md]
- **When file becomes bigger than 1.5k lines suggest refactoring.** [VERIFIED: CLAUDE.md]
- **Use LOVE2D and Lua best coding practices.** [VERIFIED: CLAUDE.md]
- **Document what you have done.** [VERIFIED: CLAUDE.md]

## Standard Stack

### Core

No new libraries needed. This phase modifies existing Lua modules only.

| Tool | Version | Purpose | Status |
|------|---------|---------|--------|
| LOVE2D | 11.5 | Game framework | Installed [VERIFIED: `love --version`] |
| Lua | 5.1 (via LuaJIT bundled in LOVE) | Language runtime | Bundled with LOVE [VERIFIED: LOVE 11.5 uses LuaJIT] |

### Supporting

No new dependencies. All changes use standard Lua table manipulation and `love.filesystem` APIs already in use.

## Architecture Patterns

### CLN-01: Dead Code Removal

**Six dead files to delete:**

| File | Role | Dead Since | Requires |
|------|------|------------|----------|
| `game.lua` | Classic mode logic | Original architecture | `utils` |
| `game_screen.lua` | Classic mode screen | Original architecture | `game`, `animation`, `particles`, `graphics`, `input`, `sound`, `layout`, `screens`, `progression`, `mobile` |
| `upgrades.lua` | Houses/rows/columns shop data | Replaced by skill tree | `progression`, `currency` |
| `upgrades_screen.lua` | Shop screen UI | Replaced by skill tree screen | `screens`, `layout`, `currency`, `upgrades`, `coin_utils`, `powerups`, `emoji` |
| `currency.lua` | Shard/crystal economy | Replaced by Fuel/Stars | `coin_utils`, `progression` |
| `emoji.lua` | Food emoji canvas icons | Only used by upgrades_screen | None (uses LOVE APIs) |

[VERIFIED: grep for `require()` of each module in all non-dead .lua files]

**Critical dependency:** `arena_chains.lua:286` calls `require("upgrades").getMaxCoinReached()`. This is the ONLY live reference to any dead module. [VERIFIED: grep confirmed]

**Fix pattern:** Replace line 286 in `arena_chains.lua` with:
```lua
local prog = require("progression")
local mcr = (prog.getUpgradesData().max_coin_reached) or 0
```
This reads the same `max_coin_reached` value from `progression.getUpgradesData()` without going through `upgrades.lua`. The `coin_sort.lua:setMaxCoinReached()` function already writes this field to `progression.getUpgradesData()` (lines 264-270), so the data flow is correct. [VERIFIED: coin_sort.lua:268-270]

**Dormant code in `screens.lua`:** The `mode_select` screen (lines 109-258) references `progression.isUnlocked("modes", ...)` which reads from `data.unlocks.modes`. This code is dormant (never navigated to since main.lua starts directly in `coin_sort`), but it is not one of the 6 files to delete. It can stay as-is for now -- the `unlocks` cleanup in CLN-02 should preserve the structure enough that this code won't crash if ever re-enabled, or it can be removed as part of the dead code sweep. [VERIFIED: screens.lua:144]

### CLN-02: Stale Progression Schema

**Fields actually used by the active game loop:**

| Field | Used By | How |
|-------|---------|-----|
| `resources_data` | `resources.lua` | Fuel + Stars |
| `bags_data` | `bags.lua` | Bag count + timer |
| `drops_data` | `drops.lua` | Shelf, gen tokens, pending CS drops |
| `skill_tree_data` | `skill_tree.lua` | Unlocked nodes + stars spent |
| `arena_data` | `arena.lua` | Grid, stash, dispenser, orders, tutorial |
| `coin_sort_data` | `coin_sort.lua` | Boxes, points, merges, active state |
| `powerups_data` | `powerups.lua` | Auto sort + hammer charges |
| `upgrades_data.max_coin_reached` | `coin_sort.lua` | Historical max coin level |
| `stats.total_merges` | `progression.lua` | Unlock conditions |
| `stats.total_points` | `progression.lua` | Unlock conditions |
| `stats.games_played` | `progression.lua` | Achievement conditions |
| `stats.total_coins_placed` | `progression.lua` | Tracked (onCoinPlaced) |

[VERIFIED: grep of all accessor calls in non-dead .lua files]

**Fields to remove from `getDefaultData()`:**

| Field | Reason | Risk |
|-------|--------|------|
| `currency` | Only used by dead `currency.lua` | None |
| `unlocks.modes` | Only used by dormant `mode_select` screen | Low -- mode_select is never navigated to |
| `unlocks.colors` | Only used by dead `game.lua`/`game_screen.lua` | None |
| `unlocks.backgrounds` | Only used by dead code | None |
| `unlocks.powerups` | Never used anywhere | None |
| `unlocks.cosmetics` | Never used anywhere | None |
| `upgrades_data.extra_rows` | Only used by dead `upgrades.lua` | None |
| `upgrades_data.extra_columns` | Only used by dead `upgrades.lua` | None |
| `upgrades_data.houses_unlocked` | Only used by dead `upgrades.lua` | None |
| `upgrades_data.free_house_available` | Only used by dead `upgrades.lua` | None |
| `upgrades_data.difficulty_extra_types` | Only used by dead `upgrades.lua` | None |
| `upgrades_data.houses` | Only used by dead `upgrades.lua` | None |
| `achievements` | Checked by `progression.lua` internally but never displayed or consumed by active game | Medium -- internal tracking, no visible effect |
| `stats.highest_score_classic` | Referenced in achievement check, but classic mode is dead | Low |
| `stats.highest_score_2048` | Referenced in achievement check, but 2048 was old name for coin_sort | Low |

**Key decision for planner:** The `upgrades_data` field itself cannot be fully deleted because `coin_sort.lua` reads `.max_coin_reached` from it. Two approaches:

1. **Minimal:** Keep `upgrades_data` but strip it to just `{max_coin_reached = 0}`. Remove all other sub-fields.
2. **Proper:** Move `max_coin_reached` to a top-level field (e.g., `data.max_coin_reached`) and delete `upgrades_data` entirely. Update `coin_sort.lua:268,311` to use the new path. [ASSUMED -- this is a design choice]

Option 2 is cleaner for future development but requires updating 2 read sites + 1 write site in `coin_sort.lua`. Option 1 is faster and lower risk.

**Stale progression API functions to remove:**

| Function | Reason |
|----------|--------|
| `progression.getCurrencyData()` / `setCurrencyData()` | Only called by dead `currency.lua` |
| `progression.getUpgradesData()` / `setUpgradesData()` | Called by dead `upgrades.lua` AND live `coin_sort.lua` -- must keep or migrate |

[VERIFIED: grep of all callers]

### CLN-03: Dead `coin_sort.merge()`

Lines 612-683 of `coin_sort.lua` define `coin_sort.merge()` which is a legacy synchronous merge path. Zero callers exist in the entire codebase (only the definition at line 612). [VERIFIED: grep `coin_sort\.merge\b` returns only the definition]

The function duplicates `executeMergeOnBox()` with these divergences:
- `merge()` iterates all boxes and merges all at once, while `executeMergeOnBox()` handles one box per call (animation drives the loop)
- `merge()` does not return `drop_results` or `commissions_refreshed` to the caller
- `merge()` does not track `commissions_refreshed` flag

Safe to delete entirely.

### CLN-04: Save Schema Versioning

**Current state:** `progression.dat` is a serialized Lua table with no version marker. `mergeWithDefaults()` is the only migration mechanism -- it recursively merges loaded data with defaults. [VERIFIED: progression.lua:281-304]

**Fragilities of `mergeWithDefaults()`:**
- Uses `#val > 0` to detect arrays -- unreliable for sparse Lua tables [VERIFIED: progression.lua:184 uses `#val`]
- Preserves loaded keys not in defaults (line 298-302), preventing cleanup of removed fields
- No way to distinguish "old save missing a new field" from "save where field was intentionally cleared"

**Recommended pattern (migration table):**

```lua
-- In progression.lua
local CURRENT_SCHEMA_VERSION = 1

local MIGRATIONS = {
  -- [2] = function(data) ... return data end,  -- future migrations
}

-- In progression.load(), after deserializing:
local version = data.schema_version or 0
while version < CURRENT_SCHEMA_VERSION do
  version = version + 1
  if MIGRATIONS[version] then
    data = MIGRATIONS[version](data)
  end
  data.schema_version = version
end
```

[ASSUMED -- this is a standard pattern for schema migration, not specific to any LOVE2D library]

**Version 1 migration** (for existing saves without `schema_version`):
- Set `schema_version = 1`
- Strip removed fields (`currency`, dead `unlocks` sub-tables, dead `upgrades_data` sub-fields)
- Preserve `upgrades_data.max_coin_reached` (move or keep depending on CLN-02 decision)
- Any missing active fields get defaults via explicit nil-guards (not `mergeWithDefaults`)

**Important:** `mergeWithDefaults()` should still be called as a safety net AFTER migrations, but the migration functions handle structural changes (field moves, renames, removals) that `mergeWithDefaults()` cannot.

### CLN-05: Double Merge Mechanic

**Existing infrastructure (all in `drops.lua`):**
- `drops.rollOrderDrops()` awards `double_merge` charges on hard orders (2.5% chance) [VERIFIED: drops.lua:153-155]
- `drops.getDoubleMergeCharges()` returns current charge count [VERIFIED: drops.lua:263]
- `drops.useDoubleMerge()` decrements charge, returns true/false [VERIFIED: drops.lua:266-270]
- `drops.applyPendingCSDrops()` clears `pending_cs_drops.double_merge` and reports it in `applied` but does NOT transfer charges anywhere [VERIFIED: drops.lua:249-251]
- `arena_screen.lua:1216` shows "+1 Double Merge!" notification on order drop [VERIFIED]

**What's missing:**
1. **In `drops.applyPendingCSDrops()`:** The `double_merge` charges are currently zeroed out (line 251) without being preserved as active charges. The current code structure tracks `pending_cs_drops.double_merge` as the pending count AND the active count -- but `applyPendingCSDrops()` zeroes the pending count, losing the charges. This needs a design decision: either keep a separate `active_double_merge` counter, or don't zero pending_cs_drops.double_merge in apply (let it be consumed directly by `useDoubleMerge()`).

   Looking more carefully: `useDoubleMerge()` reads from `pending_cs_drops.double_merge` directly (line 267-268), and `applyPendingCSDrops()` zeroes it (line 251). So if `applyPendingCSDrops()` runs first on CS enter, the charges are lost before they can be used. **This is a bug in the existing code.** The fix: do NOT zero `double_merge` in `applyPendingCSDrops()` -- it should remain for `useDoubleMerge()` to consume during gameplay. [VERIFIED: drops.lua:249-251, 266-268]

2. **In `coin_sort.executeMergeOnBox()`:** After computing `MERGE_OUTPUT` coins, check if a double merge charge is active. If so, consume it and double the output count.

3. **In `coin_sort_screen.lua`:** Display the double merge charge count somewhere visible (e.g., near the merge button or as a status indicator). Show a visual indicator when a charge is about to be consumed (e.g., "2x" badge on the merge button).

**Implementation pattern:**

```lua
-- In coin_sort.executeMergeOnBox():
local output_count = MERGE_OUTPUT
local used_double = false
if drops.getDoubleMergeCharges() > 0 then
    drops.useDoubleMerge()
    output_count = MERGE_OUTPUT * 2
    used_double = true
end
for _ = 1, output_count do
    table.insert(box, coin_utils.createCoin(new_number))
end
-- Return used_double flag for UI feedback
return true, gained, drop_results, commissions_refreshed, used_double
```

[ASSUMED -- exact implementation design, but follows existing module patterns]

**Logic/visual separation note:** The charge check and consumption happen in `coin_sort.lua` (logic). The visual indicator (2x badge, notification) is in `coin_sort_screen.lua` (visual). This follows the project's CLAUDE.md pattern. [VERIFIED: CLAUDE.md directives]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Save serialization | Custom binary format | Existing Lua `serialize()`/`deserialize()` in `progression.lua` | Already works, human-readable for debugging |
| Schema migration | Ad-hoc if/else version checks | Migration function table indexed by version number | Composable, testable, each migration is isolated |
| Double merge state tracking | New module or global state | Existing `drops.lua` charge system (`getDoubleMergeCharges()`, `useDoubleMerge()`) | Already built and persisted |

## Common Pitfalls

### Pitfall 1: Deleting `upgrades.lua` Before Fixing `arena_chains.lua:286`
**What goes wrong:** Generator taps crash with "module 'upgrades' not found" -- but only when `max_coin_reached >= 3` (quality bonus threshold), so early testing misses it.
**Why it happens:** The `require("upgrades")` call is inside `rollDrop()` which executes conditionally.
**How to avoid:** Fix `arena_chains.lua:286` as the very first task. Verify with `max_coin_reached >= 5` save data.
**Warning signs:** Lua error on generator tap mentioning "upgrades" module.
[VERIFIED: arena_chains.lua:286, .planning/research/PITFALLS.md]

### Pitfall 2: `mergeWithDefaults()` Re-Populating Removed Fields From Old Saves
**What goes wrong:** Old save files contain `currency`, `upgrades_data.houses`, etc. After schema cleanup removes these from defaults, `mergeWithDefaults()` line 298-302 still preserves loaded keys not in defaults. So the stale data persists in memory and gets re-serialized.
**Why it happens:** `mergeWithDefaults()` was designed to never lose data -- it keeps both default AND loaded keys.
**How to avoid:** The migration function must actively DELETE stale keys (`data.currency = nil`). Do not rely on "removing from defaults" to clean old saves.
**Warning signs:** Save file still contains old fields after "cleanup" update.
[VERIFIED: progression.lua:298-302]

### Pitfall 3: Double Merge Charges Lost on CS Enter
**What goes wrong:** `drops.applyPendingCSDrops()` zeroes `pending_cs_drops.double_merge` on CS screen enter (line 251), but `drops.useDoubleMerge()` reads from the same counter (line 267). If apply runs before use, charges are permanently lost.
**Why it happens:** `applyPendingCSDrops()` was designed for hammer/auto_sort which transfer charges to `powerups.lua`. Double merge has no separate target -- it should stay in `drops` state.
**How to avoid:** Do NOT zero `double_merge` in `applyPendingCSDrops()`. Let `useDoubleMerge()` be the only consumer.
**Warning signs:** Player earns double merge from hard orders but charge count is 0 when entering CS.
[VERIFIED: drops.lua:249-251, 266-268]

### Pitfall 4: Schema Version Migration Runs Before `mergeWithDefaults()` Fills Missing Fields
**What goes wrong:** Migration function references `data.some_field` which doesn't exist in old saves because `mergeWithDefaults()` hasn't run yet. Migration crashes with nil access.
**Why it happens:** Migration and default-fill are both "upgrade" operations but run at different stages.
**How to avoid:** Run migrations BEFORE `mergeWithDefaults()`. Migrations should use explicit nil-guards (`data.field = data.field or default_value`) rather than assuming fields exist.
**Warning signs:** Lua error in migration function on save load.
[ASSUMED -- standard migration pitfall]

### Pitfall 5: Removing Progression API Functions That `coin_sort.lua` Still Uses
**What goes wrong:** Deleting `progression.getUpgradesData()` / `setUpgradesData()` as "dead" breaks `coin_sort.lua:268,311` which reads/writes `max_coin_reached` through these functions.
**Why it happens:** The functions serve both dead code (`upgrades.lua`) and live code (`coin_sort.lua`).
**How to avoid:** Either keep these functions (Option 1) or migrate `coin_sort.lua` to a new accessor path first (Option 2). Do not batch-delete based on "upgrades" name association.
**Warning signs:** Error on coin_sort init or merge about nil function.
[VERIFIED: coin_sort.lua:268,311 calls getUpgradesData/setUpgradesData]

## Code Examples

### Fixing `arena_chains.lua:286` (CLN-01)

Before:
```lua
-- arena_chains.lua:286 (current)
local upgrades = require("upgrades")
local mcr = upgrades.getMaxCoinReached()
```

After:
```lua
-- arena_chains.lua:286 (fixed)
local prog = require("progression")
local mcr = (prog.getUpgradesData() or {}).max_coin_reached or 0
```
[VERIFIED: arena_chains.lua:286-287, coin_sort.lua:268-270 writes to same field]

### Schema Version Migration Skeleton (CLN-04)

```lua
-- In progression.lua

local CURRENT_SCHEMA_VERSION = 1

local MIGRATIONS = {
  -- Migration to version 1: clean stale classic-mode fields
  [1] = function(data)
    -- Remove dead currency system
    data.currency = nil
    -- Clean dead unlock categories (keep structure for mode_select compatibility)
    if data.unlocks then
      data.unlocks.colors = nil
      data.unlocks.backgrounds = nil
      data.unlocks.powerups = nil
      data.unlocks.cosmetics = nil
    end
    -- Strip dead upgrades_data sub-fields, keep max_coin_reached
    if data.upgrades_data then
      local mcr = data.upgrades_data.max_coin_reached
      data.upgrades_data = { max_coin_reached = mcr or 0 }
    end
    -- Clean dead achievement references
    data.achievements = nil
    return data
  end,
}

-- In progression.load(), after deserialize:
local function runMigrations(data)
  local version = data.schema_version or 0
  while version < CURRENT_SCHEMA_VERSION do
    version = version + 1
    if MIGRATIONS[version] then
      data = MIGRATIONS[version](data)
    end
    data.schema_version = version
  end
  return data
end
```
[ASSUMED -- pattern design, follows standard migration table approach]

### Double Merge in `executeMergeOnBox()` (CLN-05)

```lua
-- In coin_sort.executeMergeOnBox(), after computing new_number:
local output_count = MERGE_OUTPUT
local used_double = false
if drops.getDoubleMergeCharges() > 0 then
    drops.useDoubleMerge()
    output_count = MERGE_OUTPUT * 2
    used_double = true
end
for _ = 1, output_count do
    table.insert(box, coin_utils.createCoin(new_number))
end
```
[ASSUMED -- implementation design, follows existing patterns]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `mergeWithDefaults()` only | Schema version + migration table + `mergeWithDefaults()` fallback | This phase | Enables safe future schema changes |
| Dead `coin_sort.merge()` | All merges go through `executeMergeOnBox()` via animation system | Already true (merge() already dead) | Single merge path, no divergence risk |
| `require("upgrades")` in arena_chains | Direct progression data access | This phase | No dependency on dead modules |

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None -- no test infrastructure exists |
| Config file | None |
| Quick run command | `love /home/username/Documents/Coins-Boxes` (manual launch) |
| Full suite command | N/A |

No standalone Lua or LuaJIT CLI is installed. LOVE2D 11.5 is available but tests would need to run within the LOVE environment. [VERIFIED: `which lua luajit` found nothing, `love --version` returns 11.5]

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CLN-01 | Game launches without dead module errors | smoke | `love . --headless` (if supported) or manual launch | N/A |
| CLN-02 | Save file contains only active fields | manual | Load game, save, inspect progression.dat | N/A |
| CLN-03 | `coin_sort.merge` no longer exists | grep | `grep -r "coin_sort\.merge\b" *.lua` returns only 0 results | N/A |
| CLN-04 | Old save migrates to schema_version 1 | manual | Create old save, load after update, verify fields | N/A |
| CLN-05 | Double merge produces 4 coins instead of 2 | manual | Earn double merge charge, trigger merge, count output | N/A |

### Wave 0 Gaps

- No test framework installed or configured
- No standalone Lua interpreter for unit tests
- All verification must be manual (launch game, inspect behavior) or static (grep for removed code)
- **Recommendation:** Static verification (grep for dead requires, dead functions) is sufficient for CLN-01/CLN-02/CLN-03. CLN-04/CLN-05 require manual gameplay testing.

## Assumptions Log

> List all claims tagged [ASSUMED] in this research. The planner and discuss-phase use this
> section to identify decisions that need user confirmation before execution.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Moving `max_coin_reached` to a top-level field (Option 2) is cleaner than keeping `upgrades_data` stub | CLN-02 Architecture | Low -- Option 1 (minimal) works fine either way |
| A2 | Migration table pattern (version number + function table) is the right approach | CLN-04 Architecture | Low -- this is a widely-used pattern |
| A3 | Schema version 1 migration should actively nil-out stale fields | CLN-04 Code Example | Medium -- if any hidden code reads stale fields, it breaks |
| A4 | Double merge should produce 2x MERGE_OUTPUT coins (4 instead of 2) | CLN-05 Architecture | Medium -- "double output" could mean double resources instead |
| A5 | `double_merge` charges should NOT be zeroed in `applyPendingCSDrops()` | CLN-05 Pitfalls | Low -- current behavior is clearly a bug (charges lost) |

## Open Questions (RESOLVED)

1. **What exactly does "double merge" mean?** — RESOLVED: Implement as 2x output coin count (4 coins of next level instead of 2). This is the most impactful and visible interpretation, matching CLN-05 wording "produces double output coins".

2. **Should the mode_select screen dormant code be cleaned up too?** — RESOLVED: Leave it. It's in `screens.lua` (not a separate file) and may be revived later. Not in scope for Phase 1.

3. **Should `progression.onMerge()`, `onPoints()`, `onGameEnd()`, `onCoinPlaced()` be cleaned up?** — RESOLVED: Keep them. The `stats` fields they populate are used by achievement conditions. Not blocking for Phase 1.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| LOVE2D | Manual smoke testing | Yes | 11.5 | -- |
| Standalone Lua | Unit tests | No | -- | Manual testing via LOVE |
| Text editor | Code changes | Yes | -- | -- |

**Missing dependencies with no fallback:**
- None (all changes are code edits, verifiable by launching the game)

**Missing dependencies with fallback:**
- Standalone Lua interpreter: not installed, but all testing can be done through LOVE2D launch

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection of all referenced files:
  - `progression.lua` -- full read, schema analysis
  - `coin_sort.lua` -- full read, merge flow analysis
  - `arena_chains.lua` -- full read, rollDrop() dead reference confirmed at line 286
  - `drops.lua` -- full read, double merge infrastructure confirmed
  - `coin_sort_screen.lua` -- merge callback flow, applyPendingCSDrops usage
  - `arena_screen.lua:1216` -- double merge notification display
  - `upgrades.lua`, `currency.lua`, `game.lua`, `game_screen.lua`, `upgrades_screen.lua`, `emoji.lua` -- confirmed dead, cross-reference analysis
  - `screens.lua` -- mode_select dormant code identified
  - `main.lua` -- confirmed no requires of dead modules

### Secondary (MEDIUM confidence)
- `.planning/codebase/CONCERNS.md` -- prior codebase analysis documenting all issues
- `.planning/research/PITFALLS.md` -- prior domain research with detailed pitfall analysis
- `.planning/research/SUMMARY.md` -- prior research summary with phase ordering rationale

### Tertiary (LOW confidence)
- [LOVE2D Forums: Save file patterns](https://love2d.org/forums/viewtopic.php?t=91852) -- confirms Lua serialization is standard approach, no built-in migration system

## Metadata

**Confidence breakdown:**
- Dead code identification: HIGH -- grep-verified, all call sites checked
- Schema analysis: HIGH -- all accessor functions traced to callers
- Double merge implementation: MEDIUM -- design is straightforward but exact UX interpretation needs confirmation
- Migration pattern: HIGH -- standard approach, well-understood
- Pitfalls: HIGH -- verified against actual code, cross-referenced with prior research

**Research date:** 2026-04-05
**Valid until:** 2026-05-05 (stable codebase, no external dependency changes expected)
