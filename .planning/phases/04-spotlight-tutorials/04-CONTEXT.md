# Phase 4: Spotlight Tutorials - Context

**Gathered:** 2026-04-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Build a reusable spotlight overlay system and implement guided tutorials for both game modes. Coin Sort gets a new 5-step tutorial (greenfield). Arena gets a complete tutorial redesign (~6-8 steps, replacing the current 18-step state machine which is removed). Both use the shared spotlight system with hand icon animations and localized instruction text (Russian + English).

</domain>

<decisions>
## Implementation Decisions

### Spotlight overlay rendering
- **D-01:** Dark overlay with rounded-rectangle cutout matching target element bounds + small padding. No stencils exist in codebase -- this is new rendering territory (canvas-based approach or stencil).
- **D-02:** Overlay opacity is ~60% black (medium dim). Game grid/layout remains partially visible for spatial context behind the spotlight.
- **D-03:** Cutout edge has an animated pulse border -- brightness oscillates gently to draw the eye to the interaction target.
- **D-04:** Spotlight transitions between targets use smooth slide animation (~0.3s) -- cutout moves and resizes to the next target position. Player sees where attention shifts.

### Coin Sort tutorial (5 steps, greenfield)
- **D-05:** Full 3x5 grid with pre-set coins (not random deal). Board state is hand-crafted by the tutorial script to guarantee teaching moments.
- **D-06:** 5-step sequence: 1) Tap box to pick coins, 2) Tap another box to place, 3) Press Merge button to merge the now-full box, 4) Tap bag to deal new coins, 5) Free play.
- **D-07:** Steps 1-2 (pick/place) fill a box that step 3 (merge) then acts on. The pre-set board has a box almost full of same-number coins so the player's pick/place action completes it -- direct cause-and-effect between steps.

### Arena tutorial (redesign from scratch, ~6-8 steps)
- **D-08:** Complete redesign, NOT a 1:1 rebuild of the 18-step version. Focus on essential concepts without redundancy.
- **D-09:** Essential concepts taught (each gets 1-2 spotlight steps): dispenser tap -> item placement, merge same items, sealed cells + box reveals, generator tap (costs fuel), orders, stash.
- **D-10:** Keep the current initial board layout (7x8 with boxes, sealed cells, 2 empty cells). Proven layout, no redesign needed.
- **D-11:** Keep existing hardcoded tutorial drops (Da1 Egg, Me1 Smoked Meat). Less redesign risk, these simple items teach merging well.
- **D-12:** Old 18-step tutorial state machine is removed completely from the codebase (arena.lua tutorial_step, arena_screen.lua tutorial handling). Clean break, no dead code.

### Instruction delivery
- **D-13:** Hand icon (pointing hand emoji style) + minimal text label. Visual-first approach that works across languages and reduces text dependency.
- **D-14:** Animated tap motion for tap steps (hand moves down in tapping motion, repeats ~1.5s). Animated drag trail for drag steps (hand shows drag path from source to destination). Universal signals.
- **D-15:** Instruction text auto-positions above or below the spotlight, whichever has more space. Avoids overlapping the target.
- **D-16:** Tutorial text supports Russian + English from day one. Yandex Games targets Russian audience. Text strings stored in a localizable structure.

### Board state validation
- **D-17:** Each tutorial step validates board state preconditions before proceeding -- prevents soft-locks if something unexpected happens. Part of TUT-04 requirement.

### Claude's Discretion
- Exact pre-set coin layout for CS tutorial board (which numbers, which boxes)
- Stencil vs canvas approach for spotlight cutout rendering
- Exact step count for Arena tutorial (within 6-8 range)
- Step ordering for Arena tutorial concepts
- Pulse border timing/color
- Hand icon exact animation curves and timing
- Board state validation strategy (what preconditions per step, how to recover)
- Localization string format (table structure in Lua)
- Tutorial persistence format in progression.dat (how to track which tutorials are completed)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing tutorial infrastructure (to be replaced)
- `arena.lua` -- Current 18-step tutorial state machine: `tutorial_step`, `getTutorialStep()`, `setTutorialStep()`, `isTutorialDone()`, hardcoded `TUTORIAL_GEN_DROPS`. All to be removed and replaced.
- `arena_screen.lua` -- Tutorial-specific logic in `enter()` (step 1 dispenser seeding), `draw()` and `mousepressed()` tutorial branches. To be removed.

