# Phase 4: Spotlight Tutorials — Research

**Researched:** 2026-04-07
**Domain:** LOVE2D overlay/stencil rendering + tutorial state machine design
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Dark overlay with rounded-rectangle cutout matching target element bounds + small padding. No stencils exist in codebase — this is new rendering territory (canvas-based approach or stencil).
**D-02:** Overlay opacity ~60% black. Game grid/layout remains partially visible for spatial context.
**D-03:** Cutout edge has an animated pulse border — brightness oscillates gently.
**D-04:** Spotlight transitions between targets use smooth slide animation (~0.3s).
**D-05:** Full 3×5 grid with pre-set coins (not random deal). Board state hand-crafted by tutorial script.
**D-06:** CS 5-step sequence: 1) Tap box to pick coins, 2) Tap another box to place, 3) Press Merge button, 4) Tap bag to deal, 5) Free play.
**D-07:** Steps 1–2 fill a box that step 3 acts on. Pre-set board has a near-full box so pick/place completes it.
**D-08:** Arena tutorial is a complete redesign, NOT a 1:1 rebuild.
**D-09:** Essential concepts: dispenser tap, merge same items, sealed cells + box reveals, generator tap (costs fuel), orders, stash. Each gets 1–2 steps.
**D-10:** Keep current initial board layout (7×8 with boxes, sealed, 2 empty cells).
**D-11:** Keep existing hardcoded tutorial drops (Da1 Egg, Me1 Smoked Meat).
**D-12:** Old 18-step tutorial state machine removed completely. Clean break, no dead code.
**D-13:** Hand icon (pointing hand style) + minimal text label. Visual-first.
**D-14:** Animated tap motion for tap steps (~1.5s repeat). Animated drag trail for drag steps.
**D-15:** Instruction text auto-positions above/below spotlight, whichever has more space.
**D-16:** Tutorial text supports Russian + English. Strings in a localizable structure.
**D-17:** Each tutorial step validates board state preconditions before proceeding (TUT-04).

### Claude's Discretion

- Exact pre-set coin layout for CS tutorial board
- Stencil vs canvas approach for spotlight cutout rendering
- Exact step count for Arena tutorial (within 6–8 range)
- Step ordering for Arena tutorial concepts
- Pulse border timing/color
- Hand icon exact animation curves and timing
- Board state validation strategy (what preconditions per step, how to recover)
- Localization string format (table structure in Lua)
- Tutorial persistence format in progression.dat

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TUT-01 | Spotlight overlay system — blacked screen with lit interaction zone, input blocked outside zone | Stencil API verified in STACK.md; exact rendering pattern documented below |
| TUT-02 | Coin Sort tutorial — pick, place, merge, deal sequence (~5 steps, no skip) | Pre-set board design and step triggers documented; CS screen integration points identified |
| TUT-03 | Arena tutorial rebuilt in spotlight style — replacing current 18-step state machine | Full scope of deletion catalogued; 7-step redesign outlined; integration points confirmed |
| TUT-04 | Board state validation per tutorial step — preconditions checked to prevent soft-locks | Precondition strategy and recovery pattern documented |
</phase_requirements>

---

## Summary

Phase 4 builds a reusable spotlight overlay system and two guided tutorials (Coin Sort 5 steps, Arena ~7 steps). The rendering technology is settled from prior research: `love.graphics.setStencilMode("draw"/"test")` in LOVE 12.0 punches the cutout hole with no additional canvas. The module architecture is also settled: `tutorial.lua` (currently a placeholder) becomes the logic/data module; screen modules handle rendering and input filtering via calls to `tutorial.*`.

The primary complexity is threefold: (1) the spotlight animation state (cutout position, pulse timer, hand icon animation, slide transition); (2) the CS tutorial pre-set board design — a hand-crafted initial state that guarantees the pick→place→fill→merge chain works; (3) removing the existing 18-step arena tutorial cleanly without leaving dead code. The old `arena.lua` tutorial variables, `advanceTutorial()` in `arena_screen.lua`, and the dispenser-seeding logic in `arena_screen.enter()` are all going away and must be accounted for.

