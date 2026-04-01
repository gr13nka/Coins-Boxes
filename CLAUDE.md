# User instructions, editing not allowed
When file becomes bigger then 1.5k lines suggest refactoring
Use love2d and lua best coding practicies
DO NOT use goto, it breaks the web build
Document what you have done
Keep your visuals and logic separate.
# End of user instructions.

## Modules

| File | Role |
|---|---|
| `main.lua` | Entry point: LOVE callbacks, window setup, asset loading, screen registration |
| `coin_sort.lua` | Coin Sort mode logic. Coins are `{number=N}` objects (1-50). |
| `coin_sort_screen.lua` | Coin Sort mode screen (UI, input, drawing) |
| `game_over_screen.lua` | Post-run stats: score, resource summary, Continue to Arena button |
| `arena.lua` | Merge Arena logic: 7x8 grid, boxes/sealed/items, dispenser, stash, generators |
| `arena_chains.lua` | 12 item chains with colors, items, generator specs, drop tables (data only) |
| `arena_orders.lua` | Level-based orders (10 levels, static data), completion, rewards (data only) |
| `arena_screen.lua` | Merge Arena screen: grid, dispenser, stash, orders, tutorial, drag-and-drop |
| `screens.lua` | Screen manager with mode selection |
| `animation.lua` | Dual-track animation: pick/place + merge/deal run independently, 1.5x speed |
| `particles.lua` | Chunky bouncy coin fragments with custom physics (weighty, impactful feel) |
| `graphics.lua` | Game rendering: coins, boxes, background (NOT UI buttons) |
| `input.lua` | Hit testing and coordinate conversion |
| `layout.lua` | Centralized layout: 1080x2400 virtual canvas, scaling, grid metrics |
| `resources.lua` | Fuel/Metal/Components resource system (data only, no drawing) |
| `bags.lua` | Coin bag inventory + free bag timer (data only, no drawing) |
| `tab_bar.lua` | Bottom tab bar UI component for screen switching |
| `powerups.lua` | Consumable power-ups: Auto Sort, Hammer (data only) |
| `progression.lua` | Unlock/achievement system with file persistence (`progression.dat`) |
| `coin_utils.lua` | Coin Sort helpers: 5-color cycling, shard mapping |
| `sound.lua` | Sound loading, playback, toggle state |
| `utils.lua` | `each_coin()` iterator and debugger setup |
| `conf.lua` | LOVE window config (resizable, HiDPI) |
| `tutorial.lua` | Placeholder for future tutorial |

## Key Patterns

- **No goto** — use `repeat/until` loops for retries. Goto breaks the web build.
- **Logic/visual separation** — data modules (`resources`, `bags`, `coin_sort`, `powerups`) have zero drawing code; screen modules handle all rendering.
- **Module exports** — each module returns a table of public functions.
- **Iterator** — `utils.each_coin(boxes)` for coin traversal.
- **Immediate-mode UI** — buttons drawn as rectangles, hit-tested on mouse click.

## Rendering

1080x2400 virtual canvas (portrait) with letterboxing. Screen-to-game coord conversion via `ox`, `oy`, `scale` in `main.lua`. Coins are always rendered as tinted `ball.png`.

## Screen System

Each screen is a table with optional methods: `enter()`, `exit()`, `update(dt)`, `draw()`, `mousepressed(x, y, button)`, `keypressed(key, scancode, isrepeat)`.

**Active Screens:** `coin_sort` (Coin Sort, default start), `arena` (Merge Arena), `game_over`
**Dormant Screens:** `mode_select` — kept in code but not registered.

**Adding a new screen:**
1. Create `my_screen.lua` with screen table and methods
2. Add `my_screen.init(assets)` to receive shared assets
3. In `main.lua`, require, init, and register with `screens.register()`

## Two-Screen Loop (Coin Sort + Merge Arena)

```
[App Start] -> [coin_sort] <--tab bar--> [arena]
                   |                        ^
             [all boxes full,               |
              no merges possible]           |
                   |                        |
                   v                        |
             [game_over]                    |
                   |                        |
             ["Continue to Arena"] ---------+
```

1. `coin_sort_screen.enter()` uses fixed 3×5 grid (15 boxes, 10 slots each), inits game
2. Deal coins from bags (limited). Merge coins to earn Fuel/Metal/Components.
3. Switch to Arena via tab bar. Generators cost 1 Fuel per tap to produce items.
4. Completing arena orders rewards XP + items (to dispenser queue).
5. Game over (all boxes full, no merges) → resource summary → Continue to Arena.

**Resource flow:** Coin Sort merges → Fuel → Arena generators → items → orders → XP + more items

