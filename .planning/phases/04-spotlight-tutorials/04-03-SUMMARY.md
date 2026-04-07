---
phase: 04-spotlight-tutorials
plan: 03
status: partial-complete
tasks_executed: 2 of 3
tasks_skipped: 1 (Task 3 is human checkpoint, handled by orchestrator)
started: 2026-04-07
completed: 2026-04-07
subsystem: tutorial
tags: [tutorial, spotlight, arena, cleanup]
requirements: [TUT-03, TUT-04]

dependency_graph:
  requires: ["04-01"]
  provides: ["arena spotlight tutorial", "old tutorial removed"]
  affects: ["arena.lua", "arena_screen.lua"]

tech_stack:
  added: []
  patterns: ["tutorial.registerSteps", "setStencilMode draw/test pattern", "isStashVisible/isOrdersVisible gating"]

key_files:
  modified:
    - arena.lua
    - arena_screen.lua

decisions:
  - "Replaced arena.isTutorialDone() with tutorial.isActive() + tutorial.getActiveTutorial() == 'arena' for fuel depletion guard"
  - "Used setStencilMode API (LOVE 11/12) matching coin_sort_screen.lua pattern from Plan 02"
  - "Step 4 (sealed reveal) spotlights first sealed cell dynamically rather than hardcoding position"
  - "Orders visible at step 6, stash visible at step 7 (7-step system vs old 13/15 thresholds)"

metrics:
  duration: ~45 minutes
  completed_date: "2026-04-07"
  tasks: 2
  files_modified: 2
---

# Phase 04 Plan 03: Remove Old Tutorial and Register Arena Spotlight Tutorial

Built a clean 7-step spotlight-based arena tutorial replacing the verbose 18-step state machine, with all old tutorial code fully excised.

## What Was Built

### Task 1: Remove Old Tutorial System (arena.lua + arena_screen.lua)

**arena.lua:**
- Deleted `local tutorial_step = 1` and `local tutorial_gen_index = 0`
- Deleted `local TUTORIAL_GEN_DROPS` table (old name)
- Replaced with `local ARENA_TUTORIAL_GEN_DROPS` (new name) + `local arena_tutorial_gen_count = 0` driven by `tutorial.lua` state (D-11 preserved)
- Removed `arena.getTutorialStep()`, `arena.setTutorialStep()`, `arena.isTutorialDone()` functions
- Cleaned `arena.save()`: removed `tutorial_step` and `tutorial_gen_index` fields
- Cleaned `arena.init()`: removed those field loads, reset `arena_tutorial_gen_count = 0`
- Cleaned `arena.setupInitialBoard()`: replaced `tutorial_step = 1` with `arena_tutorial_gen_count = 0`
- Generator tap logic: now checks `tutorial.isActive() and tutorial.getActiveTutorial() == "arena"` for hardcoded drops

**arena_screen.lua:**
- Deleted `TUTORIAL_TOOLTIPS` table (18 strings)
- Deleted `drawTutorial()` function (cell highlighting, tooltip drawing)
- Deleted `advanceTutorial(event, data)` function (event-dispatch state machine)
- Replaced `arena.getTutorialStep()` in `drawStash()` with `isStashVisible()`
- Replaced `arena.getTutorialStep()` in `drawOrdersStrip()` with `isOrdersVisible()`
- Replaced `arena.isTutorialDone()` in fuel depletion timer with `tutorial.isActive()` check
- Replaced all `arena.getTutorialStep()` / `advanceTutorial()` call sites in `mousepressed` and `mousereleased`
- Removed old dispenser seeding block in `enter()` (was `arena.getTutorialStep() == 1` check)

### Task 2: Register 7-Step Arena Spotlight Tutorial (arena_screen.lua)

**New visibility helpers:**
- `isStashVisible()` — returns false during arena tutorial steps 1-6, true at step 7+
- `isOrdersVisible()` — returns false during arena tutorial steps 1-5, true at step 6+

**New rect helpers** for spotlight targeting:
- `getCellRect(grid_index)` — grid cell → {x,y,w,h}
- `getDispenserRect()` — dispenser circle bounds
- `getStashRect()` — full stash row bounds
- `getOrdersRect()` — orders strip bounds
- `getGeneratorCellRect()` — first generator cell found via scan

**7-step tutorial registered** via `tutorial.registerSteps("arena", {...})`:

| Step | Concept | Spotlight | Hand | Advance trigger |
|------|---------|-----------|------|-----------------|
| 1 | Dispenser tap (place item) | Dispenser circle | tap | Dispenser tap (mousepressed) |
| 2 | Place second item | Dispenser circle | tap | Dispenser tap (mousepressed) |
| 3 | Merge matching items | First Ch1 cell | drag | Successful merge (mousereleased) |
| 4 | Sealed reveal (observe) | First sealed cell | tap | Any tap in spotlight |
| 5 | Generator tap | First generator | tap | Successful gen tap (mousereleased) |
| 6 | Orders panel | Orders strip | tap | Any tap in spotlight |
| 7 | Stash | Stash row | tap | Any tap in spotlight |

- Steps 1/2 `on_enter`: `arena.pushDispenser("Ch", 1)` seeds dispenser
- Hardcoded gen drops (D-11): Da1 Egg + Me1 Smoked Meat, driven by `arena_tutorial_gen_count` in arena.lua

**`drawSpotlightOverlay()` local function** added:
- Phase 1: `setStencilMode("draw", 1)` writes cutout rectangle
- Phase 2: `setStencilMode("test", 1)` draws 60% black overlay with hole
- Phase 3: `setStencilMode()` resets
- Pulsing border: `tutorial.getPulseAlpha()` drives animated yellow outline
- Hand animation: tap (bouncing offset) and drag (lerp from source toward drag_target) using `tutorial.getHandAnim()`
- Text: positioned above/below spotlight via `tutorial.getTextPosition()`, black pill background

**Integration points:**
- `arena_screen.enter()`: calls `tutorial.start("arena")` if not done, `tutorial.isDone("arena")` guard
- `arena_screen.update(dt)`: `tutorial.update(dt)` added
- `arena_screen.draw()`: spotlight rendered after `effects.draw()`, before `effects.drawFlash()`; tab bar suppressed during active tutorial (T-04-06 mitigation)
- `arena_screen.mousepressed()`: input filter via `tutorial.isInputAllowed(x, y)` at top; observe steps 4/6/7 auto-advance on any tap; step-conditional advance calls at dispenser tap (1/2) and merge (3) and generator tap (5)

## Deviations from Plan

**[Rule 1 - Bug] stencil API mismatch**
- Found during: Task 2
- Issue: Initial implementation used `love.graphics.stencil(function() ... end, "replace", 1)` + `setStencilTest()` (old LOVE API). Plan 02's coin_sort_screen.lua uses `setStencilMode("draw", 1)` / `setStencilMode("test", 1)` / `setStencilMode()` (LOVE 11/12 API).
- Fix: Replaced with the `setStencilMode` pattern to match established project usage
- Files modified: arena_screen.lua

**[CLAUDE.md] File size warning**
- arena_screen.lua grew to 1631 lines, exceeding the 1.5k line threshold
- Per CLAUDE.md: "When file becomes bigger then 1.5k lines suggest refactoring"
- Suggestion: Consider splitting drawing helpers (drawGrid, drawStash, drawOrdersStrip, spotlight overlay) into a separate `arena_draw.lua` module in a future plan

**[Deviation] advanceTutorial("any", nil) removal without replacement**
- The old code called `advanceTutorial("any", nil)` as a catch-all at the end of `mousepressed`
- Removed without replacement — the new system uses explicit step-gated advance calls instead of event dispatch
- This is correct behavior: the observe steps (4/6/7) are handled at the tutorial input filter at the top of `mousepressed`

## Known Stubs

None. All 7 tutorial steps are fully wired with real game state checks.

## Threat Flags

None. No new network surface or auth paths introduced.

## Self-Check: PASSED

- arena.lua exists: YES (846 lines)
- arena_screen.lua exists: YES (1631 lines)
- Commit 61e50a5 exists: YES
- Commit f00fc68 exists: YES
- Zero old tutorial symbols in arena.lua: VERIFIED
- Zero old tutorial symbols in arena_screen.lua: VERIFIED
- tutorial.registerSteps("arena") in arena_screen.lua: VERIFIED (1 match)
- setStencilMode in arena_screen.lua: VERIFIED (3 matches)
- tutorial.advance() in arena_screen.lua: VERIFIED (4 matches)
- No goto in either file: VERIFIED

Task 3 (human-verify) is NOT executed — left for orchestrator.
