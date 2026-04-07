---
phase: 1
slug: cleanup-and-prep
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-05
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual verification (no test framework — Lua/LOVE2D game) |
| **Config file** | none |
| **Quick run command** | `grep -r "require" *.lua \| grep -v "^--"` (static analysis) |
| **Full suite command** | `love . --test` (manual game launch verification) |
| **Estimated runtime** | ~5 seconds (static), ~30 seconds (manual launch) |

---

## Sampling Rate

- **After every task commit:** Run static grep checks for dead requires
- **After every plan wave:** Launch game and verify no runtime errors
- **Before `/gsd-verify-work`:** Full manual launch + save/load cycle
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 1 | CLN-01 | — | N/A | static | `grep -r "require.*game\b\|require.*upgrades\b\|require.*currency\b\|require.*emoji\b" *.lua` | N/A | ⬜ pending |
| 1-01-02 | 01 | 1 | CLN-02 | — | N/A | static | `grep "currency\|unlocks\|upgrades_data" progression.lua` | N/A | ⬜ pending |
| 1-01-03 | 01 | 1 | CLN-04 | — | N/A | static | `grep "schema_version" progression.lua` | N/A | ⬜ pending |
| 1-02-01 | 02 | 1 | CLN-03 | — | N/A | static | `grep "function.*merge\b" coin_sort.lua` | N/A | ⬜ pending |
| 1-02-02 | 02 | 1 | CLN-05 | — | N/A | static | `grep "double_merge" coin_sort.lua` | N/A | ⬜ pending |

*Status: ⬜ pending*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework needed — all verification is static grep analysis and manual game launch.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Game launches without errors | CLN-01 | Requires LOVE2D runtime | Run `love .`, verify no error screen |
| Save migration preserves data | CLN-04 | Requires old save file + runtime | Create save, add schema_version, reload, verify data intact |
| Double merge produces double output | CLN-05 | Requires gameplay interaction | Activate double merge charge, perform merge, count output coins |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