**Tab bar** (tab_bar.lua) is drawn by both coin_sort_screen and arena_screen at bottom of canvas. Handles its own hit testing.

**Free bag timer** ticks on all screens via `bags.update(dt)`.

## Animation System

See `animation.lua` for all config constants and math formulas.

**Dual-track architecture** — two independent state tracks run simultaneously:
- **Pick track:** IDLE → HOVERING → FLYING (player interaction)
- **Background track:** IDLE → MERGING → DEALING (automated)

Players can pick/place coins while merge/dealing animations play in the background. Boxes currently being merged (`getMergeLockedBoxes()`) are excluded from interaction.

**Hover/Flight flow:**
1. Click box with coins → `startHover()` → coins lift up (~50ms) then stay static
2. Click destination → `startFlight()` → coins arc to target, drop one by one
3. Each landing triggers `coinLandCallback` (adds coin, plays sound)
4. All landed → `callback` fires → IDLE

**Return-to-source:** clicking the source box while hovering returns coins via `animation.getSourceBox()`.

**Merge flow (both modes):**
1. Call `getMergeableBoxes()` on the game module
2. Pass to `startMerge(merge_data, onComplete, onBoxMerge, particles)`
3. Per box (sequentially with delay): coins slide up one-by-one with particles + shake, `onBoxMerge` callback updates game state, new coin pops with elastic bounce
4. All done → `onComplete()` → IDLE

**Dealing flow (poker dealer style):**
1. Call `calculateCoinsToAdd()` to pre-calculate destinations
2. `startDealing()` — coins fly from bottom center to destination boxes with spin
3. Each landing triggers `onCoinLand`, all done triggers `onComplete`

**Screen shake:** intensity scales with merge progress (40% → 100%). Apply via `love.graphics.translate(animation.getScreenShake())` inside `push()`/`pop()`.

## Layout System

See `layout.lua` for all static values and metric formulas.

**Progressive grid scaling:** `layout.getGridMetrics(cols, rows)` computes all sizing. After calling `layout.applyMetrics()`, you MUST call `graphics.updateMetrics()` and `input.updateMetrics()` to refresh cached values. (`animation.lua` reads layout globals directly — no refresh needed.)

**Two-layer depth mode (poker-chip stacking):**
- Activates at `rows >= TWO_LAYER_THRESHOLD` (default 8)
- Pairs slots into visual rows: odd slots = back layer (offset up-left), even = front (offset down-right)
- `graphics.drawCoins2048` renders back layer first for proper z-order

**Multi-row column layout:**
- Activates at `cols >= MULTI_ROW_THRESHOLD` (default 7)
- Wraps columns into 2 visual rows, `column_step` uses `cols_per_row` so coins stay large
- `layout.columnPosition(column)` transparently handles row wrapping
- Can combine with two-layer mode (7+ cols AND 8+ rows)

## Coin Sort Mode (coin_sort.lua)

Coins are `{number=N}`, 5 cycling colors via `coin_utils.numberToColor()`. Placement: same number or empty slot only. Full box of same number → `MERGE_OUTPUT` (2) coins of number+1. See module for all balance constants.

**Two-cap progression system:**
- Buffer cap: `floor(COLS * 0.70) + difficulty_extra_types` (hard cap: cols-1)
- Progression cap: `min(10, 3 + floor(merges/10))`
- `max_spawn_number = min(progression_cap, buffer_cap)`

**Dealing algorithm (`computeDeal()`):**
- Initial deal: `2 * BOX_ROWS` coins, uniform types. Regular: `BOX_ROWS * uniform(0.5, 0.9)` with weighted distribution.
- Sparse board bonus: when fill < 30%, deal lerps toward `2 * BOX_ROWS` (0% fill → full initial size)
- 36% chance to skip each type per deal for variety. Lower numbers weighted heavier.

**Max coin tracking:** `executeMergeOnBox()` and `merge()` track max_coin_reached via progression. On `init()`, `max_spawn_number` boosted to `max(2, max_coin_reached - 2)`.

**Fixed 3×5 grid:** 15 boxes (3 rows × 5 columns), each holding 10 coin slots.

**Bag-based dealing:** `dealFromBag()` consumes one bag (from `bags.lua`) and deals coins. No unlimited adding.

**Game over:** only when ALL boxes full AND no merges possible.

## Merge Arena (arena.lua + arena_chains.lua + arena_orders.lua)

**7×8 grid** (56 cells). Linear index: `(row-1)*7 + col` (1-indexed). Cell states: empty (`nil`), box (`{state="box", chain_id, level}`), sealed (`{state="sealed", chain_id, level}`), normal item (`{chain_id, level}`). Generators are normal items at/above chain's `generator_threshold`.