Persistence is a single new `tutorial_data` key in `progression.dat` (same schema as existing keys), tracking which tutorials are completed. The localization structure is a simple two-key Lua table (`{en = "...", ru = "..."}`) resolved at draw time via a `tutorial.lang` setting.

**Primary recommendation:** Implement `tutorial.lua` as a pure logic/data module. Split rendering across `coin_sort_screen.lua` and `arena_screen.lua`. Draw the spotlight overlay in those screens' `draw()` calls after all game content but before popups. Filter input at the top of each screen's `mousepressed()` using `tutorial.isInputBlocked(x, y)`.

---

## Standard Stack

### Core

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| `love.graphics.setStencilMode` | LOVE 12.0 | Spotlight cutout masking | Replaces deprecated callback-based stencil API. Hardware-accelerated, zero shader overhead. WebGL2 spec guarantees 8-bit stencil buffer. [VERIFIED: .planning/research/STACK.md] |
| `love.graphics.rectangle` (rounded) | LOVE 12.0 | All overlay shapes, hand icon, text backgrounds | Already used throughout codebase. `rectangle("fill", x, y, w, h, rx, ry)` for rounded corners. [VERIFIED: codebase grep] |
| Existing `progression.lua` serialization | Lua 5.x | Tutorial completion persistence | Same pattern as `drops_data`, `bags_data`, `arena_data`. No new tech. [VERIFIED: progression.lua lines 74–159] |
| Inline easing functions | Lua | Spotlight slide + pulse animations | Pattern already in `popups.lua`, `effects.lua`, `arena_screen.lua`. No tween library. [VERIFIED: codebase] |

### Fallback (if stencil fails on web)

| Approach | Description | When to Activate |
|----------|-------------|-----------------|
| Four-rectangle masking | Draw top/bottom/left/right dark strips around the spotlight rect | If `setStencilMode` throws on web build during testing |
| Canvas punch-hole | `love.graphics.newCanvas` + `setBlendMode("replace")` | If stencil AND 4-rect both insufficient (unlikely) |

[VERIFIED: .planning/research/STACK.md — fallback techniques documented]

**Installation:** No new dependencies. All features use LOVE 12.0 built-in APIs.

---

## Architecture Patterns

### Module Structure

```
tutorial.lua            -- Logic/data (no drawing). Manages step state, localization, validation.
coin_sort_screen.lua    -- Calls tutorial.* for CS tutorial; draws overlay; filters input.
arena_screen.lua        -- Calls tutorial.* for Arena tutorial; draws overlay; filters input.
progression.lua         -- Stores tutorial_data (cs_done, arena_done) in progression.dat.
```

`tutorial.lua` owns:
- Active tutorial id (`nil`, `"coin_sort"`, `"arena"`)
- Current step index
- Spotlight target rect `{x, y, w, h}` (current and previous for slide interpolation)
- Spotlight transition timer
- Pulse animation timer
- Hand icon animation state
- Localized string table lookup
- `tutorial.isInputBlocked(gx, gy)` — returns true if point is outside current spotlight rect
- `tutorial.advance()` — moves to next step, triggers slide transition
- `tutorial.isDone()` — returns true when current tutorial is complete
- `tutorial.getSpotlight()` — returns interpolated rect for this frame
- `tutorial.getText()` — returns localized string for current step

Screen modules own:
- Drawing the stencil overlay using data from `tutorial.getSpotlight()`
- Drawing the pulse border, hand icon, instruction text
- Calling `tutorial.isInputBlocked()` at the top of `mousepressed()`
- Calling `tutorial.advance()` after the required action is completed
- Calling `tutorial.update(dt)` from `screen.update(dt)`

