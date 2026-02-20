# User instructions, editing not allowed
Do no try to test the project running in with love . .User will test it on its own.
When file becomes bigger then 1.5k lines suggest refactoring.
Use love2d and lua best coding practicies.
DO NOT use goto, it breaks the web build.
Document what youve done here.
Create an extensible, reusable snippets that can be easily used and refactored.
Try to keep your visuals and logic separate.
# End of user instructions.

## Modules

| File | Role |
|---|---|
| `main.lua` | Entry point: LOVE callbacks, window setup, asset loading, screen registration |
| `game.lua` | Classic mode logic. Coins are color strings. |
| `game_2048.lua` | 2048 mode logic. Coins are `{number=N}` objects (1-50). |
| `game_screen.lua` | Classic mode screen (UI, input, drawing) |
| `game_2048_screen.lua` | 2048 mode screen (UI, input, drawing) |
| `game_over_screen.lua` | Post-run stats: score, shard breakdown, crystal totals, Continue button |
| `upgrades_screen.lua` | Meta/shop: crystals, houses, row/col upgrades, difficulty, Play button |
| `screens.lua` | Screen manager with mode selection |
| `animation.lua` | Dual-track animation: pick/place + merge/deal run independently, 1.5x speed |
| `particles.lua` | Chunky bouncy coin fragments with custom physics (weighty, impactful feel) |
| `graphics.lua` | Game rendering: coins, boxes, background (NOT UI buttons) |
| `input.lua` | Hit testing and coordinate conversion |
| `layout.lua` | Centralized layout: 1080x2400 virtual canvas, scaling, grid metrics |
| `currency.lua` | Shard/crystal system (data only, no drawing) |
| `upgrades.lua` | Permanent upgrades: houses, grid size, difficulty (data only) |
| `powerups.lua` | Consumable power-ups: Auto Sort, Hammer (data only) |
| `progression.lua` | Unlock/achievement system with file persistence (`progression.dat`) |
| `coin_utils.lua` | 2048 helpers: 5-color cycling, shard mapping, fruit image loading |
| `sound.lua` | Sound loading, playback, toggle state |
| `utils.lua` | `each_coin()` iterator and debugger setup |
| `conf.lua` | LOVE window config (resizable, HiDPI) |
| `tutorial.lua` | Placeholder for future tutorial |

## Key Patterns

- **No goto** — use `repeat/until` loops for retries. Goto breaks the web build.
- **Logic/visual separation** — data modules (`currency`, `upgrades`, `game_2048`, `powerups`) have zero drawing code; screen modules handle all rendering.
- **Module exports** — each module returns a table of public functions.
- **Iterator** — `utils.each_coin(boxes)` for coin traversal.
- **Immediate-mode UI** — buttons drawn as rectangles, hit-tested on mouse click.

## Rendering

1080x2400 virtual canvas (portrait) with letterboxing. Screen-to-game coord conversion via `ox`, `oy`, `scale` in `main.lua`. Coin style toggle: `layout.USE_FRUIT_IMAGES` (`false` = tinted `ball.png`, `true` = per-color fruit PNGs).

## Screen System

Each screen is a table with optional methods: `enter()`, `exit()`, `update(dt)`, `draw()`, `mousepressed(x, y, button)`, `keypressed(key, scancode, isrepeat)`.

**Screens:** `mode_select`, `game` (classic), `game_2048` (default start), `game_over`, `upgrades`

**Adding a new screen:**
1. Create `my_screen.lua` with screen table and methods
2. Add `my_screen.init(assets)` to receive shared assets
3. In `main.lua`, require, init, and register with `screens.register()`
4. Add a button in `mode_select` to switch to it (with `unlock_key` if lockable)

## Screen Flow (Roguelike Loop)

```
[App Start] -> [game_2048] <------ [upgrades "Play"]
                   |                      ^
             [all boxes full,             |
              no merges possible]         |
                   |                      |
                   v                      |
             [game_over]                  |
                   |                      |
             ["Continue"] ----------------+
```

1. `game_2048_screen.enter()` recalculates grid from upgrades, inits game, resets run shards
2. Play until `game_2048.isGameOver()` (checked after flight landing, deal completion, merge completion)
3. `game_over_screen` shows run stats, "Continue" goes to `upgrades_screen`
4. "Play" starts a new run with the upgraded grid

**House production** ticks on ALL screens via `upgrades.updateProduction(dt)`. On upgrades screen, production events trigger flying crystal animations.

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

## Classic Mode (game.lua)

Coins are color strings. Full box with all same colors → cleared, points awarded with combo multiplier. See module for full API.

**Animated merge:** `getMergeableBoxes()` → `animation.startMerge()` → `executeMergeOnBox(box_idx, combo)` callback per box.

## 2048 Mode (game_2048.lua)

Coins are `{number=N}`, 5 cycling colors via `coin_utils.numberToColor()`. Placement: same number or empty slot only. Full box of same number → `MERGE_OUTPUT` (2) coins of number+1. See module for all balance constants.

**Two-cap progression system:**
- Buffer cap: `floor(COLS * 0.70) + difficulty_extra_types` (hard cap: cols-1)
- Progression cap: `min(10, 3 + floor(merges/10))`
- `max_spawn_number = min(progression_cap, buffer_cap)`