### 12 Item Chains

| Chain | Abbr | Color | Items | Gen Threshold | Produces |
|---|---|---|---|---|---|
| Chill | Ch | light blue | L1-3 items, L4-10 gens (Fridge) | 4 | Me 1-3, Da 1-3, Ch 1 |
| Cupboard | Cu | brown | L1-3 items, L4-9 gens | 4 | Ta 1-2, Ki 1-2, Bl 1, He 1 |
| Heating | He | red/orange | L1-3 items, L4-10 gens (Toaster) | 4 | Ba 1-2 |
| Blending | Bl | purple | L1-3 items, L4-10 gens (Blender) | 4 | De 1-3 |
| Kitchenware | Ki | green | L1-6 items, L7 gen (Pot) | 7 | So 1 |
| Tableware | Ta | blue | L1-6 items, L7 gen (Carafe) | 7 | Be 1-2 |
| Meat | Me | dark red | 12 items | — | — |
| Dairy | Da | yellow | 12 items | — | — |
| Bakery | Ba | warm brown | 10 items | — | — |
| Desert | De | pink | 12 items | — | — |
| Soups | So | olive | 6 items | — | — |
| Beverages | Be | teal | 6 items | — | — |

**Generator drops — shuffle bag system:** Generators do NOT use random drops. Instead, a shuffle bag is pre-filled with all items required by uncompleted orders in the current level (exact chain+level), then Fisher-Yates shuffled. Each generator tap pulls the next item from the bag. When empty, refill from remaining uncompleted orders. Bag clears on level advancement. Fallback to `arena_chains.rollDrop()` only when all orders are complete.

**Tutorial generator drops are hardcoded:** First tap → Da1 (Egg), second tap → Me1 (Smoked Meat). After tutorial, switches to shuffle bag.

### Merge Rules
- Source must be a normal item (not box/sealed). Target can be normal OR sealed.
- Same chain_id AND same level AND level < max → merge to level+1 (always unsealed).
- After merge: adjacent boxes (4-directional) reveal as sealed items.

### Generator Mechanics
- Tap = spend 1 Fuel → pull from shuffle bag (or hardcoded during tutorial) → place in nearest empty cell (BFS).
- Cannot tap if Fuel < 1 or grid full.

### Dispenser, Stash, Drag Rules
- **Dispenser:** FIFO queue above grid, shows 1 item. Fed by: tutorial, order rewards, level rewards. **Tap to pop** — tapping dispenser places item in nearest empty grid cell (not draggable).
- **Stash:** 8 slots below grid. Storage only, no merging. Grid↔stash movement allowed.
- **Drag sources → valid targets:** grid→grid(empty/merge/sealed-merge), grid→stash(empty), stash→grid(empty), stash→stash(rearrange). Tap on generator = activate.

### Orders
10 levels of static orders (Season 1). Characters: Meryl, Murray, Marcus, Mike, Midori. Up to 3 visible at a time from current level. Complete order → items removed from grid, XP + item rewards to dispenser. All level orders done → level rewards (items + XP) → next level. Orders hidden during tutorial until step 13.

**Order item highlighting:** Grid items that match any visible order requirement are highlighted with a green border (visual only, not locked — player can still merge/move them). Count-aware: if an order needs 2× Me5, only 2 Me5 items get highlighted.

### Arena Screen Layout (1080×1920 virtual canvas)
- Fuel bar: Y 0-40
- Dispenser: Y 45-135 (single slot centered, queue count badge)
- Grid: Y 150-1298 (cell=140px, gap=4px, 7×8)
- Stash: Y 1310-1420 (8 horizontal slots, 110px each)
- Orders: Y 1435-1665 (up to 3 order cards)
- Tab bar: Y 1840-1920

### Initial Board
Full grid contents (all start as boxes except center area):
```
He3 Ch3 Bl5 Ch3 Cu2 Bl2 Cu3
Ki2 He3 Ki2 Cu1 Ch3 Bl1 Ch2
Ch5 Ki1 Ta2 Ch1 Cu2 Bl3 Cu4
He2 Cu3 Cu1 Da1 Bl2 He3 Ch5
Ta3 He2 Ta1  .   .  He4 Ki2
He2 Ch2 Da2 Me3 Ch3 Ta2 He4
He3 Ki2 Bl2 Da2 Me1 He4 Ch4
Ch3 Ki2 Ch4 Cu2 Da1 He3 Ki3
```
Initially sealed (visible): row4 cols 3-5 (Cu1,Da1,Bl2), row5 cols 2,3,6 (He2,Ta1,He4), row6 cols 3-5 (Da2,Me3,Ch3). Row5 cols 4-5 are empty. Everything else is boxes.

