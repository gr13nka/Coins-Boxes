# Phase 2: Effects System Redesign - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Rebuild the particle/effects system for web performance with tiered quality (HIGH/MED/LOW), then add new visual effects for merges, chests/rewards, and button/UI interactions. The existing pool + SpriteBatch architecture in particles.lua is the foundation — redesign the tier system and layer new effect types on top.

</domain>

<decisions>
## Implementation Decisions

### Merge celebration effects
- **D-01:** Merge celebrations use a "satisfying pop" style — enhanced particles + screen shake + brief flash, amplifying the existing chunky fragment aesthetic rather than introducing new visual paradigms
- **D-02:** Effect intensity scales with coin level — low merges (L2-L3) get a small pop, high merges (L5+) get full celebration with more particles, stronger shake, and optional brief flash
- **D-03:** Coin Sort and Arena have mode-specific merge effects — CS coins explode into chunky fragments (current style, amplified), Arena items glow/dissolve into the merged result rather than exploding (kitchen objects don't shatter like coins)

### Chest & reward effects
- **D-04:** Chest opens use a "lid pop + item reveal" sequence — chest shakes briefly, lid pops off with chain-colored particles, item rises up and settles into its grid cell. Each tap is a mini-reveal moment
- **D-05:** Resource gains (Fuel/Stars from merges) use icon fly-to-bar — small fuel/star icons fly from the merge point to the corresponding resource bar at the top, showing where the resource went
- **D-06:** Big rewards (level completions, large star gains, commission completions) get a distinct celebration — brief overlay flash or radial star burst, separate from the normal fly-to-bar treatment. Makes big moments feel meaningfully different from routine gains

### Button & UI polish
- **D-07:** Button press feedback uses scale bounce — button shrinks to ~95% on press, bounces back with subtle overshoot. Quick and tactile, works well for mobile touch
- **D-08:** Tab bar switches are instant (no slide/crossfade animation) but the active tab highlight/underline slides smoothly to the new position. Fast, doesn't block gameplay
- **D-09:** Actionable items get subtle pulse feedback — generators with charges gently pulse, completed orders glow. Helps players identify what's interactive, especially useful for new players

### Claude's Discretion
- Quality tier system (HIGH/MED/LOW) — how to detect platform capability, whether to allow player override, exact particle budgets per tier. Current binary IS_MOBILE gating in particles.lua is the starting point
- Exact particle counts, speeds, and timing curves for each effect
- GC pressure reduction strategy for web builds
- Whether high-level merges (L6-L7) get brief slow-mo or just more particles
- Arena glow/dissolve implementation approach (shader vs alpha tween vs particle overlay)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Effects system
- `particles.lua` — Current pool + SpriteBatch particle system with IS_MOBILE gating, spawn/merge explosion functions
- `animation.lua` — Dual-track animation state machine (pick/place + merge/deal), screen shake infrastructure, all timing constants
- `graphics.lua` — Coin/box rendering, sprite caching, metrics system

### Performance context
- `mobile.lua` — Platform detection: `isLowPerformance()` gates particle counts for mobile and web
- `layout.lua` — Virtual canvas (1080x2400), coordinate system, grid metrics

### Integration points
- `coin_sort_screen.lua` — Where CS merge effects trigger, current merge animation callbacks
- `arena_screen.lua` — Where Arena merge/chest/generator effects trigger, order completion callbacks
- `tab_bar.lua` — Tab switching UI, where transition highlight would be added
- `resources.lua` — Fuel/Stars resource system, `onCoinMerge()` returns reward amounts for fly-to-bar
- `drops.lua` — Chest system, reward rolling — triggers for chest open effects

No external specs — requirements fully captured in decisions above and REQUIREMENTS.md (FX-01 through FX-05).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `particles.lua` pool + SpriteBatch system: O(1) alloc, swap-remove, single draw call. Foundation for all particle effects — extend, don't replace
- `animation.lua` screen shake: already has intensity scaling and duration config. Can be amplified for merge celebrations
- `animation.lua` dual-track state machine: merge/deal animations already trigger callbacks per-box — natural hook points for per-merge effects
- `coin_utils.numberToColor()`: 5-color cycling for coins — use for merge particle tinting
- `arena_chains.lua` chain colors: each chain has a defined color — use for Arena merge and chest particle tinting

### Established Patterns
- `mobile.isLowPerformance()` gates visual complexity — extend this into the 3-tier system
- SpriteBatch for batched rendering — any new particle types should follow this pattern
- Callbacks in animation system (`onBoxMerge`, `coinLandCallback`, `onComplete`) — natural trigger points for effects
- Logic/visual separation — new effect logic (timing, sequencing) goes in effect modules, rendering in screen modules or rendering helpers

### Integration Points
- Merge effects trigger from `animation.startMerge()` callbacks in both `coin_sort_screen.lua` and `arena_screen.lua`
- Chest effects trigger from `arena_screen.lua` chest tap handling
- Resource fly-to-bar needs source coordinates (from merge point) and target coordinates (resource bar position in screen layout)
- Button feedback integrates into the immediate-mode button drawing in screen modules
- Tab highlight animation integrates into `tab_bar.lua` draw function

</code_context>

<specifics>
## Specific Ideas

- Arena merges should feel like items glow and dissolve into the merged result (kitchen objects don't shatter) — contrasts with CS coins which explode into chunky fragments
- Icon fly-to-bar for resource gains shows "where the resource went" — connects the merge action to the resource bar spatially
- Big rewards (level ups, commission completions) need a visually distinct celebration that stands apart from routine fly-to-bar — radial star burst or overlay flash

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-effects-system-redesign*
*Context gathered: 2026-04-05*
