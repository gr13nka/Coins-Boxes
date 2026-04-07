# Codebase Concerns

**Analysis Date:** 2026-04-05

---

## Tech Debt

**Dead modules from a previous game mode still in the repository:**
- Issue: `game.lua`, `game_screen.lua`, `upgrades.lua`, `upgrades_screen.lua`, `currency.lua`, `emoji.lua` are never loaded by `main.lua` and are not registered as screens. They belong to a scrapped "classic mode" with its own economy (crystals, houses, color unlocks). They reference each other and `arena_chains.lua` still has a live `require("upgrades")` call at line 286 to read `upgrades.getMaxCoinReached()`, even though the active game uses `coin_sort` to track `max_coin_reached` internally.
- Files: `game.lua`, `game_screen.lua`, `upgrades.lua`, `upgrades_screen.lua`, `currency.lua`, `emoji.lua`, `arena_chains.lua:286`
- Impact: `arena_chains.lua:rollDrop()` silently calls into dead code every time a generator drop quality bonus is calculated. If `upgrades.lua` ever fails to load or its API changes, arena drops break silently with no error during normal play. Dead code inflates binary/load cost on web.
- Fix approach: Replace the `require("upgrades").getMaxCoinReached()` call in `arena_chains.lua` with a direct read from `progression.getUpgradesData().max_coin_reached` or — better — expose `coin_sort.getMaxCoinReached()` and route it properly. Then delete the six dead files.

**`progression.lua` carries stale schema from the old classic mode:**
- Issue: `getDefaultData()` still initialises `currency`, `unlocks.colors`, `unlocks.backgrounds`, `unlocks.modes`, `stats.highest_score_classic`, `stats.highest_score_2048`, `upgrades_data` (with houses, extra rows/columns). None of these fields are read by the active game loop. They are serialised to `progression.dat` on every save, bloating the file unnecessarily.
- Files: `progression.lua:8-123`
- Impact: Save file grows each session. `mergeWithDefaults()` copies all stale keys into every load, hiding the actual active schema. Adding a real field with the same name as a stale one would produce a silent collision.
- Fix approach: Audit which fields are actually read by `resources.lua`, `bags.lua`, `drops.lua`, `arena.lua`, `coin_sort.lua`, `skill_tree.lua`. Delete the rest from `getDefaultData()` and from `mergeWithDefaults()`. Add a `schema_version` key so future migrations are explicit.

**`double_merge` drop type is fully wired but never consumed in Coin Sort:**
- Issue: `drops.rollOrderDrops()` can award a `double_merge` charge, `drops.useDoubleMerge()` and `drops.getDoubleMergeCharges()` exist, and the pending counter is tracked in saves. But `coin_sort.lua` and `coin_sort_screen.lua` never call either function — the charges accumulate in saves forever without effect.
- Files: `drops.lua:152-268`, `coin_sort.lua` (no reference), `coin_sort_screen.lua` (no reference)
- Impact: Players are shown "+1 Double Merge!" notification from `arena_screen.lua:1217` but nothing ever happens. Misleading UX.
- Fix approach: Either implement the mechanic (double output on next merge in Coin Sort) or remove the type from drop tables and clean up the dead state.

**`coin_sort.merge()` is a full duplicate of `executeMergeOnBox()`:**
- Issue: `coin_sort.merge()` (lines 612–683) performs the same box scan, coin removal, resource award, commission tracking, and drop rolling as `coin_sort.executeMergeOnBox()` (lines 556–607). The animated path calls `executeMergeOnBox()`; the non-animated (button-release) path calls the animation layer which also ends up calling `executeMergeOnBox()`. `merge()` appears to be a legacy synchronous path that is no longer called anywhere.
- Files: `coin_sort.lua:612-683`
- Impact: Two divergent merge implementations. Any balance tweak (drop rates, resources) must be applied to both or introduces a split-brain bug.
- Fix approach: Verify `merge()` is never called (grep shows no callers outside of itself). If confirmed dead, delete it.

**`arena.placeFromDispenser()` is defined but never called:**
- Issue: `arena.placeFromDispenser(target_index)` at line 525 accepts a target grid index and places from the dispenser queue. The actual tap-to-pop flow always uses `arena.popDispenserToGrid()` instead. The drag-to-place flow for dispenser items was removed.
- Files: `arena.lua:525-533`
- Impact: Dead surface area in the API. Confusing for future developers trying to understand the dispenser interaction model.
- Fix approach: Delete `arena.placeFromDispenser()` unless a drag-to-place feature is planned.

