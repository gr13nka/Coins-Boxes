---
phase: 04-spotlight-tutorials
plan: 01
status: complete
started: 2026-04-07
completed: 2026-04-07
---

## Summary

Built the reusable spotlight overlay system (tutorial.lua) that both CS and Arena tutorials depend on, plus persistence and animation integration.

## What Was Built

### tutorial.lua (362 lines, data/logic only)
- 18 public functions: isActive, getActiveTutorial, start, update, advance, registerSteps, getSpotlight, getOverlayOpacity, getPulseAlpha, getCutoutRadius, getText, getTextPosition, getHandAnim, isInputAllowed, isDone, markDone, getCurrentStep, getStepCount, getTutorialData, setLang
- Step registration system with empty coin_sort/arena tables for Plan 02/03 to populate
- Spotlight slide transitions (easeOutCubic, 0.3s), pulse border animation, hand tap/drag animations
- Localization support (en/ru, default ru for Yandex target)
- Input blocking via isInputAllowed() point-in-rect test
- Animation-idle gating via queued_advance mechanism
- Lazy require for animation and progression to avoid circular deps
- Zero love.graphics calls (logic/visual separation per CLAUDE.md)

### progression.lua changes
- Schema version bumped from 2 to 3
- MIGRATIONS[3]: adds tutorial_data = {cs_done, arena_done}, cleans up old arena_data.tutorial_step
- getDefaultData() includes tutorial_data
- getTutorialData() / setTutorialData() accessors added

### animation.lua changes
- Added isIdle() function: returns true when both pick_state and bg_state are STATE.IDLE

### main.lua changes
- Added require("tutorial") and tutorial.load() call

## Key Files

| File | Change |
|------|--------|
| tutorial.lua | Full rewrite from placeholder |
| progression.lua | Schema v3, tutorial_data migration + accessors |
| animation.lua | isIdle() accessor |
| main.lua | Tutorial module loaded at startup |

## Deviations

None.

## Self-Check: PASSED
