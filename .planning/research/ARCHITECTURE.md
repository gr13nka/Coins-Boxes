# Architecture Patterns

**Domain:** v1.0 Release Polish features for LOVE2D/Lua merge puzzle game
**Researched:** 2026-04-05

## Recommended Architecture

Four new features -- effects system redesign, spotlight tutorials, persistent commissions, and reward popups -- integrate into the existing module-per-concern architecture. The key principle: **each new feature follows the existing logic/visual split**, introducing new modules where responsibility is genuinely new, and modifying existing modules only at well-defined hook points.

### High-Level Integration Map

```
                     main.lua
                       |
              screens.lua (delegates)
               /       |       \
  coin_sort_screen  arena_screen  game_over_screen
       |     |          |     |        |
       |  [NEW: spotlight.lua - overlay drawing + input gating]
       |     |          |     |
       |  [NEW: popups.lua - modal queue + drawing]
       |     |          |     |
  coin_sort  arena    commissions (MODIFIED: persistence)
       |     |          |
  [NEW: effects.lua - unified VFX pipeline]
       |     |
  particles  animation  (MODIFIED: effects integration)
       |
  progression.lua (MODIFIED: commissions_data slice)
```

### New Modules (4)

| Module | Type | Role | Depends On | Used By |
|--------|------|------|-----------|---------|
| `effects.lua` | Rendering helper | Unified VFX pipeline: screen-space effects (flashes, glows, trails, number fly-ups). Replaces ad-hoc `resource_popups` in CS screen and `slot_tweens` in arena screen with a centralized, pooled system. | `layout.lua`, `mobile.lua` | `coin_sort_screen.lua`, `arena_screen.lua`, `game_over_screen.lua` |
| `spotlight.lua` | Rendering helper | Spotlight tutorial overlay: draws dimmed background with cutout holes, tooltip text, input gating. Stateless renderer -- the tutorial *state machine* lives in the screen modules (or a new `cs_tutorial.lua` data module). | `layout.lua` | `coin_sort_screen.lua`, `arena_screen.lua` |
| `popups.lua` | UI component | Modal reward popup queue: FIFO queue of popup descriptors, draws one at a time over everything (like `drawFuelDepletionOverlay` but generalized), consumes taps to dismiss. | `layout.lua`, `sound.lua` | `coin_sort_screen.lua`, `arena_screen.lua`, `game_over_screen.lua` |
| `cs_tutorial.lua` | Logic (pure data) | Coin Sort tutorial state machine: step definitions, advancement rules, completion tracking. Mirrors how arena tutorial state lives in `arena.lua` but for CS. | `progression.lua`, `coin_sort.lua` | `coin_sort_screen.lua` |

### Modified Modules (7)

| Module | What Changes | Why |
|--------|-------------|-----|
| `commissions.lua` | Add `init()` loading from progression, `save()`/`sync()`, cross-session persistence, refresh logic (timer or level-based instead of per-game). Remove `clear()` on game over -- commissions survive sessions. | Currently ephemeral (regenerated each `coin_sort.init()`). Persistence requires save/load cycle. |
| `progression.lua` | Add `commissions_data` slice to `getDefaultData()`, add `getCommissionsData()`/`setCommissionsData()` accessors. Add `cs_tutorial_step` field to `coin_sort_data`. | New persistent data for commissions and CS tutorial progress. |
| `coin_sort_screen.lua` | (1) Replace `resource_popups` with `effects.spawnFlyUp()`. (2) Add spotlight overlay calls to `draw()`. (3) Add input gating in `mousepressed()` when spotlight active. (4) Draw commission panel from both modes (move to shared or keep in-screen). (5) Wire `popups.draw()` and `popups.mousepressed()`. | Screen is the integration surface for 3 of 4 new features. |
| `arena_screen.lua` | (1) Replace `slot_tweens`, `gen_fly`, `notifications` with effects system equivalents. (2) Rebuild `drawTutorial()` + `advanceTutorial()` to use `spotlight.lua` for rendering. Tutorial state machine stays here (or moves to `arena.lua`). (3) Wire `popups.draw()` and `popups.mousepressed()`. (4) Replace inline order-complete notification block with `popups.show()` for big moments. | Same integration surface. The 18-step tutorial rendering moves from inline rectangles to spotlight cutouts. |
| `particles.lua` | Likely *replaced* or heavily refactored into the new `effects.lua`. If kept separate, its `init()`/`update()`/`draw()` API stays the same but internal pool may be unified with effects. | Current system is the web performance bottleneck. Redesign is the whole point of the effects milestone. |
| `game_over_screen.lua` | Wire `popups.draw()`. Commission rewards displayed via popup instead of (or in addition to) static text. | Reward popups should fire on game over for commission completions. |
| `main.lua` | `require("effects")`, `require("popups")`, `require("cs_tutorial")`. Call `effects.init()` and `popups.init()` in `love.load()`. | Registration of new modules in the init chain. |

