---
phase: 04-spotlight-tutorials
plan: 02
subsystem: coin-sort-tutorial
status: complete
started: 2026-04-07
completed: 2026-04-07
tags: [tutorial, spotlight, coin-sort, input-filtering, stencil]
dependency_graph:
  requires: [04-01]
  provides: [coin-sort-tutorial-complete]
  affects: [coin_sort_screen, coin_sort]
tech_stack:
  added: []
  patterns:
    - love.graphics.setStencilMode draw/test/reset for spotlight cutout
    - Closure-captured step index for async callback tutorial gating
    - Pre-set deterministic tutorial board via initTutorial(board_spec)
    - Timer-based auto-advance for free-play step 5
key_files:
  created: []
  modified:
    - coin_sort.lua
    - coin_sort_screen.lua
decisions:
  - Spotlight overlay drawn OUTSIDE the shake transform so it never shakes
  - Tutorial input filter placed after tab_bar.mousepressed() (tab bar suppressed anyway) for clean flow
  - tut_step_at_place closure variable captures step at press-time to avoid race with async flight callback
  - Step 2 check uses closure access to module-local `selection` variable
  - free_play_timer initialized to 0 at module level, reset in enter() and set by step 5 on_enter
metrics:
  duration_minutes: 7
  tasks_completed: 1
  tasks_total: 1
  files_modified: 2
---

# Phase 04 Plan 02: Coin Sort Tutorial Summary

Built the Coin Sort 5-step spotlight tutorial: deterministic board setup in `coin_sort.lua`, step registration and full overlay rendering in `coin_sort_screen.lua`.

## What Was Built

### coin_sort.lua — `initTutorial(board_spec)` (26 lines added)

- New public function after `init()`: sets up boxes directly from `board_spec.boxes` without random dealing
- Loads `max_coin_reached` from progression (same as normal init)
- Uses `coin_utils.createCoin()` for each coin value so coins have proper structure
- Calls `commissions.generate(max_coin_reached)` to initialize commissions for the session
- Sets `game_active = true` so the screen renders correctly

### coin_sort_screen.lua — Tutorial integration (230 lines added, ~5 lines modified)

**CS_TUTORIAL_BOARD spec** (module-local constant):
- `active_box_count = 4`, boxes 11–14 active (UNLOCK_ORDER starting positions)
- Box 11: 9× value-2 coins — needs exactly 1 more to trigger the merge step (D-07)
- Box 12: `{2, 2, 2, 1, 1}` — donor box, player picks the 3 value-2 coins from the top
- Boxes 13, 14: filler coins showing a realistic board state

**5 Tutorial Steps** registered via `tutorial.registerSteps("coin_sort", {...})` at module load time:
1. Pick — spotlight box 12, hand="tap", check: box 12 has coins
2. Place — spotlight box 11, hand="tap", check: `selection ~= nil` (player has picked up)
3. Merge — spotlight Merge button, hand="tap", check: box 11 is in getMergeableBoxes()
4. Deal — spotlight Add Coins button, hand="tap", on_enter: ensure bags > 0 via bags.addBags(1) safety net
5. Free play — getRect=nil (no spotlight), hand="none", on_enter: sets free_play_timer=2.0

**drawSpotlightOverlay()** local function (rendering only):
- Phase 1: stencil draw — writes cutout rectangle
- Phase 2: stencil test — dark overlay everywhere except cutout
- Phase 3: stencil reset — clears stencil state
- Phase 4: pulse border — `tutorial.getPulseAlpha()` animated yellow outline
- Phase 5: hand icon — tap animation (down 20px + return) with stylized triangle+circle shape
- Phase 6: instruction text — `tutorial.getTextPosition()` auto-positions above/below spotlight

**enter() changes**:
- Resets `free_play_timer = 0` on fresh init
- Checks `not tutorial.isDone("coin_sort") and not tutorial.isActive()` → calls `initTutorial` + `tutorial.start`
- Falls through to normal `coin_sort.init()` for returning players

**update() changes**:
- Calls `tutorial.update(dt)` on every frame
- Free-play timer countdown: when step == 5, decrements `free_play_timer`, calls `tutorial.advance()` at 0

**draw() changes**:
- Spotlight overlay drawn OUTSIDE screen shake transform (after `love.graphics.pop()`) — screen-level overlay should not shake
- `tab_bar.draw()` wrapped in `not (tutorial.isActive() and ...)` guard — suppresses tab bar during tutorial (Pitfall 3)

**mousepressed() changes**:
- Tutorial input filter inserted early: `if not tutorial.isInputAllowed(x, y) then return end`
- After pick succeeds (step 1): `tutorial.advance()`
- `tut_step_at_place` closure captures step index at press time for async safety

**mousereleased() changes**:
- Merge final callback (step 3): `tutorial.advance()` after all boxes merge
- Deal final callback (step 4): `tutorial.advance()` after dealing completes

## Deviations from Plan

**1. [Rule 1 - Bug] Spotlight drawn outside shake transform**
- **Found during:** Task 1 implementation review
- **Issue:** Plan placed overlay inside the shake transform block. A screen-level overlay should not shake with game content — it would look broken during merge animations.
- **Fix:** Moved `drawSpotlightOverlay()` call to after `love.graphics.pop()`, between shake-end and tab bar.
- **Files modified:** coin_sort_screen.lua (draw function)
- **Commit:** 67f96d1

**2. [Rule 2 - Missing critical functionality] `tut_step_at_place` closure variable**
- **Found during:** Task 1 — analyzing async flight callback
- **Issue:** By the time the flight callback fires, `tutorial.getCurrentStep()` may have changed (e.g., if tutorial.advance() was already called by another path). Checking step inside the callback without capturing it at press-time would be fragile.
- **Fix:** Added `local tut_step_at_place = tutorial.getCurrentStep()` before `animation.startFlight()`, used in the final callback.
- **Files modified:** coin_sort_screen.lua (mousepressed)
- **Commit:** 67f96d1

## Known Stubs

None — all 5 tutorial steps are fully wired with real game logic checks.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced. Tutorial board spec is a hardcoded Lua constant (T-04-04: accepted per plan threat model).

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| coin_sort.lua exists | FOUND |
| coin_sort_screen.lua exists | FOUND |
| Commit 67f96d1 exists | FOUND |
| initTutorial in coin_sort.lua | 1 match |
| registerSteps in coin_sort_screen.lua | 1 match |
