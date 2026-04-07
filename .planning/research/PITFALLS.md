# Domain Pitfalls

**Domain:** v1.0 release polish for LOVE2D/Lua merge puzzle game (web/WASM target)
**Researched:** 2026-04-05
**Confidence:** HIGH (based on codebase analysis + documented concerns + platform-specific research)

---

## Critical Pitfalls

Mistakes that cause rewrites, regressions, or ship-blocking bugs.

### Pitfall 1: Effects System Replacement Breaks the Working Merge/Deal Animation Pipeline

**What goes wrong:** The current particle system (`particles.lua`) is tightly coupled into `coin_sort_screen.lua` via 7+ call sites that pass it as a parameter to `animation.startMerge()`, `animation.startDealing()`, and direct `particles.spawn()`/`particles.spawnMergeExplosion()` calls. Replacing `particles.lua` with a new effects module that has a different API signature will silently break all these call sites. The animation module stores a runtime reference to the particles module (`particles_module`) passed at `startMerge()` time -- if the new module's `spawn()` / `spawnMergeExplosion()` signatures change, merges will error mid-animation and soft-lock the game.

**Why it happens:** The effects redesign is motivated by web performance problems with the current system. The temptation is to replace the whole module at once. But the current system is wired into both screens at the call-site level (not behind an abstraction), meaning a "swap" is actually a multi-file refactor touching `coin_sort_screen.lua` (1174 lines), `arena_screen.lua` (1437 lines), and `animation.lua` (894 lines) -- the three largest files in the project.

**Consequences:**
- Merge animations crash mid-sequence, leaving game state inconsistent (coins removed but merge product not added).
- Dealing animations fail, leaving coins in limbo (deducted from bag but not placed).
- Regression only visible during gameplay, not at load time.

**Prevention:**
1. Keep the existing `particles.lua` public API as the contract: `init()`, `spawn(x, y, color)`, `spawnMergeExplosion(x, y, color)`, `spawnSqueezeParticles(x, y, color, count)`, `update(dt)`, `draw()`, `getActiveCount()`.
2. Redesign the internals of `particles.lua` (pool strategy, rendering approach, effect types) but preserve these 7 function signatures exactly.
3. Add new effect types (button glow, star gains, chest opens) as NEW functions on the same module, not as a replacement module.
4. Test the merge/deal animation cycle end-to-end after any particle change before touching visual quality.

**Detection:** Merge button press produces no visual feedback or throws a Lua error. Dealing coins "vanish" (bag consumed, no coins appear).

**Phase relevance:** Must be addressed FIRST in the effects redesign phase. Establish API contract before any implementation work.

---

### Pitfall 2: Dead Code in `arena_chains.lua` Crashes on Dead Module Deletion

**What goes wrong:** `arena_chains.lua:286` calls `require("upgrades").getMaxCoinReached()` -- a live call into one of the 6 dead files from the scrapped classic mode. If the dead code cleanup phase deletes `upgrades.lua` before fixing this call site, every generator tap in the Arena that triggers `rollDrop()` quality bonus calculation will crash with `module 'upgrades' not found`. This is not a startup crash -- it only triggers during active gameplay when a generator produces items.

**Why it happens:** The dead code and the live call into it are in different files. A developer cleaning up dead files will grep for `require("upgrades")` but may see it's also referenced in `upgrades_screen.lua` and `currency.lua` (both dead) and assume all references are dead. The live reference in `arena_chains.lua` is buried in a function that runs conditionally (only when quality bonus chance is non-zero, which depends on `max_coin_reached >= 3`).

**Consequences:** Arena becomes unplayable after new players reach mid-game progression (when `max_coin_reached` crosses the quality bonus threshold). Early testing won't catch it because quality bonus is 0% at `mcr < 3`.

**Prevention:**
1. Fix the `arena_chains.lua:286` call BEFORE deleting any dead files. Replace with `progression.getUpgradesData().max_coin_reached` or better, expose `coin_sort.getMaxCoinReached()`.
2. Grep ALL live `.lua` files for `require("upgrades")`, `require("currency")`, `require("game")`, `require("game_screen")`, `require("emoji")` before deletion.
3. Test with a save file where `max_coin_reached >= 5` after deletion to trigger the quality bonus path.

**Detection:** Lua error on generator tap mentioning `upgrades` module. Only appears after player has merged L3+ coins in Coin Sort.