### Unchanged Modules

Everything else stays untouched: `animation.lua`, `graphics.lua`, `layout.lua`, `input.lua`, `tab_bar.lua`, `resources.lua`, `bags.lua`, `drops.lua`, `powerups.lua`, `skill_tree.lua`, `arena_chains.lua`, `arena_orders.lua`, `sound.lua`, `coin_utils.lua`, `utils.lua`, `mobile.lua`, `yandex.lua`, `screens.lua`.

The animation system (`animation.lua`) in particular does NOT change. Its dual-track state machine for pick/place and merge/deal is independent of visual effects. The new `effects.lua` handles *decorative* VFX (particles, glows, fly-ups) while animation handles *functional* movement (coin arcs, merge slides, dealing).

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `effects.lua` | Pooled screen-space VFX: spawn, update, draw. Types: fly-up text, burst particles, glow rings, trails. Performance-budgeted for web. | Called by screen modules. No callbacks -- fire-and-forget. |
| `spotlight.lua` | Render a dimmed overlay with rectangular/circular cutouts. Show tooltip text anchored to cutout. Report whether a tap is inside or outside the spotlight region. | Called by screen modules in `draw()` and queried in `mousepressed()`. |
| `popups.lua` | Maintain a FIFO queue of modal popups. Draw the front popup with enter/exit animation. Consume dismiss taps. Call a `onDismiss` callback when dismissed. | Called by screen modules. Screens push popups via `popups.show({...})`. |
| `cs_tutorial.lua` | Track CS tutorial step (integer). Define step configs: which element to spotlight, tooltip text, advancement condition. Persist step to progression. | Read by `coin_sort_screen.lua` for spotlight config. Advanced by CS screen on player actions. Reads `coin_sort.lua` state. |
| `commissions.lua` (modified) | Generate, track, complete, persist commissions. Refresh on a timer or when all complete (not per-game). Queryable from both screens. | `coin_sort_screen.lua` and `arena_screen.lua` both call `commissions.getActive()` to draw. `coin_sort.lua` calls `commissions.onMerge()`. `commissions.sync()` called in save batches. |

## Data Flow

### Effects System

```
Game event (merge, deal, chest open, star gain)
  -> Screen module calls effects.spawn{type, x, y, color, ...}
  -> effects.update(dt) ticks all active effects
  -> effects.draw() renders via SpriteBatch or simple geometry
  -> Effect expires -> returned to pool
```

No callbacks. No state mutation. Pure visual decoration. The key constraint: `effects.update(dt)` and `effects.draw()` must be called from whichever screen is active, just like `particles.update(dt)` and `particles.draw()` are called today.

**Performance budget:** effects.lua replaces particles.lua as the unified VFX system. The pool size, particle counts, and lifetime caps must be tuned for `mobile.isLowPerformance()` (web/WASM). Target: max 100 active effect instances on web, 200 on desktop. Single SpriteBatch draw call for all particle-type effects; simple `love.graphics` calls for geometric effects (glows, rings).

### Spotlight Tutorial