### Tutorial (18-step state machine)
1-3: Dispenser gives Ch1×2 → merge → Ch2. 4-5: Give Ch2 → merge → Ch3. 6-7: Drag Ch3 onto sealed Ch3 → Ch4 generator + box reveals. 8-9: Tap generator. 10-12: Give Da1×2 → merge onto sealed Da1 → Da2. 13-14: Show orders, complete first. 15: Show stash. 16-17: Tap generator again. 18: Done → free play. Orders hidden before step 13, stash hidden before step 15.

**Save data:** `progression.arena_data = {grid, stash, dispenser_queue, order_level, completed_orders, xp, tutorial_step}`. Old saves (with `board` key) auto-migrate to fresh arena start.

## Resources (resources.lua)

Three resources earned from Coin Sort merges:
- **Fuel** (cap 100): powers arena generators (1 Fuel per generator tap)
- **Metal** (uncapped): reserved for future use
- **Components** (uncapped): reserved for future use

Merge reward table (by resulting coin level): L2→+1fuel, L4→+1fuel+1comp, L5→+2fuel+1comp+5%metal, L6→+3fuel+2comp+25%metal, L7→+4fuel+3comp+50%metal

## Bags (bags.lua)

Coin bags consumed in Coin Sort to deal coins. Free bags generate on timer (12 min, max 2 queued). Order rewards add bags. Fresh save starts with 5 bags. Timer ticks on all screens.

## Power-ups (powerups.lua)

- **Auto Sort** — redistributes all coins left-to-right by number type.
- **Hammer** — clears an entire column. Activates targeting mode (red overlay, click column to clear, Escape to cancel).

Both start at 100 charges (dev/testing). `coin_sort.autoSort()` returns dealing animation data. `coin_sort.clearColumn(col_idx)` returns removed coins.

## Coin Sort Gameplay Screen (coin_sort_screen.lua)

**Responsive input:** only blocked during coin flight (~0.23s). Players can pick/place during merge/deal. Merge/Add buttons require full idle.

**Reset button** (top-right): hold 3 seconds to reset all progress via `progression.reset()`.

## Assets

- `/sfx/` — sound effects, `/bgnd_music/` — background music
- `/assets/` — sprites: `ball.png` (tinted per color for coins)
- `comic shanns.otf` — custom UI font

## Mobile Touch Input

`love.touchpressed` / `love.touchreleased` are intentionally **NOT defined** in `main.lua`. When absent, LÖVE automatically generates synthetic mouse events from touch — giving single-tap = single `mousepressed`. Defining touch callbacks disables this and caused double-fire (pick up + immediate return) on mobile.

**Web touch debounce:** SDL+Emscripten (love.js) fires BOTH a synthetic mouse event (`istouch=true`) AND a duplicate real mouse event (`istouch=false`) for a single touch. `main.lua` debounces this: when `istouch=true`, timestamp is recorded; any non-touch mouse event within 0.2s is ignored.

`coin_sort_screen.lua` provides `isPointerDown()` and `getPointerPosition()` helpers that check both `love.mouse` and `love.touch` for extra robustness.

## Platform Detection (mobile.lua)

- `mobile.isMobile()` — native mobile only (Android/iOS). Use for fullscreen, vibration.
- `mobile.isWeb()` — web builds (`getOS() == "Unknown"` or `"Web"`; love-web-builder returns `"Unknown"`).
- `mobile.isLowPerformance()` — true for both native mobile AND web. Use for particle reduction and other GPU optimizations.

## Mobile/Web Performance

- **No FPS cap**: update and draw run at native rate on all platforms (browser typically provides 50-60fps). Animation speed multiplier is always 4x for snappy feel.
- **Particles**: `particles.lua` uses active-list pool (O(1) alloc, update skips dead) + SpriteBatch (1 draw call for all particles). `mobile.isLowPerformance()` halves particle counts (150 max, 10 per burst, 18 per merge), reduces lifetime/bounces, and skips the per-particle highlight.
- **Graphics caching**: `graphics.lua` caches `getDimensions()` for the ball image, and `font:getWidth()`/`font:getHeight()` per font. Two-layer rendering uses step-2 iteration (no modulo per coin).
- **Canvas**: `{dpiscale = 1}` prevents oversized textures on HiDPI mobile GPUs.

## FPS Counter

Drawn inside the virtual canvas (bottom-left corner) in `main.lua`'s `love.draw()`, using a 24px font. Always visible on all screens.

## Keyboard Shortcuts
- `\` — quit, `Escape` — upgrades screen (from game)