**Phase relevance:** Must be the FIRST task in any dead code cleanup. Do not batch it with other cleanup work.

---

### Pitfall 3: Spotlight Tutorial Blocks Game State Mutations It Does Not Expect

**What goes wrong:** A spotlight tutorial that dims the screen and restricts input to a single highlighted element must correctly handle ALL game state changes that can occur during the highlighted action. The existing Arena tutorial already demonstrates this failure: steps 6/7 share identical code because the player can merge onto a *different* sealed cell than intended, causing the state machine to get stuck (documented bug in CONCERNS.md). A new spotlight system with stricter input blocking risks making this WORSE -- if the spotlight forces the player toward a specific cell but the game state has already changed (e.g., the target cell was unsealed by an adjacent merge in a previous step), the tutorial deadlocks.

**Why it happens:** The tutorial state machine and the game state machine are independent. The tutorial tracks step numbers, the game tracks grid contents. Neither validates the other's assumptions. Steps assume specific board state (e.g., "there is a sealed Ch3 at this position") but don't verify it before showing the spotlight.

**Consequences:**
- Tutorial soft-locks requiring full progression reset.
- New players (the exact audience tutorials serve) hit a wall in the first 2 minutes.
- On web/Yandex, there's no convenient way to recover -- the F1 reset key is hidden and the 3-second hold button is only on the CS screen.

**Prevention:**
1. Each tutorial step must declare its preconditions as data (not assumptions): `{step=6, requires={cell_at={index=X, state="sealed", chain_id="Ch", level=3}}}`.
2. Before showing a spotlight, validate preconditions. If invalid, skip to the next step that has valid preconditions (or complete the tutorial).
3. Add a "skip tutorial" button accessible during any step -- essential for the web platform where users may refresh and re-encounter the tutorial.
4. The Coin Sort tutorial (new) should be designed with this pattern from the start, not retrofitted.

**Detection:** Player taps highlighted area but nothing happens. Tutorial tooltip stays on screen indefinitely.

**Phase relevance:** Affects both the CS tutorial (new) and Arena tutorial (rebuild). Design the precondition validation system before implementing either tutorial.

---

### Pitfall 4: Persistent Commissions Break the Save Schema Without Migration

**What goes wrong:** Current commissions are per-session (`commissions.generate()` on init, `commissions.clear()` on game over, no save/load). Making them persistent requires adding a `commissions_data` field to `progression.lua`'s save schema. The existing `mergeWithDefaults()` function (lines 281-304) has a documented fragility: it uses `#val > 0` to detect arrays, which produces unpredictable results on sparse tables. Commission data will include arrays (the active commissions list) with possible nil gaps if a commission is completed and removed mid-list. `mergeWithDefaults()` will misidentify these as dicts and recursively merge keys, corrupting the commission state.

**Why it happens:** `progression.lua` was designed for flat key-value data. The commission data structure includes nested arrays with mixed types (numbers, strings, booleans in each commission entry). The `mergeWithDefaults()` approach silently mangles data structures it doesn't understand, and there is no `schema_version` field to trigger proper migration.

**Consequences:**
- Existing saves load with corrupted or missing commission data -- commissions appear blank or with wrong progress values.
- No error is thrown; the corruption is silent. Players lose commission progress without knowing why.
- Since there's no schema version, there's no way to detect "this save predates persistent commissions" and initialize cleanly.

**Prevention:**
1. Add `schema_version = 1` to `progression.lua`'s default data BEFORE adding commission persistence.
2. Add a migration function table: `MIGRATIONS[2] = function(data) data.commissions_data = {active = {}, generation_seed = 0}; data.schema_version = 2; return data end`.
3. On load: if `data.schema_version < CURRENT_VERSION`, run migrations in sequence.
4. For commission data specifically, use explicit nil-guarded defaults in the commission accessor (pattern already used correctly by `arena.lua:799-806` for grid data) rather than relying on `mergeWithDefaults()`.
5. Store commissions as a flat serializable structure: `{active = {{type="forge", target_level=4, ...}, ...}, completed_ids = {}}` -- no sparse arrays.

**Detection:** After updating, commission UI shows "0/0" or wrong descriptions. Commission progress resets on every app restart despite being "persistent."

**Phase relevance:** Must be addressed BEFORE implementing persistent commissions. The schema migration system is a prerequisite, not an afterthought.

---

### Pitfall 5: Reward Popup Overlays Swallow Input on Both Screens Without a Modal Stack