### Pattern 1: Stencil Spotlight Rendering

```lua
-- Source: .planning/research/STACK.md (verified against LOVE 12.0 source)
local function drawSpotlightOverlay(rect, opacity, pulse_t)
    local x, y, w, h = rect.x, rect.y, rect.w, rect.h
    local r = 12  -- corner radius for rounded-rect cutout

    -- Phase 1: write cutout shape into stencil buffer (doesn't touch pixels)
    love.graphics.setStencilMode("draw", 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", x, y, w, h, r, r)

    -- Phase 2: draw dark overlay everywhere EXCEPT the cutout (notequal test)
    love.graphics.setStencilMode("test", 1)
    love.graphics.setColor(0, 0, 0, opacity)  -- D-02: ~0.60
    love.graphics.rectangle("fill", 0, 0, layout.VW, layout.VH)

    -- Phase 3: reset stencil
    love.graphics.setStencilMode()
    love.graphics.setColor(1, 1, 1, 1)

    -- Phase 4: draw pulse border over the cutout (drawn normally, no stencil)
    local pulse_alpha = 0.4 + 0.4 * math.sin(pulse_t * math.pi * 2)  -- D-03
    love.graphics.setColor(1, 1, 0.4, pulse_alpha)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, w, h, r, r)
    love.graphics.setLineWidth(1)
end
```

[VERIFIED: STACK.md stencil technique + codebase popups.lua backdrop pattern]

### Pattern 2: Spotlight Slide Transition (~0.3s, D-04)

```lua
-- tutorial.lua internal — lerps from prev_rect to next_rect over SLIDE_DURATION
local SLIDE_DURATION = 0.3
local slide_timer = 0
local prev_rect = nil
local next_rect = nil

function M.setTarget(rect)
    prev_rect = M.getSpotlight()  -- current interpolated position
    next_rect = rect
    slide_timer = 0
end

function M.update(dt)
    if slide_timer < SLIDE_DURATION then
        slide_timer = slide_timer + dt
    end
    pulse_timer = pulse_timer + dt
    -- hand animation timer update...
end

function M.getSpotlight()
    if not next_rect then return nil end
    if not prev_rect then return next_rect end
    local t = math.min(slide_timer / SLIDE_DURATION, 1)
    local e = 1 - (1 - t) * (1 - t) * (1 - t)  -- easeOutCubic
    return {
        x = prev_rect.x + (next_rect.x - prev_rect.x) * e,
        y = prev_rect.y + (next_rect.y - prev_rect.y) * e,
        w = prev_rect.w + (next_rect.w - prev_rect.w) * e,
        h = prev_rect.h + (next_rect.h - prev_rect.h) * e,
    }
end
```