### Tutorial placeholder
- `tutorial.lua` -- Empty module placeholder. Will become the spotlight overlay + tutorial step system.

### Overlay/dimming patterns (reusable)
- `popups.lua` -- Backdrop dimming (`CARD_BACKDROP = {0,0,0,0.7}`), input blocking, overlay rendering patterns. Reference for spotlight overlay implementation.
- `effects.lua` -- Overlay flash system (`spawnFlash`), screen-level visual effects. Reference for celebration/feedback during tutorial.

### Input and layout
- `input.lua` -- Hit testing and coordinate conversion. Spotlight input blocking will need to integrate with this.
- `layout.lua` -- Virtual canvas (1080x2400), grid metrics. Spotlight positioning needs layout coordinates.
- `coin_sort_screen.lua` -- CS screen input handling, button drawing, merge button. Integration point for CS tutorial.
- `arena_screen.lua` -- Arena screen input handling, grid/dispenser/stash/order drawing. Integration point for Arena tutorial.

### Persistence
- `progression.lua` -- Save infrastructure: `getDefaultData()`, `mergeWithDefaults()`, `runMigrations()`. Tutorial completion state saved here.

### Animation
- `animation.lua` -- Dual-track animation system. Tutorial steps must respect animation states (don't advance during active animations).

No external specs -- requirements fully captured in decisions above and REQUIREMENTS.md (TUT-01 through TUT-04).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `popups.lua` backdrop rendering: Pattern for semi-transparent overlay with input blocking -- directly applicable to spotlight overlay
- `effects.lua` overlay flash: Screen-level effect system with pre-allocated pools -- reference for tutorial visual feedback
- `animation.lua` screen shake + callbacks: Tutorial steps should hook into animation completion callbacks to know when actions are done
- `coin_utils.numberToColor()`: 5-color cycling for coins -- needed for tutorial pre-set board coin rendering
- `arena_chains.lua` chain data: Item names, colors, levels -- needed for Arena tutorial instruction text

### Established Patterns
- Logic/visual separation: Tutorial step logic in `tutorial.lua` (data module), rendering/input in screen modules
- Module skeleton: `local M = {}` ... `return M` with init/update/draw separation
- Save batching: Tutorial state should follow the `sync()` pattern used by resources/bags/drops
- Callback-driven flow: Both animation tracks use callbacks (`onComplete`, `onBoxMerge`) -- tutorial step advancement should listen to these

### Integration Points
- CS tutorial integrates into `coin_sort_screen.lua` enter/draw/mousepressed -- overlay drawn on top, input filtered through spotlight
- Arena tutorial integrates into `arena_screen.lua` enter/draw/mousepressed -- replaces current tutorial branches
- Tutorial completion state saved via `progression.lua` alongside existing `tutorial_step` field (or new structure)
- Spotlight overlay drawn above game content but below popups (respects popup z-order from Phase 3)
- Tab bar may need to be hidden/disabled during tutorials to prevent mode switching mid-tutorial

</code_context>

<specifics>
## Specific Ideas

- Hand icon uses pointing hand emoji aesthetic -- not a realistic hand, more stylized/iconic
- Animated drag shows the full path from source to destination so player understands drag mechanic before attempting
- Pick/place in CS tutorial directly fills the box that triggers the merge step -- satisfying cause-and-effect chain
- Medium dim (60%) keeps spatial context visible -- player can see the grid layout while focusing on the spotlight target
- Pulsing border + smooth slide transitions give the spotlight system a polished, guided feel
- Russian + English localization is important because Yandex Games is the primary platform

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 04-spotlight-tutorials*
*Context gathered: 2026-04-07*