**What goes wrong:** The game currently has ONE modal overlay: the fuel depletion panel in `arena_screen.lua`. It works by checking `fuel_overlay_shown` at the top of `mousepressed()` and returning early, consuming all clicks. Adding reward popups means multiple overlays can coexist (commission complete + level up + chest drop can all fire within the same user action). Without a proper modal stack, overlays fight over input priority, and the "tap to dismiss" on one popup accidentally dismisses another, or clicks fall through to the game grid behind the popup.

**Why it happens:** The immediate-mode UI pattern used throughout the game has no concept of z-order or input focus. Each screen's `mousepressed` is a flat function with priority determined by code order. Adding a second modal to the same function creates an implicit priority hierarchy that's fragile and hard to reason about.

**Consequences:**
- Player taps "Continue" on a reward popup and accidentally completes an arena order behind it.
- Multiple popups stack visually but only the last one receives input.
- On web with touch, the SDL+Emscripten double-fire issue (synthetic + real mouse event) can dismiss two popups with a single tap if the debounce window is shorter than the popup transition.

**Prevention:**
1. Implement a simple overlay stack (array of active overlays) checked at the TOP of each screen's `mousepressed`. If stack is non-empty, only the top overlay receives input; everything else is blocked.
2. Pattern: `if overlay_stack.handleInput(x, y) then return end` as the first line of every `mousepressed`.
3. Overlays push/pop from the stack, with automatic dimming of content behind them.
4. Ensure the existing touch debounce (0.2s in `main.lua`) applies to overlay dismissals too. Consider increasing to 0.3s for modal transitions.
5. Build the overlay stack as a shared module (like `tab_bar.lua`) usable by both screens, not as per-screen state.

**Detection:** Tapping a reward popup triggers a game action. Two popups appear simultaneously and only one can be dismissed. Arena drag starts "through" a popup overlay.

**Phase relevance:** The overlay/modal stack should be built as infrastructure in the first phase, before any feature that uses popups (reward popups, tutorials with overlays).

---

## Moderate Pitfalls

### Pitfall 6: `coin_sort_screen.lua` Crosses the Complexity Threshold During Tutorial Addition

**What goes wrong:** `coin_sort_screen.lua` is already 1174 lines -- the second-largest file. Adding a spotlight tutorial system (step definitions, precondition checks, overlay drawing, input interception, tooltip rendering) will push it well past 1500 lines. The CLAUDE.md project rule requires suggesting refactoring at 1500 lines. But refactoring mid-feature is risky -- it's better to plan the extraction before adding the tutorial.

**Prevention:**
1. Extract tutorial logic into a separate `coin_sort_tutorial.lua` module BEFORE implementing the tutorial steps.
2. The tutorial module should receive draw callbacks from the screen (for spotlighting specific elements) rather than reaching into the screen's internals.
3. Similarly, `arena_screen.lua` (1437 lines, nearly at the threshold) should have its tutorial code (currently ~200 lines of if-elseif chain at lines 874-968, plus `drawTutorial()` at lines 821-870, plus `TUTORIAL_TOOLTIPS` at lines 739-758) extracted into `arena_tutorial.lua` BEFORE the rebuild.

**Detection:** Files exceed 1500 lines. Tutorial bugs require reading 200+ lines of if-elseif chains.

**Phase relevance:** File extraction should happen in a prep/cleanup phase before tutorial implementation begins.

---

### Pitfall 7: Arena Tutorial Rebuild Loses Hard-Won Edge Case Handling

**What goes wrong:** The existing 18-step arena tutorial, despite its bugs, encodes important knowledge: hardcoded tutorial drops (Da1, Me1), dispenser push timing, order visibility gating (hidden before step 13), stash visibility gating (hidden before step 15). A "clean rewrite" risks losing these gating behaviors because they're scattered across `arena_screen.lua`'s `drawOrdersStrip()`, `drawStash()`, and `advanceTutorial()` -- not just in the tutorial drawing function.

**Why it happens:** The tutorial's behavior is not encapsulated. It's implemented as guard clauses (`if step < 13 then return end`) sprinkled across 4+ drawing functions and the input handler. A developer building the new spotlight tutorial will naturally focus on the `drawTutorial()` and `advanceTutorial()` functions, missing the guards elsewhere.