**`arena_screen.lua` recomputes scale/offset in `update()` instead of using the canonical values from `main.lua`:**
- Issue: Lines 1081–1086 manually recompute `sc`, `oox`, `ooy` from `love.graphics.getDimensions()` to convert drag coordinates. The same math is in `main.lua` and `input.lua`. This creates a third copy of the coordinate transform that can drift if `main.lua`'s `recalcScale()` changes.
- Files: `arena_screen.lua:1079-1087`, `main.lua:41-46`, `input.lua`
- Impact: If window resize behaviour changes, drag coordinates will silently break in arena but nowhere else.
- Fix approach: Expose `ox`, `oy`, `scale` from `main.lua` or `input.lua` as a shared getter, or pass them to `arena_screen` through the assets bundle.

---

## Known Bugs

**Tutorial step 8/9 duplicate — generator tap advances from both steps 8 and 9:**
- Symptoms: Steps 8 and 9 have identical handler code (`advanceTutorial` in `arena_screen.lua:920-929`). Step 7 also shares the "unseal merge" handler with step 6. The state machine can get stuck at step 7 if the player merges in a state where step 6 already advanced (the sealed Ch3 is gone, but the tutorial is still expecting it).
- Files: `arena_screen.lua:912-929`
- Trigger: Reach tutorial step 6, immediately merge onto a different sealed cell instead of the correct one, then try to continue.
- Workaround: None; the tutorial must be restarted (via the reset hold button).

**Drag position tracking on touch is split between mouse and touch paths:**
- Symptoms: `arena_screen.update()` at line 1079 only updates `drag.x/y` from `love.mouse.isDown(1)`. The `touchmoved` handler at line 1421 also updates `drag.x/y`. On web (SDL+Emscripten), where both events fire, the drag position may stutter on fast moves as the two updates race.
- Files: `arena_screen.lua:1079-1087`, `arena_screen.lua:1421-1425`
- Trigger: Fast drag on web build.
- Workaround: Touch `touchmoved` wins (last write), but timing depends on event order.

**Shuffle bag can supply items for locked generator chains:**
- Symptoms: `arena.refillShuffleBag()` calls `arena_orders.getAllRemainingRequirements()`, which filters by `isOrderProducible()`. However, `isOrderProducible()` only checks the direct producer chain, not whether sub-chain items are reachable. A generator that is unlocked but depleted and recharging will still contribute its orders to the shuffle bag even though no items can currently be produced.
- Files: `arena.lua:457-468`, `arena_orders.lua:464-481`
- Trigger: All generator charges depleted simultaneously. Shuffle bag fills with items no active generator can currently produce. `pullFromShuffleBag()` finds no match and falls through to the random `rollDrop()` fallback.
- Workaround: The fallback `rollDrop()` fires, producing something — but not what the orders need.

**`arena_orders.advanceLevel()` mutates `rewards` table returned by `level_data.level_rewards`:**
- Symptoms: `advanceLevel()` at line 572 does `rewards.bag_reward = ...` and `rewards.star_reward = ...` directly on the table retrieved from `ORDER_LEVELS`, which is a module-level constant. This overwrites the static data in place on first call. Subsequent resets (via `progression.reset()`) could return incorrect level reward values if the level is ever re-visited.
- Files: `arena_orders.lua:562-578`
- Trigger: Complete level 1, reset progression, complete level 1 again — the `bag_reward`/`star_reward` fields on the static table are already set to the level-1 computed values from the first run.
- Workaround: Currently masked because `progression.reset()` also resets `arena_data`, triggering a fresh `arena_orders.init()`. But any future path that resets orders without reload would expose this.

---

## Security Considerations

**Save file loaded via `load()` / `loadstring()` executes arbitrary Lua:**
- Risk: `progression.lua:208` uses `(loadstring or load)(str)` to deserialize the save file. Any malicious or corrupted save file containing executable Lua is run with full game privileges.
- Files: `progression.lua:207-213`
- Current mitigation: The save file is in `love.filesystem` (sandboxed directory) on desktop; on web, it is in browser LocalStorage. Attacker would need filesystem write access, which is unlikely in casual games. LOVE's sandbox prevents OS-level damage.
- Recommendations: Replace with a purpose-built deserializer (e.g., a recursive table parser that only accepts numbers, strings, booleans, and nested tables without function values). This is straightforward since the data format is regular.

**FPS counter is always visible in production builds:**
- Risk: Not a security risk, but a product quality issue. `main.lua:162-167` draws the FPS counter unconditionally on every frame. There is no release flag.
- Files: `main.lua:162-167`
- Recommendations: Gate behind `love.filesystem.getInfo("debug_mode")` or a compile-time constant.

**F1 key resets all progression without confirmation in production:**
- Risk: `main.lua:180-192` listens for F1 on any platform and immediately resets all save data. On web, the keyboard is accessible.
- Files: `main.lua:179-192`
- Recommendations: Remove from production or gate behind a multi-key combination. The 3-second hold reset button in `coin_sort_screen.lua` already provides a safer UX path.

---

## Performance Bottlenecks

