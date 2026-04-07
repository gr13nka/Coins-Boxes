# Coins & Boxes

## What This Is

A mobile/web merge puzzle game with two interlocking modes — Coin Sort (merge numbered coins in a grid) and Merge Arena (combine kitchen items to fulfill orders). Built with LOVE2D/Lua, targeting Yandex Games as the primary web platform. Players earn resources in one mode to progress in the other.

## Core Value

The satisfying merge loop: picking, placing, and merging coins/items with immediate visual+audio feedback, where both modes feed into each other creating a "just one more turn" cycle.

## Current Milestone: v1.0 Release Polish

**Goal:** Get Coins & Boxes release-ready with optimized performance, guided tutorials, persistent commissions, reward popups, and visual polish across both game modes.

**Target features:**
- Effects system redesign for web performance + new visual effects
- Coin Sort tutorial (spotlight-style, controlled interaction)
- Arena tutorial rebuild (spotlight-style, replacing current 18-step)
- Persistent commissions visible from both modes
- Reward popups for big moments

## Requirements

### Validated

<!-- Shipped and confirmed valuable. Inferred from existing codebase. -->

- Coin Sort mode with 3x5 grid, bag-based dealing, merge mechanics (v0.9)
- Merge Arena with 7x8 grid, 12 item chains, generators, orders (v0.9)
- Skill tree with 30 nodes, star-based unlocks (v0.9)
- Cross-mode resource flow: Fuel, Stars, Bags, Drops, Chests (v0.9)
- Arena tutorial (18-step, functional but being replaced) (v0.9)
- Commission system (per-session, 2 per game) (v0.9)
- Yandex Games SDK integration (ads) (v0.9)
- Save/load via progression.dat (v0.9)
- Tab bar navigation between modes (v0.9)

### Active

<!-- Current scope. Building toward these for v1.0. -->

- [x] Redesigned effects/particle system optimized for web — Validated in Phase 2: Effects System Redesign
- [x] New visual effects (merges, chest opens, star gains, buttons) — Validated in Phase 2: Effects System Redesign
- [ ] Coin Sort spotlight tutorial (pick, place, merge, deal)
- [ ] Arena spotlight tutorial rebuild
- [ ] Persistent cross-session commissions
- [ ] Commission UI visible from both modes
- [ ] Reward popups for big moments (level ups, chests, commission completions)

### Out of Scope

<!-- Explicit boundaries. -->

- Real-time multiplayer — not needed for v1.0
- New game modes — polish existing before adding
- Monetization beyond Yandex ads — defer to post-release
- iOS/Android native builds — web-first for Yandex Games
- New skill tree nodes — current 30 nodes sufficient for release

## Context

- **Platform:** Web (Yandex Games) is the primary target. Emscripten/WASM via love-web-builder.
- **Performance:** Current particle system causes lag on web during Coin Sort. Effects redesign must stay within web perf budget.
- **Status:** In development, pre-release. Save compatibility with v0.9 not required.
- **Dead code:** Cleaned in Phase 1 — 6 classic-mode files removed, save schema versioned.
- **Effects system:** Rebuilt in Phase 2 — 3-tier perf detection, tiered particles, effects.lua pools, mode-specific celebrations.
- **Known bugs:** Tutorial step 8/9 duplicate handlers, drag position stutter on web.

## Constraints

- **No goto:** Breaks web build (Emscripten limitation). Use repeat/until for retries.
- **Logic/visual separation:** Data modules have zero drawing code; screen modules handle all rendering.
- **Web performance:** All effects must run smoothly at 50-60fps on browser/WASM.
- **LOVE2D 12.0:** Pinned to main branch commit cdf68b3.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Web-first (Yandex Games) | Primary distribution platform | — Pending |
| Spotlight tutorial style | Ensures players learn mechanics, no way to skip or get lost | — Pending |
| Persistent commissions | Per-session model loses progress on exit, frustrating | — Pending |
| Effects system redesign (not patch) | Current system lags on web, adding more effects on top would make it worse | ✓ Phase 2 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-05 after Phase 2 (Effects System Redesign) completion*