**Prevention:**
1. Before rewriting, catalog EVERY location in `arena_screen.lua` that checks `arena.getTutorialStep()`. Current locations:
   - `advanceTutorial()` (lines 874-968)
   - `drawTutorial()` (lines 821-870)
   - `drawOrdersStrip()` (order visibility gate)
   - `drawStash()` (stash visibility gate)
   - `arena_screen.mousepressed()` (order button gating)
   - `arena_screen.update()` (fuel overlay suppression during tutorial)
2. Document each guard's purpose in the new tutorial's step definition data.
3. The new system should have explicit `visibleSections` per step: `{step=6, visible={grid=true, orders=false, stash=false, dispenser=true}}`.

**Detection:** After tutorial rebuild, stash is visible from step 1 (should be hidden). Orders appear during merge introduction (should be hidden until step 13).

**Phase relevance:** The catalog of tutorial touchpoints must be created before the arena tutorial rebuild begins.

---

### Pitfall 8: Effects System Redesign Creates Per-Frame Object Allocation on WASM

**What goes wrong:** On desktop LOVE2D with LuaJIT, per-frame table allocation is nearly free (JIT-compiled allocation + generational GC). On web with Lua 5.1 via Emscripten, there is no JIT -- every table allocation goes through the interpreter, and GC pauses are more noticeable because the browser's event loop is single-threaded. A new effects system that creates particle tables per-frame (instead of reusing from a pool) will cause GC stutters visible as frame drops.

**Why it happens:** The current `particles.lua` correctly uses a pre-allocated pool of `MAX_PARTICLES` objects that are recycled via a free stack. A redesign might "simplify" this to dynamically create/destroy particle tables, which works fine on desktop but chokes on WASM where Lua 5.1's GC is the bottleneck.

**Consequences:** Consistent 3-5fps drops during merge explosions on web. GC pause visible as a "hitch" every 1-2 seconds during particle-heavy scenes. Players on lower-end devices (the Yandex Games audience) experience stuttering that desktop testing never reveals.

**Prevention:**
1. KEEP the pool-based allocation pattern from the current `particles.lua`. It's correct.
2. Pre-allocate all effect objects at `init()` time. No `{}` inside `update()` or `draw()` loops.
3. The `SpriteBatch` approach (single draw call for all particles) is also correct and must be preserved.
4. Profile on web EARLY: use the FPS counter (already displayed) plus `collectgarbage("count")` to monitor memory. A jump of >50KB/frame indicates per-frame allocation.
5. If adding new effect types (glow, trails), add them as additional pre-allocated pools, not as dynamic objects.

**Detection:** FPS drops specifically during merges on web. Desktop shows stable 60fps for the same scene. `collectgarbage("count")` increases monotonically between manual `collectgarbage()` calls.

**Phase relevance:** Establish the "no per-frame allocation" rule as a constraint before effects implementation begins. Review during code review.

---

### Pitfall 9: `progression.save()` Called on Every Interaction Compounds with New Features

**What goes wrong:** `arena.save()` is already called on every grid interaction (documented in CONCERNS.md, 13+ call sites). Adding reward popups (which modify drop state), persistent commissions (which modify commission state), and effects that trigger drops (chest opens) will each add MORE `progression.save()` calls. On web, each save serializes the entire data table and writes to LocalStorage -- a synchronous operation that blocks the main thread. With persistent commissions adding ~200 bytes per save and reward popup state adding another ~100 bytes, the already-bloated save (which includes stale classic-mode schema) becomes a performance bottleneck.

**Prevention:**
1. Implement the dirty-flag save batching recommended in CONCERNS.md BEFORE adding new features that trigger saves.
2. Pattern: `arena_dirty = true` on mutation, `arena.save()` only from `exit()`, `love.focus(false)`, `love.quit()`, and a 30-second periodic timer.
3. New features should set the dirty flag, never call `progression.save()` directly.
4. Clean up the stale schema from `progression.lua`'s `getDefaultData()` to reduce serialization payload.

**Detection:** Noticeable UI lag (100ms+) on every grid interaction on web. Worse on mobile web browsers with slow LocalStorage.

**Phase relevance:** Save batching should be implemented in the cleanup/prep phase before any new feature that adds save data.

---

### Pitfall 10: Commission UI Visible From Both Modes Requires Cross-Screen State Synchronization

