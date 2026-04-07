# Research Summary: Coins & Boxes v1.0 Release Polish

**Domain:** Feature integration architecture for LOVE2D/Lua merge puzzle game
**Researched:** 2026-04-05
**Overall confidence:** HIGH

## Executive Summary

The v1.0 milestone adds four features to an existing, architecturally consistent codebase: a redesigned effects system, spotlight tutorials for both game modes, persistent cross-session commissions, and modal reward popups. The existing architecture -- module-per-concern with hard logic/visual separation, single-active-screen state machine, and centralized persistence through `progression.lua` -- accommodates all four features without structural changes. The new features follow established patterns: pure-data logic modules for state, screen modules for rendering, fire-and-forget helper modules for visual effects.

The research identified four new modules (`effects.lua`, `spotlight.lua`, `popups.lua`, `cs_tutorial.lua`) and seven modified modules. The most significant finding is that **build order matters**: effects must come first because all other features depend on it for visual polish; the popup system must precede commissions and tutorials because both use popups for reward display; and the spotlight renderer must precede tutorial implementation. The commission persistence change is the simplest modification (adding a data slice to `progression.lua` and save/load to `commissions.lua`) and can run in parallel with spotlight development.

The primary risk is the effects system redesign breaking the existing merge/deal animation pipeline. The current `particles.lua` is wired into both screen modules and `animation.lua` at 7+ call sites. The recommended approach is to redesign the internals while preserving the existing public API signatures, then add new effect types (glows, fly-ups, trails) as additional functions. The secondary risk is spotlight tutorial soft-locks from unvalidated preconditions -- each tutorial step must verify board state before showing a spotlight cutout.

No new external dependencies are needed. All features are built with LOVE2D/Lua primitives already in use. The stencil buffer was considered for spotlight cutouts and rejected due to WebGL compatibility concerns on the Yandex Games target platform; rectangular geometry is simpler and more portable.

## Key Findings

**Stack:** No new technology. All four features use existing LOVE2D primitives (SpriteBatch, Canvas, rectangle geometry, alpha blending). Zero external dependencies.

**Architecture:** Four new modules follow existing patterns. The critical integration surface is the `draw()` and `mousepressed()` functions in each screen module, which must enforce strict z-order: game content -> effects -> HUD -> spotlight -> popups -> tab bar.

**Critical pitfall:** The effects system redesign can break the existing merge/deal animation pipeline if the `particles.lua` public API changes. The animation module stores a runtime reference to the particle module and calls `spawn()` / `spawnMergeExplosion()` by name -- changing signatures will crash mid-animation.

## Implications for Roadmap

Based on research, suggested phase structure:

1. **Prep/Cleanup Phase** - Fix prerequisites before building new features
   - Addresses: Dead `require("upgrades")` call in arena_chains.lua, duplicate `coin_sort.merge()`, `double_merge` drop type resolution, save schema versioning
   - Avoids: Pitfall 2 (dead code crash), Pitfall 4 (save corruption), Pitfall 11 (celebrating non-functional feature)

2. **Effects System Redesign** - Replace/redesign particles.lua internals
   - Addresses: Web performance bottleneck, new VFX types (fly-ups, glows, bursts)
   - Avoids: Pitfall 1 (API breakage), Pitfall 8 (GC allocation on WASM)
   - Note: Preserve existing public API signatures; add new functions for new effect types

3. **Popup System + Commission Persistence** - Build popup infrastructure, make commissions persistent
   - Addresses: Reward feedback for big moments, cross-session commission tracking, cross-mode commission visibility
   - Avoids: Pitfall 4 (save schema corruption), Pitfall 5 (input swallowing without modal stack), Pitfall 10 (cross-screen state sync)
   - Note: These can be built in parallel since they have no mutual dependency

4. **Spotlight Tutorial System** - Build spotlight renderer, then implement CS tutorial and rebuild Arena tutorial
   - Addresses: New player guidance for Coin Sort, modernized Arena tutorial
   - Avoids: Pitfall 3 (tutorial soft-locks), Pitfall 6 (file size threshold), Pitfall 7 (lost edge case handling)
   - Note: Extract tutorial code from screen modules into dedicated files before adding spotlight logic

**Phase ordering rationale:**
- Cleanup first because it removes landmines that would complicate all subsequent work (dead code references, save schema fragility, dead drop types).
- Effects second because popups, tutorials, and commissions all benefit from visual polish effects being available (entrance animations, celebration particles, highlight pulses).
- Popups and commissions third because they are infrastructure that tutorials use (commission-complete popups, tutorial-complete celebrations).
- Tutorials last because they are the most complex integration (input gating, state machines, cross-module coordination) and benefit from having all other systems in place.

**Research flags for phases:**
- Phase 2 (Effects): Likely needs deeper research on SpriteBatch performance limits on WebGL -- profile early on actual web build, not just desktop.
- Phase 4 (Tutorials): Needs detailed step-by-step design for CS tutorial (no existing tutorial to rebuild -- pure new design). Arena tutorial has 18 steps to catalog before rebuilding.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | No new technology. All primitives already used in the codebase. |
| Features | HIGH | Features are well-defined in PROJECT.md. Integration points identified from direct code inspection. |
| Architecture | HIGH | Existing module pattern is clear and consistent. New modules follow established conventions. |
| Pitfalls | HIGH | Identified from direct codebase analysis. The pre-existing PITFALLS.md has extremely detailed, code-line-level analysis. |
| Web/WASM Performance | MEDIUM | GC behavior and SpriteBatch limits on Emscripten are based on documented concerns in the codebase + general knowledge, not profiling data. |
| Stencil/WebGL compat | LOW | Recommendation to avoid stencil buffer is based on general WebGL knowledge, not Yandex-Games-specific testing. Rectangle approach is safe regardless. |

## Gaps to Address

- **CS tutorial step design**: No existing tutorial for Coin Sort. The step sequence (what to teach, in what order, with what board state) needs design work during Phase 4, not just implementation.
- **Web profiling baseline**: No performance measurements exist for the current particle system on web. Before redesigning effects, establish a baseline (FPS during merges, GC pause frequency) to measure improvement.
- **Commission refresh policy**: The research identifies that commissions should be persistent, but the specific refresh policy (timer-based, completion-based, daily reset) needs gameplay design input, not just technical design.
- **Popup visual design**: The popup content layout (where to show reward icons, how to animate entrance) needs visual design iteration that cannot be fully specified in architecture research.

---

*Research summary: 2026-04-05*