```
Screen enter()
  -> cs_tutorial.getStep() returns step config {target_rect, tooltip, advance_on}
  -> Screen stores spotlight config in local state

Screen draw()
  -> ... draw game content ...
  -> spotlight.draw(config) renders overlay + cutout + tooltip (drawn ABOVE game, BELOW popups)

Screen mousepressed(x, y)
  -> IF spotlight active:
       spotlight.isInCutout(x, y, config)?
         YES -> handle normally (the allowed interaction)
         NO  -> block input (dim flash or ignore)
       RETURN (don't process further)
  -> ELSE normal input handling

Game action triggers advancement
  -> cs_tutorial.advance() -> checks condition -> moves to next step
  -> If step == "done", spotlight config becomes nil
```

The spotlight overlay does NOT own the tutorial state machine. It is a pure renderer. This keeps the logic/visual split clean: `cs_tutorial.lua` (data) knows *what* to spotlight and *when* to advance; `spotlight.lua` (rendering) knows *how* to draw a dimmed overlay with holes.

For **Arena tutorial rebuild**: the existing `advanceTutorial()` function and `drawTutorial()` function in `arena_screen.lua` get rewritten to use `spotlight.lua` for rendering. The state machine (steps 1-18) stays in `arena_screen.lua` or moves to `arena.lua` (where `tutorial_step` already lives). The 18-step logic does not change fundamentally -- only the visual presentation shifts from "highlight rectangles" to "dimmed overlay with cutout holes."

### Persistent Commissions

```
App start
  -> progression.load() includes commissions_data
  -> commissions.init() restores active commissions from save

Coin Sort merge
  -> commissions.onMerge(level, gained) -- same as today

Commission completed
  -> commissions.onComplete(index) marks it done
  -> popups.show({type="commission", ...}) queues a reward popup
  -> rewards applied immediately (bags, stars)

All commissions done (or refresh timer expires)
  -> commissions.refresh() generates new set
  -> commissions.sync() + progression.save()

Either screen draws commissions:
  -> commissions.getActive() returns the shared list
  -> Screen draws the commission panel (or a shared drawCommissions() helper)

Save batching:
  -> commissions.sync() added to arena.save() batch alongside bags.sync(), resources.sync(), drops.sync()
  -> coin_sort.save() also calls commissions.sync()
```

**Cross-screen visibility:** Both `coin_sort_screen.lua` and `arena_screen.lua` draw the commission panel. The `drawCommissions()` function currently lives inside `coin_sort_screen.lua` as a local function. Two options:
1. **Move to a shared helper** (e.g., `commissions_ui.lua`) -- violates the "no drawing in logic modules" rule unless it's explicitly a UI helper.
2. **Duplicate the draw code** in both screens -- keeps each screen self-contained but duplicates ~40 lines.

**Recommendation:** Option 2 (duplicate). The commission panel is simple (a few rectangles and text). Each screen has different Y positioning anyway. Copy the draw logic into both screens. The data comes from the shared `commissions.getActive()` call.

### Reward Popups

```
Big moment occurs (order complete, level up, commission done, first high-level merge)
  -> Screen calls popups.show({
       title = "Order Complete!",
       rewards = {{type="bags", amount=2}, {type="stars", amount=5}},
       onDismiss = function() ... end
     })

popups.update(dt)
  -> Animates enter/exit of front popup

popups.draw()
  -> Draws dimmed background + centered card with rewards
  -> Drawn LAST in screen draw() (above everything including spotlight)

popups.mousepressed(x, y)
  -> If popup visible, consume the tap (dismiss current popup)
  -> Return true if consumed (screen skips its own input)

Screen mousepressed(x, y)
  -> if popups.mousepressed(x, y) then return end  -- popup ate the tap
  -> ... normal input ...
```

**Popup queue is global, not per-screen.** The `popups.lua` module maintains a single queue. When screens switch, pending popups carry over. This means a popup triggered in Arena (e.g., level up) that hasn't been dismissed will still show if the player switches to Coin Sort. This is intentional -- reward popups should not be lost.

**Popup vs notification:** The existing `showNotification()` in arena_screen is a non-blocking slide-in toast. Popups are *modal* -- they block interaction until dismissed. Use popups for big moments (level up, commission complete, first chest earned). Use notifications (or effects fly-ups) for small moments (fuel +1, star +2).

## Patterns to Follow