**What goes wrong:** Currently, commissions are initialized in `coin_sort.lua` and displayed in `coin_sort_screen.lua`. Making them "visible from both modes" means `arena_screen.lua` also needs to read commission state. If the commission module is modified while on the Arena screen (e.g., a timer-based commission that ticks in `update()`), and the player switches to Coin Sort, the screen must reflect the current state without re-generating commissions. The existing `commissions.generate()` wipes all state and creates new commissions -- calling it on Coin Sort re-entry would destroy progress tracked while in Arena.

**Prevention:**
1. Commission lifecycle must be decoupled from screen lifecycle. `commissions.generate()` should only be called when starting a new commission period (e.g., on daily reset or explicit refresh), not on screen `enter()`.
2. Both screens should call `commissions.getActive()` for read access -- no generation or mutation on screen transitions.
3. Commission tracking callbacks (`commissions.onMerge()`) should be called from the game logic modules (`coin_sort.lua`), not from the screen modules. This is already the case for CS, but Arena has no commission tracking -- arena merges and order completions should also feed into commissions.
4. Persist commission state (including progress) alongside other save data. The commission module should have `sync()` and `init()` patterns matching `drops.lua`.

**Detection:** Switching from Arena to Coin Sort resets commission progress. Commission shown on Arena screen is stale (does not reflect progress made in CS).

**Phase relevance:** Commission persistence architecture must be designed before the cross-mode visibility feature.

---

### Pitfall 11: The `double_merge` Drop Type Becomes More Confusing After Adding Reward Popups

**What goes wrong:** `double_merge` is currently awarded by `drops.rollOrderDrops()` for hard orders, displayed as "+1 Double Merge!" notification in `arena_screen.lua:1217`, persisted in saves, but never consumed by `coin_sort.lua`. Adding reward popups will make this MORE visible to players (a shiny popup saying "Double Merge!") while still doing nothing. Players will actively search for how to use it and become frustrated.

**Prevention:** Either implement the mechanic before adding reward popups, or remove the drop type from tables before reward popups go live. Do not ship reward popups that celebrate a non-functional feature.

**Detection:** Players receive "Double Merge" reward popup but can find no way to use it. Support/review complaints.

**Phase relevance:** Must be resolved (implement or remove) in the prep/cleanup phase before reward popups are added.

---

## Minor Pitfalls

### Pitfall 12: Spotlight Tutorial Dimming Layer Interferes with Screen Shake

**What goes wrong:** The coin sort merge animation applies screen shake via `love.graphics.translate(animation.getScreenShake())`. A spotlight overlay drawn AFTER the shake translation will be offset by the shake amount, causing the dimming layer and spotlight cutout to jitter independently of the game content. The spotlight "window" will appear to vibrate while the highlighted element stays still (or vice versa).

**Prevention:** Draw the spotlight overlay INSIDE the same `push()`/`pop()` block as the game content, so shake applies to both uniformly. Or apply shake only to game elements, not overlays, by drawing the overlay after `love.graphics.pop()`.

**Detection:** During a merge with tutorial active, the spotlight cutout visibly jitters.

---

### Pitfall 13: `arena_orders.advanceLevel()` Static Table Mutation Hits Persistent Commission Rewards

**What goes wrong:** `arena_orders.advanceLevel()` at line 572 mutates the static `ORDER_LEVELS` table by writing `bag_reward` and `star_reward` directly onto it (documented bug in CONCERNS.md). If persistent commissions reference order rewards for their reward calculation, and the player reaches level 10 and resets, the static reward values from the first run persist in memory, yielding incorrect commission rewards on subsequent playthroughs.

**Prevention:** Fix the static table mutation bug before building any feature that reads order reward data. Copy the level data table before writing to it: `local rewards = {}; for k, v in pairs(level_data.level_rewards) do rewards[k] = v end`.

**Detection:** After progression reset, level 1 order rewards show incorrect values.

---

### Pitfall 14: The Duplicate `coin_sort.merge()` Function Becomes a Divergence Risk During Commission Tracking

**What goes wrong:** `coin_sort.merge()` (lines 612-683) duplicates `executeMergeOnBox()` (lines 556-607). When adding commission tracking to merges (for persistent commissions), the change must be applied to `executeMergeOnBox()` (the live path). If a developer also adds it to `merge()` (the dead path), any future accidental call to `merge()` would double-count commission progress. If they don't add it to `merge()`, the dead function silently drifts further.

**Prevention:** Delete `coin_sort.merge()` in the cleanup phase. Grep confirms no callers exist outside the function itself.

