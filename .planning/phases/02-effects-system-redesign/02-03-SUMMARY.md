---
phase: 02-effects-system-redesign
plan: 03
subsystem: effects
tags: [arena-effects, dissolve, chest-shake, fly-to-bar, level-celebration, love2d, lua]

# Dependency graph
requires:
  - plan: 02-01
    provides: effects.lua pools, particles.spawnMergeExplosion, tiered performance
provides:
  - Arena merge dissolve/glow animation replacing fragment explosion (D-03)
  - Chest open shake + chain-colored particle pop sequence (D-04)
  - Fly-to-bar resource icons from order cards to resource bar (D-05)
  - Level completion white flash + gold burst celebration (D-06)
  - PILL_W/PILL_H/PILL_GAP/PILL_START_X/PILL_Y shared pill geometry constants
affects: [02-05, arena_screen]

# Tech tracking
tech-stack:
  added: []
  patterns: [dissolve-ghost table, deferred-action shake, layout-derived fly targets, pill geometry constants]

key-files:
  created: []
  modified: [arena_screen.lua]

key-decisions:
  - "Dissolve ghosts stored separately from grid to draw fading item on already-cleared cell"
  - "Chest tap deferred: shake animation runs first, actual tapChest executes on shake completion"
  - "Pill geometry extracted as module-level constants shared between drawResources and fly-to-bar targeting"
  - "SHAPE_DEFS dispatch table replaces if/elseif chain for per-chain polygon shapes"

patterns-established:
  - "Dissolve ghost pattern: store visual copy of cleared cell for dissolve tween rendering"
  - "Deferred action: chest_shakes table delays game action until visual effect completes"
  - "Layout-derived coordinates: fly targets computed from PILL_* constants, not hardcoded pixels"

requirements-completed: [FX-03, FX-04]

# Metrics
duration: ~8min
completed: 2026-04-05
---

# Phase 2 Plan 3: Arena Visual Effects Summary

**Arena-specific dissolve merges, chest shake-pop, fly-to-bar star icons, and level completion celebration flash**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-05
- **Completed:** 2026-04-05
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

### Task 1: Arena merge glow/dissolve + chest open effects (c579219)
- Added dissolve_out tween style: source items glow (brighten 50%) and fade out on merge instead of fragment explosion (D-03)
- Created dissolve_ghosts table to render fading items on already-cleared grid cells
- Implemented chest_shakes system: 0.2s random-offset shake followed by chain-colored particle burst via particles.spawnMergeExplosion (D-04)
- Deferred chest tap execution to after shake completes for proper visual sequence
- Integrated effects.lua into arena_screen (require, update, draw, drawFlash)
- Added cellCenterPos() helper for DRY grid center coordinate calculation
- Refactored drawShape() from if/elseif chain to SHAPE_DEFS dispatch table
- Added effects.spawnBurst() at merge point with 6 chain-colored particles

### Task 2: Fly-to-bar resource icons + big reward flash (98a5539)
- Extracted pill geometry as module-level constants: PILL_W, PILL_H, PILL_GAP, PILL_START_X, PILL_Y
- Updated drawResources() to use shared pill constants instead of local duplicates
- Set effects.setResourceBarTargets() in enter() with layout-derived coordinates (not hardcoded)
- Triggered effects.spawnResourceFly() cascade on order star rewards from order card center (D-05)
- Triggered effects.spawnFlash(0.3, white) + effects.spawnBurst(16, gold) on level completion (D-06)
- File stays at 1499 lines (under 1500 CLAUDE.md threshold)

## Task Commits

Each task was committed atomically:

1. **Task 1: Arena merge dissolve, chest shake, effects integration** - `c579219` (feat)
2. **Task 2: Fly-to-bar resource icons and level completion celebration** - `98a5539` (feat)

## Files Created/Modified
- `arena_screen.lua` - dissolve_out tween, dissolve_ghosts, chest_shakes, SHAPE_DEFS table, cellCenterPos(), PILL_* constants, effects integration, fly-to-bar on order rewards, level celebration flash+burst

## Decisions Made
- Dissolve ghosts stored in separate table because arena.executeMerge clears the source cell before the dissolve animation can read it
- Chest open uses deferred action pattern: visual shake runs for 0.2s, then arena.tapChest executes on completion
- Pill geometry shared as module-level constants so fly-to-bar targets auto-update if layout changes
- SHAPE_DEFS dispatch table is more maintainable than nested if/elseif for 11 shape types

## Deviations from Plan

None -- plan executed as written.

## Issues Encountered
None

## User Setup Required

None

## Next Phase Readiness
- All four Arena effects (D-03 through D-06) complete and integrated
- Ready for performance verification in Plan 05

## Self-Check: PASSED

All files verified present. All commit hashes verified in git log.

---
*Phase: 02-effects-system-redesign*
*Completed: 2026-04-05*
