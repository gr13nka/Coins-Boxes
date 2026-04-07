---
phase: 01-cleanup-and-prep
plan: 02
subsystem: gameplay
tags: [lua, love2d, coin-sort, drops, double-merge, dead-code-removal]

# Dependency graph
requires:
  - phase: none
    provides: existing coin_sort.lua, drops.lua, coin_sort_screen.lua
provides:
  - Working double merge mechanic (charges produce 4 coins instead of 2)
  - Clean coin_sort.lua with dead merge() removed
  - Fixed drops.applyPendingCSDrops preserving double_merge charges
  - Double merge UI indicator on Coin Sort screen
affects: [arena-orders, drops, coin-sort-balance]

# Tech tracking
tech-stack:
  added: []
  patterns: [cross-module charge consumption via getter/use API pattern]

key-files:
  created: []
  modified: [coin_sort.lua, drops.lua, coin_sort_screen.lua]

key-decisions:
  - "Double merge indicator placed above merge button using existing font, no new assets"
  - "Flash text uses 1.5s fade-out for consumed charge feedback"

patterns-established:
  - "Charge consumption pattern: getter checks availability, use function decrements and syncs"
  - "Return value extension: new return values appended to existing functions (Lua ignores extras)"

requirements-completed: [CLN-03, CLN-05]

# Metrics
duration: 4min
completed: 2026-04-05
---

# Phase 1 Plan 2: Dead Code Removal and Double Merge Wiring Summary

**Removed dead coin_sort.merge() function and wired double merge charges from Arena hard orders to produce 4 coins per merge in Coin Sort with visible charge indicator**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-05T14:53:31Z
- **Completed:** 2026-04-05T14:57:06Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Deleted 72 lines of dead code (coin_sort.merge) that duplicated executeMergeOnBox with divergences
- Fixed critical bug where drops.applyPendingCSDrops() zeroed double_merge charges before they could be consumed
- Wired double merge consumption into executeMergeOnBox: checks charges, uses one, produces 4 coins instead of 2
- Added "2x (N)" badge above merge button showing available double merge charges
- Added "DOUBLE MERGE!" flash text (1.5s fade-out) when a charge is consumed during merge

## Task Commits

Each task was committed atomically:

1. **Task 1: Delete dead coin_sort.merge() and fix double_merge charge loss bug** - `627cebd` (feat)
2. **Task 2: Add double merge charge indicator to Coin Sort screen** - `4fef5e1` (feat)

## Files Created/Modified
- `coin_sort.lua` - Removed dead merge(), added double merge consumption in executeMergeOnBox, returns used_double flag
- `drops.lua` - Fixed applyPendingCSDrops to preserve double_merge charges (removed zeroing line)
- `coin_sort_screen.lua` - Added double_merge_flash timer, "2x" badge display, "DOUBLE MERGE!" flash text, updated onBoxMerge callback

## Decisions Made
- Placed the "2x (N)" indicator above the merge button using the existing `font` variable -- no new fonts or assets needed
- Used 1.5 second flash duration for "DOUBLE MERGE!" feedback to match the existing merge_timer (2s) feel
- Extended executeMergeOnBox return signature with 5th value (used_double) rather than creating a separate query function -- Lua silently ignores extra returns so all existing callers are unaffected

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Double merge mechanic is fully wired: Arena hard orders drop charges, charges survive CS screen entry, merges consume them
- The feature can be tested end-to-end once Arena order drops are earned from hard orders
- No blockers for subsequent plans

## Self-Check: PASSED

All files exist, all commits verified (627cebd, 4fef5e1).

---
*Phase: 01-cleanup-and-prep*
*Completed: 2026-04-05*