**`arena.save()` is called on every single grid interaction:**
- Problem: Every `moveItem()`, `moveToStash()`, `moveFromStash()`, `moveStashToStash()`, `tapGenerator()`, `tapChest()`, `executeMerge()`, `popDispenserToGrid()` individually calls `arena.save()`, which in turn calls `bags.sync()`, `resources.sync()`, `drops.sync()`, and `progression.save()` — which serializes the entire data table and writes to disk.
- Files: `arena.lua:243, 279, 371, 443, 453, 534, 549, 573, 586, 598, 658, 696, 750`
- Cause: No dirty-flag batching. Every user interaction triggers a full serialize-and-write cycle.
- Improvement path: Introduce a dirty flag (`arena_dirty = true`) set on mutation, cleared on save. Call `arena.save()` only from `arena_screen.exit()`, `love.focus()`, `love.quit()`, and a periodic timer (e.g., every 30 seconds). The `NoSave` variants used in `resources` and `bags` show the pattern is understood — it just needs to be applied consistently to arena.

**`arena_orders.getAllRemainingRequirements()` and `isOrderProducible()` are called every generator tap to rebuild the shuffle bag:**
- Problem: `arena.refillShuffleBag()` iterates all orders and calls `isOrderProducible()` for each, which itself calls `arena.isGeneratorUnlocked()` → `require("skill_tree")` (lazy require) → table lookup. This runs on every generator tap when the bag is empty.
- Files: `arena.lua:457-468`, `arena_orders.lua:464-481, 611-625`
- Cause: No caching of the shuffle bag fill between taps. The bag is only cleared on level advance, so repeated empty-bag taps all re-compute the same requirement list.
- Improvement path: Cache the result of `getAllRemainingRequirements()` and invalidate only on order completion or level advance.

**`arena_screen.draw()` calls `arena.getGrid()` and iterates all 56 cells on every frame for order highlighting:**
- Problem: `drawOrdersStrip()` (called every frame) builds `on_board_counts` by iterating all 56 grid cells every draw call. With orders showing 3 cards, this is 56 × 3 cell lookups per frame.
- Files: `arena_screen.lua:664-670`
- Cause: No caching of item counts between frames. The grid changes infrequently (only on user actions).
- Improvement path: Maintain a dirty flag after grid mutations, recompute counts only when dirty. Store as a module-level table.

**`bags.update(dt)` calls `require("skill_tree")` on every frame on every screen:**
- Problem: `bags.update(dt)` at line 39 calls `require("skill_tree")` to get `getMaxQueuedFree()` and `getFreeBagInterval()`. Both screens call `bags.update(dt)` every frame. Lua's `require` is cached after the first load so it returns a table reference, not a full load — but the function call overhead adds up on low-performance targets.
- Files: `bags.lua:39-40`
- Cause: Values are queried dynamically instead of being cached at `bags.init()` time and invalidated when skill tree changes.
- Improvement path: Cache `max_free` and `interval` at init, refresh on skill tree unlock events.

---

## Fragile Areas

**Tutorial state machine in `arena_screen.lua` is a 200-line if-elseif chain with no data table:**
- Files: `arena_screen.lua:874-968`
- Why fragile: Adding a new step requires inserting a new `elseif` block and renumbering conceptually. Steps 6 and 7 share identical code. Steps 8 and 9 share identical code. The step numbers are referenced as magic integers spread across `drawTutorial()`, `drawStash()`, `drawOrdersStrip()`, and `advanceTutorial()` — a renumber in one place will not error, it will silently skip the highlight or guard.
- Safe modification: Always check all four draw functions and the input handler when editing a step. Add a comment mapping step numbers to human-readable names.
- Test coverage: No tests. The tutorial can only be exercised manually by resetting arena progression.

**`progression.mergeWithDefaults()` silently drops array-table keys if the loaded save uses numeric keys but the default uses sequential integer keys:**
- Files: `progression.lua:281-304`
- Why fragile: The function checks `#val > 0` to determine if a table is an "array". Lua's `#` operator on sparse tables (e.g., a grid save with gaps) returns an unpredictable result. The merge logic then treats it as a dict and recursively merges keys, potentially clobbering numeric grid indices with default values.
- Safe modification: Never rely on `mergeWithDefaults()` for tables that have numeric keys and may be sparse. Use explicit nil-guarded defaults in each accessor (e.g., `d.grid or {}`). The arena grid loader already does this correctly at `arena.lua:799-806`.

**`arena.findNearestEmpty()` BFS has no guard against the stash being counted as part of the grid:**
- Files: `arena.lua:187-209`
- Why fragile: The function searches the 56-cell grid array. If `GRID_SIZE` is ever changed or the stash is accidentally represented in the same index space, items could be placed off-grid silently.
- Safe modification: Grid and stash are separate Lua tables, so this is currently safe. But keep them structurally separate — do not merge them into a single flat array.