### Pattern 1: Fire-and-Forget VFX

**What:** Screen modules call `effects.spawn()` and never check the result. Effects manage their own lifecycle.
**When:** Any visual feedback moment (merge, deal, chest open, button press).
**Example:**
```lua
-- In coin_sort_screen.lua, after merge
local reward = resources.onCoinMerge(new_level)
if reward.fuel > 0 then
  effects.spawnFlyUp(merge_x, merge_y, "+" .. reward.fuel .. " Fuel", {1, 0.8, 0.2})
end
if reward.stars > 0 then
  effects.spawnFlyUp(merge_x, merge_y - 30, "+" .. reward.stars .. " Stars", {0.95, 0.85, 0.25})
end
effects.spawnBurst(merge_x, merge_y, coin_color, 12) -- replaces particles.spawnMergeExplosion
```

### Pattern 2: Overlay Drawing Order

**What:** Strict z-order in every screen's `draw()` function.
**When:** Always. All screens must follow this order.
**Example:**
```lua
function screen.draw()
  -- 1. Background + game content
  drawBackground()
  drawGrid()
  drawCoins()

  -- 2. Effects (screen-space VFX, above game content)
  effects.draw()

  -- 3. HUD (resource bars, commission panel)
  drawResourceHUD()
  drawCommissions()

  -- 4. Spotlight tutorial overlay (dims everything below, cuts holes)
  if tutorial_active then
    spotlight.draw(tutorial_config)
  end

  -- 5. Modal popup (above everything, blocks interaction)
  popups.draw()

  -- 6. Tab bar (always on top)
  tab_bar.draw(active_tab)
end
```

### Pattern 3: Input Priority Chain

**What:** Each overlay layer gets first chance to consume input, top-down.
**When:** Every `mousepressed` handler.
**Example:**
```lua
function screen.mousepressed(x, y, button)
  if button ~= 1 then return end

  -- 1. Popup eats input first
  if popups.mousepressed(x, y) then return end

  -- 2. Spotlight gates input second
  if tutorial_active then
    if spotlight.isInCutout(x, y, tutorial_config) then
      -- Allow this specific interaction
    else
      return -- Block everything outside the spotlight
    end
  end

  -- 3. Normal input handling
  tab_bar.mousepressed(x, y)
  -- ... grid clicks, button clicks, etc.
end
```

### Pattern 4: Pooled Effect System

**What:** Pre-allocate a fixed-size pool of effect slots. Reuse dead slots. Never allocate during gameplay.
**When:** `effects.init()` pre-allocates; `effects.spawn()` grabs from free list.
**Example:**
```lua
local MAX_EFFECTS = mobile.isLowPerformance() and 100 or 200
local pool = {}
local active_count = 0

function effects.init()
  for i = 1, MAX_EFFECTS do
    pool[i] = {active = false, type = "", x = 0, y = 0, ...}
  end
end

function effects.spawn(config)
  -- Find free slot (or steal oldest active)
  local slot = getFreeSlot()
  slot.active = true
  slot.type = config.type
  slot.x = config.x
  -- ... setup from config ...
end
```

This mirrors the existing `particles.lua` pattern (active-list pool + SpriteBatch) but extends it to handle multiple effect types (particles, fly-ups, glows) in a single pool.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Effects Module with Game Logic

**What:** Putting game state mutation inside `effects.lua` (e.g., "when the fly-up finishes, add the fuel").
**Why bad:** Breaks the logic/visual separation. If effects are skipped on low-perf devices, the fuel never gets added.
**Instead:** Apply state changes immediately in the logic module. Spawn the effect purely for visual feedback. The effect is decorative, not functional.

### Anti-Pattern 2: Tutorial State in the Spotlight Renderer

**What:** Having `spotlight.lua` track which tutorial step the player is on, or decide when to advance.
**Why bad:** Mixes rendering (how to draw the overlay) with game logic (what step comes next). Makes it impossible to reuse spotlight for other purposes (e.g., highlighting a feature callout).
**Instead:** Tutorial state machine lives in `cs_tutorial.lua` (for Coin Sort) or `arena.lua`/`arena_screen.lua` (for Arena). Spotlight is a stateless draw helper.

