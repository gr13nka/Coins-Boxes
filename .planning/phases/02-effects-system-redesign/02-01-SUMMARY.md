---
phase: 02-effects-system-redesign
plan: 01
subsystem: effects
tags: [particles, performance, pooling, love2d, lua]

# Dependency graph
requires:
  - phase: 01-cleanup-and-prep
    provides: Clean codebase with dead code removed
provides:
  - Three-tier performance detection (HIGH/MED/LOW) in mobile.lua
  - Tiered particle configuration replacing binary IS_MOBILE in particles.lua
  - Pre-allocated effects.lua module with fly-to-bar, flash, and burst pools
  - Resource bar target API for screen modules (setResourceBarTargets/spawnResourceFly)
affects: [02-02, 02-03, 02-04, 02-05, coin_sort_screen, arena_screen]

# Tech tracking
tech-stack:
  added: []
  patterns: [pre-allocated free-stack pool, tier-aware config tables, cached platform detection]

key-files:
  created: [effects.lua]
  modified: [mobile.lua, particles.lua, main.lua]

key-decisions:
  - "Three tiers (HIGH/MED/LOW) instead of binary mobile/desktop for web performance optimization"
  - "Free-stack pool pattern in effects.lua matching existing particles.lua architecture"
  - "drawFlash() exposed separately from effects.draw() for draw-ordering control"

patterns-established:
  - "TIER_CONFIG table pattern: define per-tier constants, select config = TIER_CONFIG[tier] at init"
  - "Free-stack pool: pre-allocate N objects, track active/free with swap-remove for O(1) ops"
  - "Resource target API: screen modules call setResourceBarTargets(), effects use spawnResourceFly()"

requirements-completed: [FX-01]

# Metrics
duration: 3min
completed: 2026-04-05
---

# Phase 2 Plan 1: Effects Foundation Summary

**Three-tier performance system (HIGH/MED/LOW) with tiered particles.lua config and new effects.lua pre-allocated pool module for fly-to-bar, flash, and burst effects**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-05T18:05:40Z
- **Completed:** 2026-04-05T18:09:04Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Added three-tier performance detection to mobile.lua (HIGH=desktop, MED=web, LOW=mobile) with cached result and override API
- Replaced binary IS_MOBILE in particles.lua with TIER_CONFIG tables providing granular control over max_particles (200/100/50), spawn counts, lifetimes, bounces, and highlight rendering per tier
- Created effects.lua with pre-allocated pools for fly-to-bar icons (15), overlay flash, and celebration burst (20) using the same free-stack pattern as particles.lua for zero GC pressure

## Task Commits

Each task was committed atomically:

1. **Task 1: Three-tier performance system + particles.lua tiered redesign** - `e274904` (feat)
2. **Task 2: Create effects.lua module with pre-allocated pools** - `4debfe8` (feat)

## Files Created/Modified
- `mobile.lua` - Added getPerformanceTier() and setPerformanceTier() with tier_cache
- `particles.lua` - Replaced IS_MOBILE binary config with TIER_CONFIG table system (HIGH/MED/LOW)
- `effects.lua` - New module with fly-to-bar icon pool, overlay flash, celebration burst, shared easing functions, resource target API
- `main.lua` - Added effects require and init() call in love.load()

## Decisions Made
- Three tiers (HIGH/MED/LOW) instead of binary: web builds get a middle tier (MED) with 100 particles and reduced effects, distinct from both desktop (200) and mobile (50)
- drawFlash() is a separate public function rather than part of effects.draw() to allow screen modules to control draw ordering (flash goes above game content but below UI)
- Free-stack pool pattern matches particles.lua architecture for consistency across the codebase

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- effects.lua foundation is ready for Plans 02-04 to integrate fly-to-bar into merge callbacks, add flash/burst to reward moments, and wire screen modules
- particles.lua tiered config is ready for Plan 02-02 screen shake and merge effects enhancements
- Resource target API (setResourceBarTargets/spawnResourceFly) is ready for screen modules to register their fuel/star bar positions

## Self-Check: PASSED

All files verified present. All commit hashes verified in git log.

---
*Phase: 02-effects-system-redesign*
*Completed: 2026-04-05*
