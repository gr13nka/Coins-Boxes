# Phase 2: Effects System Redesign - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-05
**Phase:** 02-effects-system-redesign
**Areas discussed:** Merge celebration effects, Chest & reward effects, Button & UI polish

---

## Merge celebration effects

| Option | Description | Selected |
|--------|-------------|----------|
| Satisfying pop | Enhanced particles + screen shake + brief flash. Amplify existing chunky style | ✓ |
| Over-the-top juice | Radial shockwave, flying fragments, background pulse, particle trails | |
| Subtle and clean | Minimal particles, gentle glow, soft shake | |

**User's choice:** Satisfying pop
**Notes:** Keep existing chunky fragment aesthetic, amplify it

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, escalating | Low merges small pop, high merges (L5+) full celebration | ✓ |
| Same intensity for all | Every merge feels the same regardless of level | |
| You decide | Claude picks scaling curve | |

**User's choice:** Yes, escalating
**Notes:** Rewards the player for bigger merges

| Option | Description | Selected |
|--------|-------------|----------|
| Same particle style | Consistent visual language, arena items burst like coins | |
| Mode-specific effects | Arena items glow/dissolve rather than explode | ✓ |
| You decide | Claude picks per mode | |

**User's choice:** Mode-specific effects
**Notes:** Arena items are kitchen objects, not coins — glow/dissolve fits better than explosion

---

## Chest & reward effects

| Option | Description | Selected |
|--------|-------------|----------|
| Lid pop + item reveal | Chest shakes, lid pops with chain-colored particles, item rises and settles | ✓ |
| Quick burst | Chest flashes, particles spray, item appears. Fast and functional | |
| You decide | Claude picks for tap rhythm | |

**User's choice:** Lid pop + item reveal
**Notes:** Each tap is a mini-reveal moment

| Option | Description | Selected |
|--------|-------------|----------|
| Fly-up numbers | '+2 Fuel' text floats up and fades. Clear but simple | |
| Icon fly-to-bar | Small fuel/star icons fly from merge point to resource bar | ✓ |
| Bar pulse only | Resource bar pulses on gain. Minimal | |
| You decide | Claude picks balance of visibility vs performance | |

**User's choice:** Icon fly-to-bar
**Notes:** Shows where the resource went — spatial connection between action and result

| Option | Description | Selected |
|--------|-------------|----------|
| Same style, bigger scale | Same fly-up but larger, with star particle burst | |
| Distinct celebration | Brief overlay flash or radial star burst, separate from normal | ✓ |
| You decide | Claude determines threshold | |

**User's choice:** Distinct celebration
**Notes:** Big moments should feel meaningfully different from routine gains

---

## Button & UI polish

| Option | Description | Selected |
|--------|-------------|----------|
| Scale bounce | Shrinks to 95%, bounces back with overshoot. Tactile | ✓ |
| Color darken + scale | Darkens AND shrinks. Double feedback | |
| You decide | Claude picks per button size | |

**User's choice:** Scale bounce
**Notes:** Quick, tactile, works well on mobile touch

| Option | Description | Selected |
|--------|-------------|----------|
| Instant with highlight | Instant switch, active tab highlight slides to new position | ✓ |
| Brief crossfade | Old screen fades out, new fades in (~150ms) | |
| You decide | Claude picks for screen system | |

**User's choice:** Instant with highlight
**Notes:** Fast, doesn't block gameplay

| Option | Description | Selected |
|--------|-------------|----------|
| Subtle pulse on actionable items | Generators with charges pulse, completed orders glow | ✓ |
| No hover states | Keep clean, mobile doesn't have hover | |
| You decide | Claude determines which elements benefit | |

**User's choice:** Subtle pulse on actionable items
**Notes:** Helps new players identify what's interactive

---

## Claude's Discretion

- Quality tier system (HIGH/MED/LOW) — detection, override, particle budgets
- Exact particle counts, speeds, timing curves per effect
- GC pressure reduction for web
- High-level merge slow-mo vs more particles
- Arena glow/dissolve implementation approach

## Deferred Ideas

None — discussion stayed within phase scope