**Detection:** Commission progress counts are double or inconsistent with actual merge count.

---

### Pitfall 15: Web Touch Debounce Window Causes Popup Double-Dismiss

**What goes wrong:** The `main.lua` touch debounce (0.2s) prevents double-fire of game inputs, but popup dismiss actions fire their own state change (remove popup from stack) synchronously. If two popups are queued (e.g., "Level Up!" followed by "Commission Complete!"), a single touch on web can dismiss the first popup, the second appears in the same frame, and the synthetic mouse event (arriving within the 0.2s debounce window but after the first popup is gone) dismisses the second popup too -- because the debounce only blocks events with `istouch` mismatches, not rapid sequential events of the same type.

**Prevention:** Popup transitions should have a minimum display time (e.g., 0.3s) before they accept dismiss input. The overlay stack should not process input on the same frame a new overlay is pushed.

**Detection:** Multiple reward popups flash by too quickly to read on web/mobile.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Dead code cleanup | `arena_chains.lua:286` crashes if `upgrades.lua` deleted first | Fix the live `require("upgrades")` call BEFORE deleting dead files |
| Dead code cleanup | `coin_sort.merge()` duplicate stays, drifts further | Delete confirmed-dead `merge()` function during cleanup |
| Dead code cleanup | `double_merge` drop type still awarded | Decide: implement or remove. Do not leave as-is before popups |
| Progression schema | `mergeWithDefaults()` corrupts array data | Add `schema_version`, use explicit nil-guards, not recursive merge |
| Save optimization | `progression.save()` on every interaction, worse with new features | Implement dirty-flag batching before adding persistent commissions |
| Effects redesign | API change breaks merge/deal animation pipeline | Preserve existing `particles.lua` public API signatures exactly |
| Effects redesign | Per-frame allocation causes GC stutter on WASM | Keep pool-based allocation, no `{}` in update/draw loops |
| CS tutorial (new) | `coin_sort_screen.lua` exceeds 1500 lines | Extract tutorial into `coin_sort_tutorial.lua` before implementation |
| Arena tutorial rebuild | Scattered guard clauses for step-based visibility lost | Catalog all `getTutorialStep()` check sites before rewriting |
| Arena tutorial rebuild | Step preconditions assume board state, cause soft-locks | Validate preconditions per step; add skip button |
| Persistent commissions | `commissions.generate()` wipes state on screen enter | Decouple commission lifecycle from screen lifecycle |
| Persistent commissions | Cross-mode visibility needs both screens to read same state | Design shared read-only access pattern before implementation |
| Reward popups | Multiple overlays fight for input | Build modal/overlay stack as shared infrastructure first |
| Reward popups | Touch debounce causes double-dismiss | Add minimum display time, block input on push frame |
| Reward popups | `double_merge` popup celebrates non-functional feature | Resolve `double_merge` before shipping popups |

---

## Sources

- Codebase analysis: `/home/username/Documents/Coins-Boxes/.planning/codebase/CONCERNS.md` (HIGH confidence -- direct code audit)
- Codebase analysis: `particles.lua`, `animation.lua`, `coin_sort_screen.lua`, `arena_screen.lua`, `commissions.lua`, `progression.lua`, `drops.lua`, `arena_chains.lua` (HIGH confidence -- direct code inspection)
- [How I learned to love.js again](https://pagefault.se/post/how-i-learned-to-love-js-again/) -- LOVE2D web/Emscripten pitfalls (MEDIUM confidence)
- [Emscripten WebGL memory leak issue #13697](https://github.com/emscripten-core/emscripten/issues/13697) -- WebGL uniform location leak (MEDIUM confidence)
- [LOVE2D SpriteBatch performance forum thread](https://love2d.org/forums/viewtopic.php?t=78271) -- SpriteBatch vs individual draw calls (MEDIUM confidence)
- [LOVE2D performance optimization tips](https://love2d.org/forums/viewtopic.php?t=91369) -- General LOVE2D rendering optimization (MEDIUM confidence)
- [LOVE Web Builder](https://schellingb.github.io/LoveWebBuilder/) -- Lua 5.1 (no goto, no LuaJIT) constraint confirmation (MEDIUM confidence)
- [Factorio Lua Migrations](https://lua-api.factorio.com/1.1.70/Migrations.html) -- Save migration pattern reference (MEDIUM confidence)

---

*Pitfalls audit: 2026-04-05*
