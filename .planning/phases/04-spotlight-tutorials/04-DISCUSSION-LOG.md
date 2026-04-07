# Phase 4: Spotlight Tutorials - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-04-07
**Phase:** 04-spotlight-tutorials
**Areas discussed:** Spotlight visual style, CS tutorial steps, Arena tutorial scope, Instruction delivery

---

## Spotlight Visual Style

### Cutout shape

| Option | Description | Selected |
|--------|-------------|----------|
| Rounded rectangle | Matches box/cell aesthetic, clean and consistent | ✓ |
| Circle spotlight | Classic spotlight feel, may clip rectangular UI | |
| No cutout, highlight only | Glow border on target, dimmed background | |

**User's choice:** Rounded rectangle
**Notes:** Matches existing game visual language

### Cutout edge

| Option | Description | Selected |
|--------|-------------|----------|
| Subtle glow border | Soft light glow around cutout edge | |
| Clean hard edge | Sharp transition, minimal | |
| Animated pulse border | Border gently pulses brightness | ✓ |

**User's choice:** Animated pulse border
**Notes:** None

### Overlay darkness

| Option | Description | Selected |
|--------|-------------|----------|
| Heavy dim (~80%) | Strong focus, game barely visible | |
| Medium dim (~60%) | Target stands out, game still partially visible | ✓ |
| Light dim (~40%) | Game remains quite visible | |

**User's choice:** Medium dim (~60% black)
**Notes:** None

### Target transitions

| Option | Description | Selected |
|--------|-------------|----------|
| Smooth slide | Cutout moves/resizes over ~0.3s | ✓ |
| Snap with fade | Old fades out, new fades in | |
| Instant snap | Jumps immediately | |

**User's choice:** Smooth slide
**Notes:** None

---

## CS Tutorial Steps

### Board setup

| Option | Description | Selected |
|--------|-------------|----------|
| Pre-set small board | Reduced grid, expand after tutorial | |
| Full 3x5 with pre-set coins | Normal grid, hand-placed coins | ✓ |
| Full 3x5 with normal deal | Random coins, spotlight whatever lands | |

**User's choice:** Full 3x5 with pre-set coins
**Notes:** None

### Step count

| Option | Description | Selected |
|--------|-------------|----------|
| ~5 steps | Pick, place, merge, deal, free play | ✓ |
| ~8 steps | More granular with resource gains, bags, commissions | |
| ~3 steps (minimal) | Ultra-compressed | |

**User's choice:** ~5 steps
**Notes:** Step 3 is specifically pressing the Merge button so a full box merges

### Merge setup

| Option | Description | Selected |
|--------|-------------|----------|
| Pick/place fills the box | Board almost full, player completes it then merges | ✓ |
| Box pre-filled, just press Merge | One box already full at start | |
| You decide | Claude chooses | |

**User's choice:** Pick/place fills the box
**Notes:** Satisfying cause-and-effect chain across steps 1-3

---

## Arena Tutorial Scope

### Rebuild approach

| Option | Description | Selected |
|--------|-------------|----------|
| Keep same 18-step progression | Same sequence, add spotlight presentation | |
| Simplify to ~10 steps | Cut redundancy, consolidate | |
| Redesign from scratch (~8 steps) | Rethink what's essential | ✓ |

**User's choice:** Redesign from scratch (~8 steps)
**Notes:** None

### Essential concepts

| Option | Description | Selected |
|--------|-------------|----------|
| Dispenser tap -> item placement | Foundation mechanic | ✓ |
| Merge same items | Core gameplay loop | ✓ |
| Sealed cells + box reveals | Progression mechanic | ✓ |
| Generator tap (costs fuel) | Connects fuel resource to arena | ✓ |

**User's choice:** All four selected
**Notes:** None

### Orders + Stash

| Option | Description | Selected |
|--------|-------------|----------|
| Teach orders, skip stash | Orders are the goal mechanic | |
| Teach both | Both get spotlight steps | ✓ |
| Skip both | Focus on core merge loop | |

**User's choice:** Teach both
**Notes:** None

### Board layout

| Option | Description | Selected |
|--------|-------------|----------|
| Keep current initial board | Proven 7x8 layout with boxes/sealed | ✓ |
| Custom simplified board | Redesign starting grid | |

**User's choice:** Keep current initial board
**Notes:** None

### Tutorial drops

| Option | Description | Selected |
|--------|-------------|----------|
| Keep existing hardcoded drops | Da1/Me1 sequence | ✓ |
| Redesign drop sequence | Different items for new flow | |
| You decide | Claude picks | |

**User's choice:** Keep existing hardcoded drops
**Notes:** None

### Old tutorial removal

| Option | Description | Selected |
|--------|-------------|----------|
| Remove completely | Clean break, no dead code | ✓ |
| Keep as commented reference | Comment out for dev reference | |

**User's choice:** Remove completely
**Notes:** Phase 1 already cleaned dead code for good reason

---

## Instruction Delivery

### Text style

| Option | Description | Selected |
|--------|-------------|----------|
| Speech bubble + arrow | Classic mobile tutorial pattern | |
| Floating text above/below | Clean and minimal | |
| Hand icon + minimal text | Visual-first, cross-language friendly | ✓ |

**User's choice:** Hand icon + minimal text
**Notes:** None

### Hand animation

| Option | Description | Selected |
|--------|-------------|----------|
| Animated tap | Tapping motion repeating ~1.5s | ✓ (for tap steps) |
| Static point | Hand stays still | |
| Animated + trail | Drag motion for drag steps | ✓ (for drag steps) |

**User's choice:** Animated tap for taps, animated drag trail for drags. Use pointing hand emoji style.
**Notes:** User specified pointing hand emoji aesthetic

### Text position

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-position | Above or below, whichever has more space | ✓ |
| Always above | Consistent but may crowd top | |
| Always below | Consistent but may crowd bottom | |

**User's choice:** Auto-position (initially selected "Always above", then changed to auto-position to avoid overlap issues)
**Notes:** None

### Localization

| Option | Description | Selected |
|--------|-------------|----------|
| English only | Simple for v1.0 | |
| Russian + English | Yandex Games targets Russian audience | ✓ |
| Localization-ready structure | English only but prepared for translations | |

**User's choice:** Russian + English
**Notes:** Primary platform is Yandex Games (Russian audience)

---

## Claude's Discretion

- Exact pre-set coin layout for CS tutorial board
- Stencil vs canvas approach for spotlight rendering
- Exact Arena tutorial step count (6-8 range)
- Step ordering for Arena concepts
- Pulse border timing/color
- Hand icon animation curves
- Board state validation strategy
- Localization string format
- Tutorial persistence format

## Deferred Ideas

None -- discussion stayed within phase scope
