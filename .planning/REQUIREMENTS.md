# Requirements: Coins & Boxes

**Defined:** 2026-04-05
**Core Value:** The satisfying merge loop with immediate visual+audio feedback where both modes feed into each other

## v1.0 Requirements

Requirements for release. Each maps to roadmap phases.

### Cleanup

- [ ] **CLN-01**: Dead code removed — 6 classic mode files deleted, `arena_chains.lua:286` fixed to not require dead `upgrades.lua`
- [ ] **CLN-02**: Stale progression schema cleaned — unused fields (`currency`, `unlocks`, `upgrades_data`) removed from `getDefaultData()`
- [ ] **CLN-03**: Dead `coin_sort.merge()` function removed (duplicate of `executeMergeOnBox()`)
- [ ] **CLN-04**: Save schema versioning added — `schema_version` field in progression.dat with migration support
- [ ] **CLN-05**: Double merge mechanic implemented — next CS merge produces double output when charge is active

### Effects

- [ ] **FX-01**: Particle system redesigned with tiered quality (HIGH/MED/LOW) and reduced GC pressure for web
- [ ] **FX-02**: Web performance verified — particles run at 50-60fps on browser/WASM during peak effects
- [ ] **FX-03**: Merge celebration effects — particles, screen shake enhancement, coin fly-up on merge (both CS and Arena)
- [ ] **FX-04**: Chest/reward effects — particles on chest open, star gain animations, fuel gain animations
- [ ] **FX-05**: Button/UI polish — button press feedback, hover glow, tab bar transition effects

### Tutorials

- [ ] **TUT-01**: Spotlight overlay system — blacked screen with lit interaction zone, input blocked outside zone
- [ ] **TUT-02**: Coin Sort tutorial — pick, place, merge, deal sequence (~5 steps, no skip)
- [ ] **TUT-03**: Arena tutorial rebuilt in spotlight style — replacing current 18-step state machine
- [ ] **TUT-04**: Board state validation per tutorial step — preconditions checked to prevent soft-locks

### Commissions

- [ ] **COM-01**: Commissions persist across sessions — saved/loaded via progression.dat
- [ ] **COM-02**: Commission progress UI improved — trackable quest list visible during gameplay

### Popups

- [ ] **POP-01**: Tiered popup system — small toast (minor), medium card (moderate), full celebration (big moments)
- [ ] **POP-02**: Reward popups on level ups, chest drops, and commission completions with accept button
- [ ] **POP-03**: Popup queue — multiple rewards queued and shown sequentially, not stacked

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Commissions

- **COM-F01**: Cross-mode commission visibility — commissions from one mode visible in the other
- **COM-F02**: Commission refresh policy — timer-based or completion-based refresh for persistent commissions

### Social

- **SOC-F01**: Yandex Games leaderboards integration
- **SOC-F02**: Player profile / avatar display

## Out of Scope

| Feature | Reason |
|---------|--------|
| Real-time multiplayer | Not needed for v1.0 |
| New game modes | Polish existing before adding |
| New skill tree nodes | Current 30 nodes sufficient for release |
| iOS/Android native builds | Web-first for Yandex Games |
| OAuth/social login | Yandex handles auth on their platform |
| Skip button for tutorials | Design decision — players must complete tutorial |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CLN-01 | Phase 1 | Pending |
| CLN-02 | Phase 1 | Pending |
| CLN-03 | Phase 1 | Pending |
| CLN-04 | Phase 1 | Pending |
| CLN-05 | Phase 1 | Pending |
| FX-01 | Phase 2 | Pending |
| FX-02 | Phase 2 | Pending |
| FX-03 | Phase 2 | Pending |
| FX-04 | Phase 2 | Pending |
| FX-05 | Phase 2 | Pending |
| TUT-01 | Phase 4 | Pending |
| TUT-02 | Phase 4 | Pending |
| TUT-03 | Phase 4 | Pending |
| TUT-04 | Phase 4 | Pending |
| COM-01 | Phase 3 | Pending |
| COM-02 | Phase 3 | Pending |
| POP-01 | Phase 3 | Pending |
| POP-02 | Phase 3 | Pending |
| POP-03 | Phase 3 | Pending |

**Coverage:**
- v1.0 requirements: 19 total
- Mapped to phases: 19
- Unmapped: 0

---
*Requirements defined: 2026-04-05*
*Last updated: 2026-04-05 after roadmap creation*
