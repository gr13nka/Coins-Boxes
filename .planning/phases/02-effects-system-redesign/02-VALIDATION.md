---
phase: 2
slug: effects-system-redesign
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-05
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual visual testing + FPS counter + grep/file-existence checks (LOVE2D game — no automated test framework) |
| **Config file** | None |
| **Quick run command** | `love /home/username/Documents/Coins-Boxes/` |
| **Full suite command** | `love /home/username/Documents/Coins-Boxes/` + manual verification of all effects |
| **Estimated runtime** | ~60 seconds (manual visual smoke test) |

---

## Sampling Rate

- **After every task commit:** Run automated grep/file-existence verify commands + quick visual smoke test via `love .`
- **After every plan wave:** Web build + browser FPS verification (`cd love-web-builder-main && ./build.sh ..`)
- **Before `/gsd-verify-work`:** Full manual verification of all 5 requirements + web FPS baseline comparison
- **Max feedback latency:** ~2 seconds (grep commands are instant)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | FX-01 | — | N/A | grep+exist | `grep -c "TIER_CONFIG" particles.lua && grep -c "getPerformanceTier" mobile.lua particles.lua` | N/A | ⬜ pending |
| 02-01-02 | 01 | 1 | FX-01 | — | N/A | grep+exist | `test -f effects.lua && grep -c "function effects.init" effects.lua && grep -c "function effects.spawnFlyToBar" effects.lua && grep -c "function effects.spawnResourceFly" effects.lua` | N/A | ⬜ pending |
| 02-02-01 | 02 | 2 | FX-03 | — | N/A | grep | `grep -c "function animation.triggerShake" animation.lua && grep -c "function animation.getShakeIntensity" animation.lua` | N/A | ⬜ pending |
| 02-02-02 | 02 | 2 | FX-03, FX-04 | — | N/A | grep | `grep -c "MERGE_CELEBRATION" coin_sort_screen.lua && grep -c "fly_ups" coin_sort_screen.lua && grep -c "spawnResourceFly" coin_sort_screen.lua && grep -c "setResourceBarTargets" coin_sort_screen.lua` | N/A | ⬜ pending |
| 02-03-01 | 03 | 2 | FX-03 | — | N/A | grep | `grep -c "dissolve_out" arena_screen.lua && grep -c "chest_shakes" arena_screen.lua && grep -c "effects.spawnBurst" arena_screen.lua` | N/A | ⬜ pending |
| 02-03-02 | 03 | 2 | FX-04 | — | N/A | grep+wc | `grep -c "PILL_START_X" arena_screen.lua && grep -c "spawnResourceFly" arena_screen.lua && wc -l arena_screen.lua` | N/A | ⬜ pending |
| 02-04-01 | 04 | 3 | FX-05 | — | N/A | grep | `grep -c "highlight_x" tab_bar.lua && grep -c "BUTTON_OVERSHOOT" coin_sort_screen.lua` | N/A | ⬜ pending |
| 02-04-02 | 04 | 3 | FX-05 | — | N/A | grep+wc | `grep -c "is_generator\|gen_scale" arena_screen.lua && grep -c "can_complete\|glow_t" arena_screen.lua && wc -l arena_screen.lua` | N/A | ⬜ pending |
| 02-05-01 | 05 | 4 | FX-02 | — | N/A | exist+grep | `ls love-web-builder-main/build/ && grep -c "getFPS" main.lua` | N/A | ⬜ pending |
| 02-05-02 | 05 | 4 | FX-02 | — | N/A | human-verify | `echo "Human verification checkpoint -- no automated test"` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No automated test framework needed for a LOVE2D game — all verification uses grep/file-existence checks for structural correctness and visual + FPS counter for behavioral correctness.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Tier detection selects correct tier | FX-01 | Platform detection requires running on actual platform; no automated platform switching | Run on desktop (verify HIGH), web build (verify MED), mobile build (verify LOW) |
| 50-60fps during peak effects on web | FX-02 | Requires browser runtime + visual frame rate observation | Build web, open in browser, trigger multi-box merge, read FPS counter |
| CS merge celebrations scale with level | FX-03 | Visual effect intensity requires human judgment | Merge coins at L2, L4, L6 — verify particle count and shake increase |
| Coin fly-up arc on CS merge | FX-03 | Animation arc requires visual verification | Merge coins — verify merged result does upward arc before settling |
| Arena merge uses glow/dissolve not fragments | FX-03 | Visual style distinction requires human observation | Arena: merge two items, verify dissolve animation (not coin-style fragments) |
| Chest open shake+pop+particles | FX-04 | Multi-phase animation sequence requires visual verification | Tap chest in Arena, verify: 1) shake, 2) lid pop particles, 3) item reveal |
| Fly-to-bar icons reach resource bar (CS) | FX-04 | Spatial animation targeting requires visual verification | Merge in CS, verify fuel/star icons fly from merge point to correct resource bar |
| Fly-to-bar icons reach resource bar (Arena) | FX-04 | Spatial animation targeting requires visual verification | Complete order in Arena, verify star icons fly from order card to resource bar |
| Big reward flash is distinct from normal | FX-04 | Subjective "feels different" — but objectively: overlay flash visible | Complete a level, verify full-screen flash occurs |
| Button scale bounce on press | FX-05 | Touch/press feedback requires interaction | Tap Add/Merge buttons, verify visual shrink-bounce |
| Tab highlight slides smoothly | FX-05 | Animation smoothness requires visual observation | Switch tabs, verify highlight bar slides (not jumps) |
| Generator pulse and order glow | FX-05 | Subtle visual feedback requires observation | In Arena, verify charged generators pulse, completed orders glow |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify commands (grep/file-existence checks)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (none needed)
- [x] No watch-mode flags
- [x] Feedback latency < 5s (grep commands are instant)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
