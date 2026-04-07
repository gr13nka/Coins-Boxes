# Roadmap: Coins & Boxes

## Overview

Coins & Boxes v1.0 takes the working v0.9 codebase and makes it release-ready. The path goes: remove dead code and fix save fragility (Phase 1), redesign the effects system for web performance (Phase 2), build popup infrastructure and make commissions persistent (Phase 3), then implement spotlight tutorials for both game modes (Phase 4). Each phase builds on the prior -- cleanup removes landmines, effects provides visual foundation, popups provide reward feedback, and tutorials tie it all together for new players.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Cleanup and Prep** - Remove dead code, fix save schema, implement double merge
- [ ] **Phase 2: Effects System Redesign** - Rebuild particles for web performance, add new visual effects
- [ ] **Phase 3: Popups and Commission Persistence** - Tiered popup system, persistent commissions with UI
- [ ] **Phase 4: Spotlight Tutorials** - Spotlight overlay system, CS tutorial, Arena tutorial rebuild

## Phase Details

### Phase 1: Cleanup and Prep
**Goal**: The codebase is free of dead code, save data is versioned and migratable, and the double merge mechanic works
**Depends on**: Nothing (first phase)
**Requirements**: CLN-01, CLN-02, CLN-03, CLN-04, CLN-05
**Success Criteria** (what must be TRUE):
  1. Game launches without requiring any dead/classic-mode modules -- no runtime errors from stale requires
  2. Save file includes a schema version and the game can migrate older save formats without data loss
  3. When a double merge charge is active, the next Coin Sort merge produces double output coins
  4. No unused functions or progression fields remain that could confuse future development
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md — Dead code removal, schema cleanup, save versioning with migration v1
- [x] 01-02-PLAN.md — Dead merge function removal, double merge mechanic implementation

### Phase 2: Effects System Redesign
**Goal**: Visual effects run smoothly on web at 50-60fps and new celebration/reward effects enhance the merge experience
**Depends on**: Phase 1
**Requirements**: FX-01, FX-02, FX-03, FX-04, FX-05
**Success Criteria** (what must be TRUE):
  1. Particle effects during peak merge activity maintain 50-60fps in a browser/WASM build (not just desktop)
  2. Coin Sort merges produce visible celebration particles and enhanced screen shake
  3. Arena merges, chest opens, and resource gains have corresponding visual effects (particles, fly-ups, animations)
  4. Buttons and UI elements respond to interaction with visible feedback (press, hover/glow, tab transitions)
  5. Effect quality automatically scales based on platform capability (HIGH/MED/LOW tiers)
**Plans**: 5 plans

Plans:
- [x] 02-01-PLAN.md — Foundation: 3-tier performance system, particles.lua tiered redesign, effects.lua module
- [x] 02-02-PLAN.md — CS merge celebrations: level-scaled particles, enhanced shake, flash effects
- [x] 02-03-PLAN.md — Arena effects: merge glow/dissolve, chest open sequence, fly-to-bar icons, big reward flash
- [x] 02-04-PLAN.md — UI polish: tab bar sliding highlight, button bounce, generator pulse, order glow
- [x] 02-05-PLAN.md — Web performance verification: build + FPS testing checkpoint

### Phase 3: Popups and Commission Persistence
**Goal**: Players see rewarding popups for big moments and commissions survive across sessions
**Depends on**: Phase 2
**Requirements**: POP-01, POP-02, POP-03, COM-01, COM-02
**Success Criteria** (what must be TRUE):
  1. Level ups, chest drops, and commission completions trigger appropriately-sized popups (toast/card/celebration)
  2. Multiple simultaneous rewards display sequentially in a queue -- never stacked or lost
  3. Closing and reopening the game preserves commission progress exactly where it was
  4. Commission progress is visible as a trackable quest list during gameplay
**Plans**: 3 plans

Plans:
- [x] 03-01-PLAN.md — Popup system module: toast/card/celebration tiers, FIFO queue, rendering
- [x] 03-02-PLAN.md — Commission persistence: save/load, manual collect, batch refresh, difficulty scaling
- [x] 03-03-PLAN.md — Commission quest panel UI redesign + popup trigger wiring into both screens

### Phase 4: Spotlight Tutorials
**Goal**: New players learn both game modes through guided spotlight tutorials that prevent confusion and soft-locks
**Depends on**: Phase 3
**Requirements**: TUT-01, TUT-02, TUT-03, TUT-04
**Success Criteria** (what must be TRUE):
  1. A spotlight overlay blacks out the screen except for the interaction target, and input outside the lit zone is blocked
  2. A new Coin Sort player is guided through pick, place, merge, and deal in sequence without being able to get lost
  3. The Arena tutorial teaches the same concepts as the current 18-step version but uses the spotlight system instead of implicit state
  4. Each tutorial step validates board state preconditions before proceeding -- no soft-lock states are reachable
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Cleanup and Prep | 0/2 | Planned | - |
| 2. Effects System Redesign | 0/5 | Planned | - |
| 3. Popups and Commission Persistence | 0/3 | Planned | - |
| 4. Spotlight Tutorials | 0/0 | Not started | - |