[ASSUMED — easing pattern matches existing codebase; exact field names are Claude's discretion]

### Pattern 3: Input Blocking

```lua
-- At the top of arena_screen.mousepressed() and coin_sort_screen.mousepressed()
-- Insert BEFORE all other input handling:
if tutorial.isActive() then
    local spotlight = tutorial.getSpotlight()
    if spotlight then
        local sx, sy, sw, sh = spotlight.x, spotlight.y, spotlight.w, spotlight.h
        local inside = x >= sx and x <= sx + sw and y >= sy and y <= sy + sh
        if not inside then
            return  -- swallow input outside spotlight
        end
    end
end
```

[ASSUMED — exact guard placement is Claude's discretion; pattern matches popups.isInputBlocked() guard in both screens]

### Pattern 4: Localization String Table

```lua
-- Inside tutorial.lua step definitions:
local STEPS = {
    coin_sort = {
        {
            text = { en = "Tap a box to pick up coins", ru = "Нажмите на ячейку, чтобы взять монеты" },
            -- spotlight target provider (called each frame to handle layout changes)
            getRect = function() return getBoxRect(CS_TUTORIAL_SOURCE_BOX) end,
            hand = "tap",
            -- precondition: source box exists and has pickable coins
            check = function() return cs_board_has_source_coins() end,
        },
        -- ... more steps
    },
    arena = {
        -- ... arena steps
    }
}
```

[ASSUMED — exact table structure is Claude's discretion; pattern matches existing data-table conventions in arena_chains.lua and arena_orders.lua]

### Pattern 5: Persistence in progression.dat

```lua
-- In progression.lua getDefaultData():
tutorial_data = {
    cs_done   = false,
    arena_done = false,
},

-- In migration (new MIGRATIONS[3]):
[3] = function(data)
    if not data.tutorial_data then
        data.tutorial_data = { cs_done = false, arena_done = false }
    end
    return data
end,
```

[VERIFIED: progression.lua lines 9–58 for migration pattern; lines 140–159 for arena_data schema pattern]

### Anti-Patterns to Avoid

- **Don't drive tutorial from game events alone (old approach):** The old `advanceTutorial(event, data)` pattern is event-driven but has no precondition safety — any step can be advanced by the wrong event. Use an explicit step object with a `check()` predicate that must pass before `advance()` is accepted.
- **Don't draw the spotlight overlay inside the game-content draw functions:** Draw it as a separate pass after all game content, before popups. The z-order is: game content → spotlight overlay → effects.drawFlash() → popups.drawToasts/drawModal() → tab_bar.
- **Don't mix tutorial state into arena.lua:** The new tutorial module is self-contained. Arena.lua goes back to being a pure game-logic module after D-12 cleanup.
- **Don't guard tab bar separately:** The tab bar must be hidden/disabled for both tutorials to prevent mode-switching mid-tutorial. `tab_bar.draw()` should be suppressed during active tutorial, OR input to the tab bar should be swallowed by the spotlight input filter (tab bar is outside the spotlight zone).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Spotlight hole in overlay | Custom pixel-by-pixel alpha mask | `love.graphics.setStencilMode("draw"/"test")` | Hardware buffer, zero GC, works for any shape |
| Tween/lerp animation | New tween library | Inline `easeOutCubic` (already in codebase 4× places) | Max 3 active tweens at once; 5-line inline is sufficient |
| Localization | i18n library | Simple `{en=..., ru=...}` table with `tutorial.lang` key | Only 2 languages, ~15 strings total |
| Tutorial trigger detection | Polling game state every frame | Callback-at-action-site (same as `advanceTutorial` call sites) | Event-driven is already the pattern; keep it, just add precondition check |

---

## Deletion Inventory (D-12: Clean break for Arena tutorial)

The following code is removed in this phase. The planner must produce explicit deletion tasks for each item.

### arena.lua — Remove completely:
| Symbol | Line | What it is |
|--------|------|------------|
| `tutorial_step` | 25 | Module-local state variable |
| `tutorial_gen_index` | 33 | Module-local state variable |
| `TUTORIAL_GEN_DROPS` | 29–32 | Hardcoded drop table |
| Conditional in `arena.lua` ~line 357–361 | 357 | `if not arena.isTutorialDone()` branch in generator drop logic |
| `arena.getTutorialStep()` | 706 | Public accessor |
| `arena.setTutorialStep()` | 707 | Public mutator |
| `arena.isTutorialDone()` | 708 | Public predicate |
| `tutorial_step = 1` in `arena.init()` | 727 | Reset in init |
| `tutorial_step` and `tutorial_gen_index` in `arena.save()` | 774–775 | Persistence write |
| `tutorial_step` and `tutorial_gen_index` in `arena.load()` | 809–810 | Persistence read |

### arena_screen.lua — Remove completely:
| Symbol | Lines (approx) | What it is |
|--------|---------------|------------|
| `TUTORIAL_TOOLTIPS` table | 766–798 | 18 tooltip strings |
| `drawTutorial()` local function | 848–899 | Drawing old tooltips + cell highlights |
| `advanceTutorial()` local function | 901–977 | 18-step event-driven state machine |
| `drawTutorial()` call in `arena_screen.draw()` | 1158 | Draw call site |
| 5× `advanceTutorial(...)` call sites in `mousepressed` | 1299, 1340, 1382, 1419, 1470, 1495 | Event dispatch sites |
| Dispenser seeding block in `arena_screen.enter()` | 1025–1029 | Tutorial step-1 dispenser seed |

### progression.lua — Migrate:
- `arena_data.tutorial_step` field (line 148) → replaced by `tutorial_data.arena_done`
- Add `MIGRATIONS[3]` to initialize `tutorial_data`
- `CURRENT_SCHEMA_VERSION` bumped from 2 to 3

[VERIFIED: arena.lua and arena_screen.lua line numbers by grep; progression.lua by direct read]

---

## CS Tutorial Pre-Set Board Design

This is under Claude's discretion. The constraints from the decisions are:

1. Box A (source): has `N-1` coins of number X already — ONE more coin needed to fill it (10 slots total, so 9 coins of value X)
2. Box B (donor): has at least 1 coin of the same value X — the player taps B to pick it up, then taps A to place it, filling A
3. After box A fills, the Merge button becomes active for that box specifically
4. Step 4 taps the "Add coins" (bag) button to deal new coins — bags module must have > 0 bags

**Recommended board for Claude:**
- Tutorial starts with `bags = 1` guaranteed (or tutorial module provides its own bag)
- Box 1 (top-left): 9× coin with value 2 (green color)
- Box 2 (adjacent): 1× coin with value 2 + filler of other values
- All other boxes: mixed low values (1s and 2s) to show a realistic board
- The coin value 2 is the lowest merge-producing value, keeping the tutorial stakes low

The pre-set board should NOT use `coin_sort.init()` — instead the tutorial script directly sets `coin_sort` state (or calls a new `coin_sort.initTutorial(board_spec)` entry point) to bypass the normal random deal.

[ASSUMED — exact numbers are Claude's discretion; constraint logic is VERIFIED from coin_sort.lua patterns]

---

## Arena Tutorial Step Design (~7 steps)

Based on D-09 (concepts: dispenser tap, merge, sealed reveals, generator tap, orders, stash) and D-11 (keep hardcoded Da1/Me1 drops), recommended 7-step sequence:

| Step | Spotlight Target | Concept | Action Required | Precondition |
|------|-----------------|---------|-----------------|--------------|
| 1 | Dispenser slot | Tap dispenser → item placed on grid | Tap dispenser | Dispenser has 1 Ch1 item |
| 2 | Grid cells Ch1+Ch1 area | Drag to merge two same items | Drag Ch1 onto Ch1 | Two Ch1 on grid |
| 3 | Revealed sealed cell | Sealed cells revealed after merge | Observe / tap to advance | Box revealed adjacent to merge result |
| 4 | Ch4 generator cell | Generator tap costs Fuel | Tap generator | Fuel > 0 |
| 5 | Da1+Da1 area (from gen drop + dispenser seeded) | Merge drops from generator | Drag Da1 onto Da1 | Two Da1 on grid (hardcoded drops, D-11) |
| 6 | Order card panel | Complete an order | Tap order's complete button (or auto-complete on match) | Matching items on grid for order |
| 7 | Stash slots | Stash stores items | Drag item to stash | Stash visible, grid item exists |

Step 3 could be "tap to continue" (observe step) rather than requiring a specific action — advances on any tap within the spotlight. Steps 2 and 5 are drags; hand icon shows drag-trail animation (D-14).

The dispenser seeding that was previously in `arena_screen.enter()` (step-1 Ch1) moves into the tutorial module's step-1 setup, called when `tutorial.startArena()` is invoked.

[ASSUMED — exact step ordering and grouping is Claude's discretion within D-09 constraints]

---

## Common Pitfalls

### Pitfall 1: Stencil Buffer Not Cleared Between Frames
**What goes wrong:** Stencil writes accumulate across draw calls if not reset. The cutout persists into the next frame or overlaps with popups.
**Why it happens:** `setStencilMode("draw", 1)` writes to the stencil buffer but doesn't clear it automatically.
**How to avoid:** Always call `love.graphics.setStencilMode()` (no args = "off") to reset after the overlay is drawn. LOVE 12.0 clears the stencil buffer on each canvas bind by default, but don't rely on this.
**Warning signs:** Overlay cutout "leaks" into areas it shouldn't, or cutout shape appears in wrong position next frame.

### Pitfall 2: Spotlight Blocks Its Own Instruction Text
**What goes wrong:** Instruction text is positioned inside or on the edge of the spotlight rect, then the dark overlay hides part of it.
**Why it happens:** Text is drawn before the overlay (game content layer), so the overlay covers it.
**How to avoid:** Draw instruction text and hand icon AFTER the stencil overlay, in screen space, not game content layer. Text renders on top of the dim. D-15 (auto-position above/below) must account for tab bar at bottom (Y 1840–1920).
**Warning signs:** Tutorial text appears dimmed or cut off.

### Pitfall 3: Tab Bar Input During Tutorial Causes Mode Switch
**What goes wrong:** Player taps tab bar during tutorial, switches mode, tutorial state is abandoned mid-step.
**Why it happens:** Tab bar draw and input handling run on both screens. The spotlight input filter passes tab-bar-region taps if the tab bar is within a spotlight zone, or accidentally if input guard isn't applied to tab bar code path.
**How to avoid:** When tutorial is active, suppress tab bar entirely — either don't call `tab_bar.draw()` at all, or ensure the spotlight input filter runs before the tab bar check in `mousepressed()`. The cleanest approach: don't draw tab bar during active tutorial (it's confusing UX anyway).
**Warning signs:** Screen switches unexpectedly during tutorial playthrough.

### Pitfall 4: Pre-Set Board Drift (CS Tutorial)
**What goes wrong:** CS tutorial board is set up correctly on first enter, but if the player returns to CS mid-tutorial (unlikely since tab bar is hidden, but possible via game-over screen), the tutorial board state is gone.
**Why it happens:** `coin_sort.init()` runs on enter and overwrites the tutorial board.
**How to avoid:** Tutorial persistence tracks `cs_done`. If CS tutorial is not done, `coin_sort_screen.enter()` detects active tutorial and calls `coin_sort.initTutorial()` instead of `coin_sort.init()`. The tutorial board spec is deterministic, so re-initialization produces the correct board.
**Warning signs:** Tutorial starts on a random board instead of the pre-set teaching board.

### Pitfall 5: Animation State Check Omitted Before Step Advance
**What goes wrong:** Tutorial advances to the next step while a coin flight or merge animation is still playing. The spotlight jumps to the next target while coins are mid-air. Confusing visually, and the precondition for step N+1 may not be true yet (coins haven't landed).
**Why it happens:** `tutorial.advance()` is called in the action handler (e.g., merge complete callback), but the animation callback fires at visual completion, not state completion.
**How to avoid:** In the `tutorial.advance()` implementation, add an animation-idle check: `if animation.isIdle() then proceed else queue the advance`. The `animation.lua` module exposes `pick_state` and `bg_state` — check both are IDLE before slide transition. [VERIFIED: animation.lua lines 21–22 — `pick_state` and `bg_state` are local; expose via `animation.isIdle()` accessor if one doesn't exist already]
**Warning signs:** Spotlight teleports while coins are still flying.

### Pitfall 6: Web/WASM Stencil Buffer Availability
**What goes wrong:** `setStencilMode` throws or silently does nothing on the web build (love-web-builder SDL3 port is experimental).
**Why it happens:** The SDL3 Emscripten port targets WebGL2, which has a stencil buffer, but the LOVE runtime may not request it.
**How to avoid:** Test stencil on web build on Day 1 of implementation. If it fails, fall back to the four-rectangle approach (documented in STACK.md). Add a `canvas = love.graphics.newCanvas(VW, VH, {dpiscale = 1, stencil = true})` variant if needed.
**Warning signs:** Dark overlay covers the entire screen (no cutout), or Lua error mentioning stencil/render state.

---

## Code Examples

### Verified: popups.lua backdrop pattern (direct reference for overlay)

```lua
-- Source: popups.lua line 349 — CARD_BACKDROP pattern
-- Backdrop dimmer (direct model for spotlight overlay):
love.graphics.setColor(0, 0, 0, active_modal.backdrop_alpha)  -- CARD_BACKDROP = {0,0,0,0.7}
love.graphics.rectangle("fill", 0, 0, layout.VW, layout.VH)
```
[VERIFIED: popups.lua lines 349–350]

### Verified: arena_screen.draw() z-order (where to insert spotlight layer)

```lua
-- Source: arena_screen.lua lines 1135–1199 — existing draw order:
drawResources()
drawDispenser()
drawOrdersStrip()
drawGrid()
drawStash()
drawDragged()
drawTutorial()          -- <- REMOVE this (old system)
-- INSERT: tutorial.drawSpotlight() here (new spotlight overlay, above game content)
effects.draw()
effects.drawFlash()
drawFuelDepletionOverlay()
popups.drawToasts()
popups.drawModal()
tab_bar.draw("arena")   -- <- SUPPRESS during active tutorial
```
[VERIFIED: arena_screen.lua lines 1158–1199]

### Verified: animation idle check (needed for pitfall 5 mitigation)

```lua
-- Source: animation.lua lines 21-22 — state vars are local, need accessor
-- Check if both tracks are idle before advancing tutorial:
-- animation.lua exposes getMergeLockedBoxes() but not a direct isIdle()
-- Planner must add: function animation.isIdle() return pick_state == "idle" and bg_state == "idle" end
```
[VERIFIED: animation.lua lines 21–22 show local pick_state and bg_state]

### Verified: progression migration pattern

```lua
-- Source: progression.lua lines 46–57 — migration 2 as direct template
[3] = function(data)
    if not data.tutorial_data then
        data.tutorial_data = { cs_done = false, arena_done = false }
    end
    -- Also clean up old arena_data.tutorial_step if migrating from old save
    if data.arena_data then
        data.arena_data.tutorial_step = nil
    end
    return data
end,
```
[VERIFIED: progression.lua lines 46–57 migration pattern; line 148 shows tutorial_step field]

---

## State of the Art

| Old Approach | New Approach | Why Changed |
|--------------|--------------|-------------|
| 18-step event-driven state machine in `arena_screen.lua` | Spotlight-based tutorial in `tutorial.lua` with precondition validation | TUT-04 requirement; cleaner separation; extensible to CS tutorial |
| Tooltip text drawn as a single bar above grid | Spotlight overlay with animated cutout + positioned text + hand icon | Visual clarity; works for both pointer-based and drag steps |
| Tutorial state stored in `arena_data.tutorial_step` | `tutorial_data = {cs_done, arena_done}` separate key | Cleaner schema; CS tutorial needs its own tracking |
| No Coin Sort tutorial | 5-step guided CS tutorial on first run | New-player onboarding for the more complex sorting mechanic |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | CS tutorial bypasses normal `coin_sort.init()` via a new `coin_sort.initTutorial(board_spec)` entry point | CS Tutorial Pre-Set Board Design | If coin_sort doesn't support this cleanly, the board setup pattern needs redesign; medium rework |
| A2 | `tutorial.lua` is the logic module; screen modules call into it for drawing (not vice versa) | Architecture Patterns | If drawing is in tutorial.lua it violates logic/visual separation rule from CLAUDE.md; requires refactor |
| A3 | Tab bar is suppressed (not drawn) during active tutorial | Pitfall 3 | If suppressing tab bar causes visual glitch or state confusion, need an alternative (e.g., draw but block input) |
| A4 | `animation.isIdle()` accessor does not currently exist and must be added | Code Examples | Low risk — adding an accessor to animation.lua is a one-liner; confirmed pick_state and bg_state are the right variables |
| A5 | Arena tutorial step 3 is an "observe" step (tap to continue) rather than a required action | Arena Tutorial Step Design | If observe steps feel wrong in playtest, it can be replaced with a tap-the-revealed-cell action; low risk |

---

## Environment Availability

Step 2.6: SKIPPED — phase is purely code changes in existing LOVE2D project. No external tools, services, or CLIs beyond the project's own LOVE2D build system.

---

## Open Questions

1. **Does `coin_sort.lua` need a new `initTutorial()` entry point, or can tutorial board state be set by directly writing to coin_sort's state table?**
   - What we know: `coin_sort.init()` resets all state from scratch. `coin_sort.getState()` returns the live state table.
   - What's unclear: Whether state fields are write-accessible from outside, or whether init() must be used.
   - Recommendation: Add `coin_sort.initTutorial(board)` that sets pre-defined boxes without the random deal. Keeps encapsulation, explicit API.

2. **Should CS tutorial track partial progress (current step) or just done/not-done?**
   - What we know: Arena tutorial stores `tutorial_step` for partial save. CS tutorial is only 5 steps.
   - What's unclear: If player force-quits mid-CS-tutorial, should they restart from the beginning or step 3?
   - Recommendation: Store `cs_step` (1–5) in `tutorial_data` for consistency. Tutorial restarts from last step on re-enter. Very low implementation cost.

3. **Should Arena tutorial guard against the player having somehow completed arena orders before tutorial starts (e.g., fresh install but corrupted save)?**
   - What we know: `arena_done = false` means show tutorial. If board state is somehow wrong (orders already complete), step preconditions will fail.
   - What's unclear: Whether recovery is "reset arena to initial board" or "skip tutorial".
   - Recommendation: If step precondition fails on enter and cannot be recovered, set `arena_done = true` and proceed to free play. The tutorial is quality-of-life, not mandatory for game correctness.

---

## Sources

### Primary (HIGH confidence)
- Existing codebase: `arena.lua`, `arena_screen.lua`, `tutorial.lua`, `progression.lua`, `popups.lua`, `effects.lua`, `animation.lua`, `coin_sort_screen.lua` — direct read, line numbers cited [VERIFIED]
- `.planning/research/STACK.md` — stencil API research from 2026-04-05, LOVE 12.0 source-verified [VERIFIED]
- `.planning/phases/04-spotlight-tutorials/04-CONTEXT.md` — locked decisions D-01 through D-17 [VERIFIED]

### Secondary (MEDIUM confidence)
- LOVE 12.0 stencil source (Graphics.cpp, renderstate.h, renderstate.cpp) — verified in prior STACK.md research session [CITED: .planning/research/STACK.md lines 56–83]
- WebGL2 stencil buffer spec — guaranteed 8-bit stencil [CITED: .planning/research/STACK.md line 86]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — stencil API already verified in STACK.md research; no new dependencies
- Architecture: HIGH — follows directly from CLAUDE.md patterns (logic/visual separation, module exports, no goto)
- Deletion inventory: HIGH — grep-verified line numbers for all symbols to remove
- CS tutorial board: MEDIUM — design constraints verified; exact numbers are Claude's discretion (A1)
- Arena step design: MEDIUM — concept list is locked (D-09); step ordering and exact text are Claude's discretion
- Pitfalls: HIGH — all grounded in verified code patterns or known LOVE2D web behavior

**Research date:** 2026-04-07
**Valid until:** 2026-05-07 (stable LOVE2D API, no churn expected)