### Anti-Pattern 3: Per-Screen Popup Systems

**What:** Each screen module maintaining its own popup queue and drawing code.
**Why bad:** Duplicates the popup UI, animation, and input blocking logic in 3+ places. Popups get lost on screen switch.
**Instead:** Single `popups.lua` module with one queue. All screens call `popups.draw()` and `popups.mousepressed()`.

### Anti-Pattern 4: Commissions Drawing in the Logic Module

**What:** Adding a `commissions.draw()` function to `commissions.lua`.
**Why bad:** Violates the hard logic/visual split. `commissions.lua` is a pure data module -- adding drawing code to it would be the first breach of this pattern and sets a bad precedent.
**Instead:** Each screen that shows commissions has its own draw function that reads from `commissions.getActive()`.

### Anti-Pattern 5: Stencil-Based Spotlight on Web

**What:** Using LOVE2D's stencil buffer for the spotlight cutout mask.
**Why bad:** Stencil operations have inconsistent support across WebGL implementations (particularly on mobile WebGL via Emscripten). Can cause visual artifacts or performance issues.
**Instead:** Draw the dimmed overlay as 4 rectangles around the cutout region (top, bottom, left, right), or render to a canvas with a cleared rectangle. Simpler, more portable, faster.

## Build Order (Dependency-Driven)

The four features have specific dependencies between them. Build order matters.

```
Phase 1: effects.lua
  |  (no dependencies on other new modules)
  |  Enables: visual polish in all subsequent phases
  v
Phase 2: popups.lua
  |  (depends on effects for popup enter/exit animations, optional)
  |  Enables: reward display for commissions and tutorials
  v
Phase 3: commissions.lua persistence + cross-screen visibility
  |  (depends on popups for completion rewards)
  |  Can be built independently of tutorials
  v
Phase 4a: spotlight.lua
  |  (depends on effects for highlight animations, optional)
  |  Enables: tutorial systems
  v
Phase 4b: cs_tutorial.lua + arena tutorial rebuild
  |  (depends on spotlight for rendering)
  |  (depends on popups for tutorial completion celebration)
```

**Rationale for this order:**
1. **Effects first** because every other feature benefits from it. Popups use effects for entrance animations. Tutorials use effects for highlight pulses. Commissions use effects for completion celebrations. Building effects first means the other features look polished from the start.
2. **Popups second** because they are a simple, self-contained UI component. Once built, both commissions and tutorials can fire popups for rewards and celebrations.
3. **Commissions third** because it is the simplest data change (adding persistence to an existing module) and does not depend on spotlight/tutorials at all.
4. **Spotlight + tutorials last** because they are the most complex integration (input gating, state machines, cross-module coordination) and benefit from having effects and popups already available.

Phases 3 and 4a can run in parallel since they have no mutual dependency.

## Scalability Considerations

| Concern | Current (web) | After Redesign | Notes |
|---------|---------------|----------------|-------|
| Particle count | 75 max (web) | 100 max (unified effects pool) | Single pool covers particles + fly-ups + glows |
| Draw calls for VFX | 1 (SpriteBatch) | 1-2 (SpriteBatch + geometry batch) | Geometric effects (glow rings) may need a second batch |
| Popup rendering | N/A | 1 popup at a time, simple geometry | Negligible perf impact |
| Spotlight rendering | N/A | 4 rectangles + text | Cheaper than stencil approach |
| Commission state | ~2 objects in memory | ~2-4 objects + save data | Negligible |
| Tutorial state | 1 integer (arena) | 2 integers (arena + CS) | Negligible |

## Sources

- Direct codebase analysis of all `.lua` files in the project root
- Existing architecture documented in `.planning/codebase/ARCHITECTURE.md`
- Existing structure documented in `.planning/codebase/STRUCTURE.md`
- LOVE2D 12.0 API (canvas, SpriteBatch, stencil behavior on web): based on framework knowledge, with LOW confidence on stencil WebGL specifics -- recommend testing stencil approach before committing to rectangle-based alternative

---

*Architecture analysis: 2026-04-05*
