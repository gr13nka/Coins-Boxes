# Phase 3: Popups and Commission Persistence - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Build a tiered popup system for reward moments (toast/card/celebration) and make commissions persist across sessions with improved quest-list UI. The popup system is a new module; commission persistence extends the existing `commissions.lua` + `progression.lua` infrastructure.

</domain>

<decisions>
## Implementation Decisions

### Popup tiers & layout
- **D-01:** Toast tier uses a top banner that slides in from the top of the screen and auto-dismisses after ~2s. Tapping anywhere dismisses early.
- **D-02:** Medium card tier uses a centered card (~60% screen width) with a semi-transparent dimmed background and an accept button. Input is blocked while visible.
- **D-03:** Celebration tier uses a large centered card (~80% screen width) with Phase 2's radial star burst and overlay flash behind it. Same card structure as medium but larger and with effects.

### Popup tier mapping
- **D-04:** Fuel/Stars from merges and chest drops use fly-to-bar icon animation only (Phase 2 effects) -- NO popup tier.
- **D-05:** Commission completions and drop notifications (gen tokens, fuel surge, star burst, bag bundle) use toast tier.
- **D-06:** Achievements use medium card tier.
- **D-07:** Level ups use celebration tier (huge).

### Popup interaction
- **D-08:** No gameplay pause -- the game is turn-based so timers (free bag, generator recharge) keep ticking while popups are visible. Input is blocked until dismissed.
- **D-09:** Popup queue is sequential with ~0.3s delay between items. Toasts can overlap (stack vertically). Cards and celebrations are one-at-a-time.
- **D-10:** Toasts auto-dismiss after ~2s. Tapping anywhere dismisses immediately.
- **D-11:** Medium cards and celebrations require tapping the accept button to dismiss.

### Commission lifecycle
- **D-12:** Commissions persist across sessions via `progression.dat`. The `commissions_data` slice stores active commissions with full state (type, difficulty, target, progress, completed).
- **D-13:** Batch refresh -- both commissions refresh together when BOTH are completed and rewards collected. Always 2 active commissions.
- **D-14:** Rewards are collected manually via a "Collect" button on each completed commission in the quest UI. No auto-collection on game over.
- **D-15:** Difficulty scales with total lifetime commissions completed (new counter), not `max_coin_reached`. Gradually introduces harder commissions as player completes more.

### Commission quest UI
- **D-16:** Inline panel below resource HUD in Coin Sort screen (improved current position). Same location as existing `drawCommissions()`, redesigned visually.
- **D-17:** Each commission entry includes: progress bar (horizontal fill), colored difficulty badge (green/yellow/red), reward preview icons (bag + star amounts), and a collect button that appears when complete.

### Claude's Discretion
- Toast animation timing curves and exact banner height
- Medium/celebration card internal layout (text, icons, reward display arrangement)
- Queue transition animations between items
- Commission data structure details for `progression.dat` persistence
- "Collect" button animation and reward fly-out effect
- Order completion reward treatment (likely toast or fly-to-bar -- not explicitly decided)
- How toasts stack vertically when multiple arrive simultaneously

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Popup system (new module)
- `effects.lua` -- Phase 2's overlay flash (`spawnFlash`) and fly-to-bar icons (`spawnFlyIcon`) are the visual foundation. Popup celebrations layer on top of these.
- `coin_sort_screen.lua` -- Current `spawnResourcePopup` floating text system (lines 115-200). Will be replaced/supplemented by the new popup module for toast tier.
- `arena_screen.lua` -- Arena-side trigger points for popups: order completion, level up, chest tap effects.

### Commission persistence
- `commissions.lua` -- Current per-session commission system: `generate()`, `onMerge()`, `collectRewards()`, `clear()`. Needs save/load, lifecycle changes, difficulty scaling rework.
- `progression.lua` -- Save infrastructure: `getDefaultData()` needs a `commissions_data` slice. Serialization, migration, `mergeWithDefaults` all apply.
- `game_over_screen.lua` -- Currently calls `commissions.collectRewards()` and `commissions.clear()` on enter. This flow changes with manual collect + batch refresh.

### Commission UI
- `coin_sort_screen.lua` -- `drawCommissions()` function (line 689+) is the current commission display. Will be redesigned in-place with progress bars, badges, collect buttons.

### Integration points
- `drops.lua` -- Drop notifications (chest, fuel surge, star burst, gen token) trigger toast popups.
- `arena_orders.lua` -- Level completion and order completion trigger card/celebration popups.
- `resources.lua` -- `onCoinMerge()` returns reward amounts; fly-to-bar (Phase 2) handles fuel/stars display.

No external specs -- requirements fully captured in decisions above and REQUIREMENTS.md (POP-01 through POP-03, COM-01 through COM-02).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `effects.lua` overlay flash + radial burst: Foundation for celebration tier background effects
- `effects.lua` fly-to-bar icons: Already handles fuel/star gain visuals -- no popup needed for those
- `spawnResourcePopup` in `coin_sort_screen.lua`: Pattern for floating text, can inform toast implementation
- `progression.lua` save infrastructure: `getDefaultData()`, `mergeWithDefaults()`, `runMigrations()` -- standard pattern for adding `commissions_data`

### Established Patterns
- Logic/visual separation: Popup queue logic goes in a new data module (`popups.lua`), rendering in screen modules
- Save batching: Commission save should follow the `NoSave` + `sync()` pattern used by resources/bags/drops
- Module skeleton: `local popups = {}` ... `return popups` with init/update/draw separation
- Screen interface: Popups draw on top of screen content, similar to how effects.lua overlays work

### Integration Points
- Commission save triggers: After `onMerge()` progress updates, after collect, after batch refresh -- use save batching
- Popup triggers: `coin_sort.executeMergeOnBox()` callback chain, `arena.completeOrder()`, `arena_orders.advanceLevel()`
- Tab bar badges: `drops.lua` already uses badge counts for cross-mode notifications -- commissions could add to these

</code_context>

<specifics>
## Specific Ideas

- Fuel/Stars from merges should just animate as fly-to-bar icons (Phase 2 system), not trigger any popup -- keep the merge flow snappy
- Chest drops also use fly-to-bar only -- no popup interruption for a common event
- Commission completion is a toast, not a big popup -- keep it lightweight since it happens frequently
- Level ups are the BIG moment -- full celebration treatment with star burst and large card
- Collect button on commissions creates an intentional reward moment -- player actively claims rewards

</specifics>

<deferred>
## Deferred Ideas

- COM-F01: Cross-mode commission visibility (commissions from CS visible in Arena) -- deferred to v2
- COM-F02: Timer-based commission refresh policy (daily commissions) -- deferred to v2

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 03-popups-and-commission-persistence*
*Context gathered: 2026-04-06*