**Dealing algorithm (`computeDeal()`):**
- Initial deal: `2 * BOX_ROWS` coins, uniform types. Regular: `BOX_ROWS * uniform(0.5, 0.9)` with weighted distribution.
- Sparse board bonus: when fill < 30%, deal lerps toward `2 * BOX_ROWS` (0% fill → full initial size)
- 36% chance to skip each type per deal for variety. Lower numbers weighted heavier.

**Max coin tracking:** both `executeMergeOnBox()` and `merge()` call `upgrades.setMaxCoinReached(n)`. On `init()`, `max_spawn_number` boosted to `max(2, max_coin_reached - 2)`.

**Game over:** only when ALL boxes full AND no merges possible.

## Currency (currency.lua)

5 shard colors (red/green/purple/blue/pink). Merges award `floor(coin_count * 5 * shard_bonus)` shards. 25 shards auto-convert to 1 crystal. Per-run tracking reset with `currency.startRun()`. Persisted via progression.

## Upgrades (upgrades.lua)

**Flat cost:** all upgrades cost `{red=1, green=1}` crystals. Base grid: 4x4, max: 15 cols x 10 rows.

**House unlock (hidden feature):**
- Houses hidden until player spends rainbow cost (1 crystal of each of 5 colors)
- Before unlock: mystery progress bar (0-5 colors) with lock icon
- On unlock: free house token granted, remaining 5 slots purchasable
- Migration: saves with any built house auto-unlock on init
- When locked, UI elements below house area shift up by 410px via `yoff`

**Houses:** 6 slots (3x2), each produces 0.25 crystals/min of chosen color. Color changeable free.

**Difficulty:** `difficulty_extra_types` adds coin types beyond default buffer cap, shrinks buffer. Shard bonus: +10% per 5% buffer decrease.

## Power-ups (powerups.lua)

- **Auto Sort** — redistributes all coins left-to-right by number type. Cost: `{red=2, green=2}`.
- **Hammer** — clears an entire column. Activates targeting mode (red overlay, click column to clear, Escape to cancel). Cost: `{red=1}`.

Both start at 100 charges (dev/testing). `game_2048.autoSort()` returns dealing animation data. `game_2048.clearColumn(col_idx)` returns removed coins.

## 2048 Gameplay Screen (game_2048_screen.lua)

**Responsive input:** only blocked during coin flight (~0.23s). Players can pick/place during merge/deal. Merge/Add buttons require full idle. Classic mode retains full blocking.

**Reset button** (top-right): hold 3 seconds to reset all progress via `progression.reset()`.

## Assets

- `/sfx/` — sound effects, `/bgnd_music/` — background music
- `/assets/` — sprites: `ball.png` (tinted per color), `Red.png`, `Green.png`, `Purple.png`, `Blue.png`, `Pink.png` (1024x1024 fruit coins with ~200x200 center slot for number)
- `comic shanns.otf` — custom UI font

## Mobile Touch Input

`love.touchpressed` / `love.touchreleased` are intentionally **NOT defined** in `main.lua`. When absent, LÖVE automatically generates synthetic mouse events from touch — giving single-tap = single `mousepressed`. Defining touch callbacks disables this and caused double-fire (pick up + immediate return) on mobile.

**Web touch debounce:** SDL+Emscripten (love.js) fires BOTH a synthetic mouse event (`istouch=true`) AND a duplicate real mouse event (`istouch=false`) for a single touch. `main.lua` debounces this: when `istouch=true`, timestamp is recorded; any non-touch mouse event within 0.2s is ignored.

`game_2048_screen.lua` provides `isPointerDown()` and `getPointerPosition()` helpers that check both `love.mouse` and `love.touch` for extra robustness.

## Platform Detection (mobile.lua)

- `mobile.isMobile()` — native mobile only (Android/iOS). Use for fullscreen, vibration.
- `mobile.isWeb()` — web builds (`getOS() == "Unknown"` or `"Web"`; love-web-builder returns `"Unknown"`).
- `mobile.isLowPerformance()` — true for both native mobile AND web. Use for particle reduction and other GPU optimizations.

## Mobile/Web Performance

- **No FPS cap**: update and draw run at native rate on all platforms (browser typically provides 50-60fps). Animation speed multiplier is always 4x for snappy feel.
- **Particles**: `particles.lua` uses active-list pool (O(1) alloc, update skips dead) + SpriteBatch (1 draw call for all particles). `mobile.isLowPerformance()` halves particle counts (150 max, 10 per burst, 18 per merge), reduces lifetime/bounces, and skips the per-particle highlight.
- **Graphics caching**: `graphics.lua` caches `getDimensions()` for ball and fruit images, and `font:getWidth()`/`font:getHeight()` per font. Two-layer rendering uses step-2 iteration (no modulo per coin).
- **Canvas**: `{dpiscale = 1}` prevents oversized textures on HiDPI mobile GPUs.

## FPS Counter

Drawn inside the virtual canvas (bottom-left corner) in `main.lua`'s `love.draw()`, using a 24px font. Always visible on all screens.

## Keyboard Shortcuts
- `\` — quit, `Escape` — upgrades screen (from game)