**`drops.rollMergeDrops()` reads an `avail` chest chain list and panics silently if empty:**
- Files: `drops.lua:85-96`
- Why fragile: If `st.isGeneratorUnlocked()` returns false for all 6 generator chains (impossible with `Ch` always unlocked via `GEN_NODE_MAP["Ch"] = nil`), `math.random(#avail)` would call `math.random(0)`, which throws an error in Lua.
- Safe modification: Add a guard `if #avail == 0 then return results end` before the random call. Currently safe due to Ch always being unlocked, but defensive coding prevents future breakage if the unlock logic changes.

**`arena_orders.advanceLevel()` returns `nil` after reaching level 10 but callers don't always guard:**
- Files: `arena_orders.lua:562-578`, `arena.lua:665-696`
- Why fragile: `arena.checkLevelComplete()` checks `if not result then return nil end` correctly. But `arena_screen.lua:1224` calls `arena.checkLevelComplete()` and checks `if level_result then` — the nil propagates correctly here. However, if `ORDER_LEVELS` were extended and `isLevelComplete()` returns true for level 11 (which has no data), `getVisibleOrders()` returns `{}` silently, causing a soft lock where the game shows no orders and the player cannot progress.
- Safe modification: Add an explicit max-level check in `getVisibleOrders()` that shows a "Season complete" state instead of an empty list.

---

## Scaling Limits

**Arena order system caps at 10 levels (Season 1 only):**
- Current capacity: 10 levels with 3–5 orders each.
- Limit: After level 10, `advanceLevel()` returns `nil`, the shuffle bag never refills with real order items, and `getVisibleOrders()` returns `{}`. The player has an infinite empty grid with working generators but no goals.
- Scaling path: Add a "Season 2" block to `ORDER_LEVELS` in `arena_orders.lua` or introduce a seasonal reset mechanic.

**`progression.dat` save format is human-readable serialized Lua with no versioning:**
- Current capacity: Works well for the current schema.
- Limit: Any schema change that removes or renames a top-level key will either be silently lost (removed field not in save) or incorrectly re-populated (renamed field gets old name from `mergeWithDefaults()`). There is no migration path for breaking changes.
- Scaling path: Add a `schema_version` integer to the save root. Add a migration function table keyed by version number.

---

## Dependencies at Risk

**`lldebugger.lua` is committed to the repository:**
- Risk: This is the Local Lua Debugger (1989 lines, ~81KB). It is loaded unconditionally via `conf.lua` when the `LOCAL_LUA_DEBUGGER_VSCODE` env var is set, and the error handler in `main.lua` checks for `_G.lldebugger`. On web builds, the env var is never set so it never activates, but it is still bundled in the build artifact, increasing download size.
- Impact: Larger web bundle. Potential issues if love.js sandbox restricts `debug.*` functions that lldebugger depends on.
- Migration plan: Move `lldebugger.lua` to a `.gitignore`d location or wrap it in a `#ifdef`-style conditional require that only bundles it in developer builds.

---

## Missing Critical Features

**No content after Arena level 10:**
- Problem: The game loop has no end-game or seasonal reset. Players who reach level 10 and complete all orders have a running arena with no goals.
- Blocks: Player retention beyond early-mid game.

**Double Merge power-up is awarded but never applied:**
- Problem: Players can accumulate `double_merge` charges from hard Arena orders, receive a notification, but the mechanic is entirely unimplemented in `coin_sort.lua` and `coin_sort_screen.lua`.
- Blocks: The power-up is part of the design doc but missing from the game.

**Yandex leaderboard and player data persistence APIs not integrated:**
- Problem: `yandex.lua` only wraps ad functions. Yandex Games SDK provides leaderboard, cloud saves, and player authentication, none of which are connected. Cloud saves would allow cross-device progression.
- Blocks: Platform-level features expected by Yandex Games store listing.

---

## Test Coverage Gaps

**No automated tests exist anywhere:**
- What's not tested: All game logic in `coin_sort.lua`, `arena.lua`, `arena_orders.lua`, `drops.lua`, `resources.lua`, `bags.lua`, `skill_tree.lua`, `progression.lua`. All animation sequencing in `animation.lua`. All serialization/deserialization in `progression.lua`.
- Files: Every `.lua` file in the project root.
- Risk: Balance regressions (wrong fuel amounts, wrong drop rates), save/load corruption, and tutorial soft-locks cannot be caught without manual playthrough.
- Priority: High for `progression.lua` (serialize/deserialize round-trip), `coin_sort.lua` (game-over detection, merge logic), `arena_orders.lua` (level completion gating), and `arena.lua` (BFS empty-cell finder, shuffle bag logic).

---

*Concerns audit: 2026-04-05*
