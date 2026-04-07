---
phase: 01-cleanup-and-prep
plan: 01
subsystem: persistence
tags: [lua, love2d, save-migration, schema-versioning, dead-code-removal]

# Dependency graph
requires: []
provides:
  - "Clean codebase with 6 dead classic-mode files removed"
  - "progression.lua schema versioning (CURRENT_SCHEMA_VERSION = 1) with migration infrastructure"
  - "Migration v1 that strips stale fields from old saves"
  - "arena_chains.lua reads max_coin_reached from progression.lua directly"
affects: [01-cleanup-and-prep, effects-system]

# Tech tracking
tech-stack:
  added: []
  patterns: [schema-versioning-with-migration-table, runMigrations-before-mergeWithDefaults]

key-files:
  created: []
  modified:
    - arena_chains.lua
    - progression.lua

key-decisions:
  - "Kept achievements table in getDefaultData() with 4 live entries (first_merge, merge_master, merge_legend, dedicated_player) -- plan said remove entirely but live ACHIEVEMENT_CONDITIONS reference data.achievements which would nil-crash on fresh saves"
  - "Cleaned dead high-score logic from onPoints() and onGameEnd() as auto-fix -- functions wrote to removed stats fields"
  - "Migration v1 nils dead achievement entries individually rather than wiping table, preserving live achievement progress"

patterns-established:
  - "Schema versioning: CURRENT_SCHEMA_VERSION constant + MIGRATIONS table at top of progression.lua"
  - "Migration ordering: runMigrations() called BEFORE mergeWithDefaults() in load()"
  - "Migration idempotency: each migration nils dead fields and restructures, safe to re-run"

requirements-completed: [CLN-01, CLN-02, CLN-04]

# Metrics
duration: 6min
completed: 2026-04-05
---

# Phase 1 Plan 1: Dead Code Removal and Save Schema Versioning Summary

**Removed 6 dead classic-mode files (2457 lines), cleaned progression schema of 14 stale fields, and added save migration v1 infrastructure**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-05T14:53:29Z
- **Completed:** 2026-04-05T14:59:20Z
- **Tasks:** 2
- **Files modified:** 2 modified, 6 deleted

## Accomplishments
- Fixed arena_chains.lua rollDrop() to read max_coin_reached from progression.lua instead of dead upgrades.lua
- Deleted 6 dead classic-mode files: game.lua, game_screen.lua, upgrades.lua, upgrades_screen.lua, currency.lua, emoji.lua (2457 lines removed)
- Cleaned progression.lua getDefaultData() of 14 stale fields (currency, dead unlocks, dead upgrades sub-fields, dead stats)
- Added CURRENT_SCHEMA_VERSION = 1 with MIGRATIONS table and runMigrations() function
- Migration v1 strips stale fields from old saves before mergeWithDefaults fills new fields
- Removed dead getCurrencyData/setCurrencyData accessor functions

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix arena_chains.lua dead reference and delete 6 dead files** - `8cda672` (feat)
2. **Task 2: Clean progression schema and add save versioning with migration v1** - `e4b4831` (feat)

## Files Created/Modified
- `arena_chains.lua` - Fixed rollDrop() quality bonus to read from progression.lua instead of dead upgrades.lua
- `progression.lua` - Cleaned schema defaults, added versioning/migration infrastructure, removed dead accessors
- `game.lua` - Deleted (dead classic mode logic)
- `game_screen.lua` - Deleted (dead classic mode screen)
- `upgrades.lua` - Deleted (dead houses/rows/columns shop data)
- `upgrades_screen.lua` - Deleted (dead shop screen UI)
- `currency.lua` - Deleted (dead shard/crystal economy)
- `emoji.lua` - Deleted (dead food emoji canvas icons)

## Decisions Made
- Kept achievements table with 4 live entries in getDefaultData() despite plan saying remove entirely -- live ACHIEVEMENT_CONDITIONS functions index data.achievements which would crash on nil for fresh saves
- Migration v1 removes dead achievement entries individually (color_collector, point_hunter) rather than wiping the whole achievements table
- Cleaned dead mode parameter and high-score scoreKey logic from onPoints() and onGameEnd() since highest_score_classic/highest_score_2048 stats were removed

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Kept achievements in getDefaultData() with live entries only**
- **Found during:** Task 2 (Clean progression schema)
- **Issue:** Plan specified removing entire `achievements` table from getDefaultData(), but 4 live ACHIEVEMENT_CONDITIONS (first_merge, merge_master, merge_legend, dedicated_player) index `data.achievements[name]` which would throw nil index error on fresh saves
- **Fix:** Kept achievements table with only the 4 live entries. Updated migration v1 to nil dead entries individually instead of wiping table.
- **Files modified:** progression.lua
- **Verification:** All achievement condition functions can safely access data.achievements
- **Committed in:** e4b4831 (Task 2 commit)

**2. [Rule 1 - Bug] Cleaned dead high-score logic from onPoints() and onGameEnd()**
- **Found during:** Task 2 (Clean progression schema)
- **Issue:** onPoints() had unused scoreKey variable referencing dead stats. onGameEnd() called updateHighScore() with dead stat keys (highest_score_classic/highest_score_2048) that were removed from defaults and migration.
- **Fix:** Removed dead mode parameter and scoreKey/updateHighScore logic from both functions. Extra args from callers are harmlessly ignored by Lua.
- **Files modified:** progression.lua
- **Verification:** grep confirms no remaining references to dead stats outside migration
- **Committed in:** e4b4831 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2x Rule 1 - bug prevention)
**Impact on plan:** Both auto-fixes prevent runtime crashes and dead code accumulation. No scope creep.

## Issues Encountered
None

## Known Stubs
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Codebase is clean of dead classic-mode references
- progression.lua has migration infrastructure ready for future schema changes (add MIGRATIONS[2], bump CURRENT_SCHEMA_VERSION)
- Ready for plan 01-02 (remaining cleanup tasks)

## Self-Check: PASSED

All files verified (2 modified exist, 6 deleted confirmed absent, SUMMARY exists). Both commit hashes (8cda672, e4b4831) found in git log.

---
*Phase: 01-cleanup-and-prep*
*Completed: 2026-04-05*
