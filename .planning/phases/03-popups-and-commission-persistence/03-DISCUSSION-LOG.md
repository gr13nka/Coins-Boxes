# Phase 3: Popups and Commission Persistence - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-04-06
**Phase:** 03-popups-and-commission-persistence
**Areas discussed:** Popup tiers & layout, Popup interaction, Commission lifecycle, Commission quest UI

---

## Popup Tiers & Layout

### Toast presentation

| Option | Description | Selected |
|--------|-------------|----------|
| Floating text (current style) | Keep existing rising/fading text popups -- lightweight, already implemented | |
| Bottom bar toast | Slide-in bar at bottom of screen, auto-dismisses after ~2s | |
| Top banner toast | Slide-in banner from top of screen, auto-dismisses after ~2s | ✓ |

**User's choice:** Top banner toast
**Notes:** None

### Medium card presentation

| Option | Description | Selected |
|--------|-------------|----------|
| Centered card with dimmed bg | Card centered on screen (~60% width) with semi-transparent dimmed background, accept button | ✓ |
| Slide-up panel | Panel slides up from bottom covering ~40% of screen | |
| Expanding from source | Card expands from trigger point to center screen | |

**User's choice:** Centered card with dimmed background
**Notes:** None

### Celebration presentation

| Option | Description | Selected |
|--------|-------------|----------|
| Full-screen overlay | Full-screen celebration with particle burst + large card | |
| Large centered card + effects | Same as medium but larger (~80%), with radial star burst and overlay flash | ✓ |
| You decide | Claude picks approach | |

**User's choice:** Large centered card + effects
**Notes:** None

### Tier mapping

| Option | Description | Selected |
|--------|-------------|----------|
| Granular mapping | Toast: fuel/stars, drops. Card: chests, level ups, orders. Celebration: commissions, achievements | |
| Minimal celebrations | Fewer celebration triggers | |
| Generous celebrations | More celebration triggers | |
| Custom (user-provided) | See notes below | ✓ |

**User's choice:** Custom mapping
**Notes:** "The fuel and stars should just animate icon fly up, chest drop too. The commission completion a drop notification and achievements medium, level up huge." Mapping: fly-to-bar only (fuel/stars, chest drops), toast (commissions, drops), medium card (achievements), celebration (level ups).

---

## Popup Interaction

### Gameplay pause

| Option | Description | Selected |
|--------|-------------|----------|
| Pause gameplay | Freeze animations and timers while popup visible | |
| Keep running | Game continues in background | |
| Pause medium only | Different behavior per tier | |
| Custom (user-provided) | See notes below | ✓ |

**User's choice:** No pause -- game is turn-based, timers keep running, input blocked while popup visible
**Notes:** "the gameplay is turn based so keep timers of energy refill and generators continue running while popup"

### Queue behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Sequential with brief delay | One at a time, ~0.3s pause between. Toasts can overlap, cards/celebrations one-at-a-time | ✓ |
| Strict one-at-a-time | Every popup waits for previous | |
| Toasts immediate, cards queued | Toasts coexist with cards | |

**User's choice:** Sequential with brief delay
**Notes:** None

### Toast dismiss

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-dismiss after ~2s | No tap needed | |
| Auto-dismiss + tap to skip | Auto-dismiss after ~2s, tap anywhere dismisses immediately | ✓ |
| Stay until tapped | Must tap to dismiss | |

**User's choice:** Auto-dismiss + tap to skip
**Notes:** None

---

## Commission Lifecycle

### Refresh policy

| Option | Description | Selected |
|--------|-------------|----------|
| On completion only | Each commission refreshes individually when completed | |
| Batch refresh on all complete | Both refresh together when BOTH completed | ✓ |
| Timer-based (daily) | Real-time timer refresh | |

**User's choice:** Batch refresh on all complete
**Notes:** None

### Reward collection

| Option | Description | Selected |
|--------|-------------|----------|
| Immediately on completion | Auto-grant rewards on completion | |
| On game over (current) | Keep current game over collection | |
| Manual collect via UI | Collect button appears on completion | ✓ |

**User's choice:** Manual collect via UI
**Notes:** None

### Difficulty scaling

| Option | Description | Selected |
|--------|-------------|----------|
| Scale with max_coin_reached (current) | Existing progression-based scaling | |
| Scale with total commissions completed | Lifetime completed count, gradual harder commissions | ✓ |
| You decide | Claude picks approach | |

**User's choice:** Scale with total commissions completed
**Notes:** None

---

## Commission Quest UI

### Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Inline panel (improved current) | Below resource HUD in CS, redesigned with progress bars and badges | ✓ |
| Slide-out side panel | Tappable icon opens side panel | |
| Dedicated section above grid | Visible strip between HUD and grid | |

**User's choice:** Inline panel (improved current)
**Notes:** None

### Visual elements (multi-select)

| Option | Description | Selected |
|--------|-------------|----------|
| Progress bar | Horizontal fill bar showing goal progress | ✓ |
| Difficulty badge | Colored label (green/yellow/red) | ✓ |
| Reward preview | Small icons showing bags + stars earned | ✓ |
| Collect button | Tappable button on completion | ✓ |

**User's choice:** All four elements selected
**Notes:** None

---

## Claude's Discretion

- Toast animation timing curves and exact banner height
- Medium/celebration card internal layout
- Queue transition animations
- Commission data structure for progression.dat
- Collect button animation
- Order completion popup tier
- Toast vertical stacking behavior

## Deferred Ideas

- COM-F01: Cross-mode commission visibility -- v2
- COM-F02: Timer-based refresh policy -- v2
