# User instructions, editing not allowed
Do no try to test the project running in with love . .User will test it on its own.
When file becomes bigger then 1.5k lines suggest refactoring.
Use love2d and lua best coding practicies.
DO NOT use goto, it breaks the web build.
Document what youve done here.
Create an extensible, reusable snippets that can be easily used and refactored.
Try to keep your visuals and logic separate.
# End of user instructions. 

## Architecture

**Module Structure:**
- `main.lua` - Minimal entry point: LÖVE callbacks, window setup, asset loading, screen registration (~140 lines)
- `game.lua` - Classic mode game state and mechanics. Coins are color strings.
- `game_2048.lua` - 2048 mode game state and mechanics. Coins are `{number=N}` objects.
- `game_dev.lua` - Dev test mode: single centered box with 12 slots, all filled with "1" coins.
- `game_screen.lua` - Classic mode gameplay screen (UI, input handling, drawing)
- `game_2048_screen.lua` - 2048 mode gameplay screen (UI, input handling, drawing)
- `game_dev_screen.lua` - Dev test mode screen (centered single box layout)
- `currency.lua` - Shard/crystal currency system: 5 colors, earned from merging, 25 shards auto-convert to 1 crystal
- `upgrades.lua` - Permanent upgrades: houses (passive crystal production), row/column purchases, difficulty setting, max coin tracking
- `powerups.lua` - Consumable power-ups: Auto Sort and Hammer, purchasable in upgrades screen
- `game_over_screen.lua` - Game over stats screen: score, shard breakdown, crystal summary, Continue button
- `upgrades_screen.lua` - Meta/shop screen: crystal display, house grid (3x2), row/column upgrades, difficulty toggle, Play button
- `graphics.lua` - Game rendering: coins, boxes, background (NOT UI buttons)
- `input.lua` - Input handling: hit testing, coordinate conversion
- `sound.lua` - Sound management: loading, playback, toggle state
- `progression.lua` - Full unlock/achievement system with persistence
- `coin_utils.lua` - Utility functions for 2048 mode: 5-color cycling, shard color mapping
- `animation.lua` - Dual-track coin animation: pick/place (hover/flight) and background (merge/deal) run independently, 1.5x speed
- `particles.lua` - Particle effects system for coin landing visual feedback
- `screens.lua` - Screen management system with mode selection (includes unlock checks)
- `layout.lua` - Centralized layout configuration (canvas size, element positions, scaling)
- `utils.lua` - Utility functions including `each_coin()` iterator and debugger setup
- `conf.lua` - LÖVE window configuration (resizable, HiDPI)
- `tutorial.lua` - Placeholder for future tutorial system

**Rendering:**
- Uses a 1080x2400 virtual canvas (vertical/portrait orientation) with letterboxing
- Window scale configurable via `layout.WINDOW_SCALE` (default 0.5 for smaller screens)
- Screen-to-game coordinate conversion via `ox`, `oy` offsets and `scale` factor
- Coins rendered using `ball.png` sprite, tinted with `setColor()` for each coin color

**Game State:**
- Centralized in `game.lua` module-level variables
- Access via `game.getState()` returns: `boxes`, `COLORS`, `BOX_ROWS`, `points`, `merge_timer`, `selection`
- `boxes` is array of box arrays, each box contains coin color strings
- `COLORS` maps color names to RGB values

**Input Flow:**
1. `love.mousepressed` converts screen coords to game coords
2. Determines if click is on a box or button
3. Calls appropriate `game.*` function to modify state

## Key Patterns

- **Module exports**: `game.lua` returns table of public functions
- **Iterator pattern**: `utils.each_coin(boxes)` for coin traversal
- **Repeat/until retry**: Uses `repeat/until` loops for random placement retries (NO goto - breaks web build)
- **Immediate-mode UI**: Buttons drawn as rectangles, hit-tested on mouse click
- **Logic/visual separation**: Data modules (`currency.lua`, `upgrades.lua`, `game_2048.lua`) have no drawing code; screen modules handle all rendering

## Screen System (screens.lua)

**Screen Manager API:**
- `screens.register(name, screen)` - Register a screen table with a name
- `screens.switch(name)` - Switch to a registered screen (calls `exit()` on old, `enter()` on new)
- `screens.update(dt)`, `screens.draw()`, `screens.mousepressed()`, `screens.keypressed()` - Delegate to current screen

**Screen Table Structure:**
Each screen is a table with optional methods: `enter()`, `exit()`, `update(dt)`, `draw()`, `mousepressed(x, y, button)`, `keypressed(key, scancode, isrepeat)`

**Available Screens:**
- `mode_select` - Menu with game mode buttons (includes unlock status display)
- `game` - Classic mode gameplay screen (defined in `game_screen.lua`)
- `game_2048` - 2048 mode gameplay screen (defined in `game_2048_screen.lua`) — **default start screen**
- `game_dev` - Dev test mode screen (defined in `game_dev_screen.lua`)
- `game_over` - Post-run stats: score, per-color shard breakdown with progress bars, crystal totals (defined in `game_over_screen.lua`)
- `upgrades` - Meta/shop screen: crystal+shard display, house grid, row/column purchases, Play button (defined in `upgrades_screen.lua`)

**Adding New Screens:**
1. Create a new file `my_screen.lua` with screen table and methods
2. Add `my_screen.init(assets)` function to receive shared assets
3. In `main.lua`, require and init the screen, then register with `screens.register()`
4. Add a button in `mode_select` to switch to it (with unlock_key if lockable)

## Animation System (animation.lua)

Handles visual animations when picking up, placing, and merging coins.

**Dual-Track Architecture:**
The animation system uses two independent state tracks that can run simultaneously:
- `pick_state`: IDLE / HOVERING / FLYING — player's pick/place interaction
- `bg_state`: IDLE / MERGING / DEALING — automated background animations
This allows players to pick and place coins while merge/dealing animations play.

**Animation Speed:** All animations run at `SPEED_MULT = 1.5` (50% faster). Applied via `dt = dt * SPEED_MULT` in update.

**Animation States:**
- `IDLE` - No animation active
- `HOVERING` - Coins bob up and down after being picked up, spread horizontally (pick track)
- `FLYING` - Coins fly in arc trajectory to destination, dropping one by one (pick track)
- `MERGING` - Coins slide up one-by-one into each other with particles and screen shake (bg track)
- `DEALING` - Coins dealt poker-style from bottom of screen to destination boxes (bg track)

**Public API:**
- `animation.startHover(coins, source_box_index)` - Begin hover animation with bobbing
- `animation.startFlight(dest_box_idx, dest_slot, callback, coinLandCallback)` - Begin flight to destination
- `animation.startMerge(merge_data, callback, boxMergeCallback, particlesRef)` - Begin merge animation
- `animation.startDealing(coins_to_deal, mode, callback, coinLandCallback, particlesRef)` - Begin dealing animation
- `animation.update(dt)` - Called from screen's `update(dt)`, applies SPEED_MULT internally
- `animation.draw(ballImage, COLORS, mode, font)` - Draw hover/flight animated coins
- `animation.drawMerge(ballImage, font)` - Draw merge animation (call separately)
- `animation.drawDealing(ballImage, COLORS, font)` - Draw dealing animation
- `animation.isAnimating()`, `isHovering()`, `isFlying()`, `isMerging()`, `isDealing()` - State queries
- `animation.getHoveringCoins()` - Get array of coin data (strings for classic, tables for 2048)
- `animation.getMergingBoxIndices()` - Get table of box indices being animated (for skipping static draw)
- `animation.getMergeLockedBoxes()` - Get ALL box indices in merge (including waiting — for input blocking)
- `animation.getScreenShake()` - Get (x, y) shake offset to apply to drawing
- `animation.cancel()` - Reset pick/place track to idle

**Hover/Flight Animation Flow:**
1. Click box with coins → `startHover()` → coins bob up/down, spread horizontally
2. Click destination box → `startFlight()` → coins fly in arc, drop one by one
3. Each coin landing triggers `coinLandCallback` (adds to box, plays sound)
4. All landed → `callback` fires, animation returns to IDLE

**Merge Animation Flow (supports N coins dynamically, both modes):**
1. Call `game.getMergeableBoxes()` (classic) or `game_2048.getMergeableBoxes()` (2048) to get boxes that can merge
2. Call `startMerge(merge_data, onComplete, onBoxMerge, particles)`
3. For each box (sequentially with delay):
   - Bottom coin slides up into second-from-bottom (particles + shake)
   - Combined slides up into next coin (particles + shake)
   - Repeat until all coins merged at top slot
   - `onBoxMerge(box_data)` callback fires (update game state)
   - New coin pops with elastic bounce + final particles
4. All boxes done → `onComplete()` fires, animation returns to IDLE

**Return-to-Source Feature (both modes):**
- When hovering with coins, clicking on the source box returns coins and cancels the animation
- Uses `animation.getSourceBox()` to track where coins were picked from

**Merge Animation Phases (per box):**
- `waiting` - Box hasn't started yet (staggered by MERGE_BOX_DELAY)
- `slide` - Coin sliding up into the one above
- `impact` - Brief pause after collision, particles spawn
- `pop` - Final merged coin appears with elastic overshoot
- `done` - Animation complete for this box

**Configuration - Hover/Flight:**
- `HOVER_BOB_AMPLITUDE = 15` - Pixels up/down for bobbing
- `HOVER_BOB_SPEED = 1.5` - Bobbing cycles per second
- `HOVER_SPREAD = 90` - Pixels between coins while hovering
- `FLIGHT_DURATION = 0.35` - Seconds per coin flight
- `FLIGHT_ARC_HEIGHT = 150` - Arc height above trajectory
- `DROP_DELAY = 0.15` - Delay between each coin starting to drop

**Configuration - Merge:**
- `MERGE_SLIDE_DURATION = 0.15` - Time for one coin to slide into another
- `MERGE_IMPACT_PAUSE = 0.05` - Brief pause on impact
- `MERGE_POP_DURATION = 0.2` - New coin pop animation time
- `MERGE_BOX_DELAY = 0.2` - Delay between sequential boxes
- `MERGE_POP_OVERSHOOT = 1.3` - Scale overshoot on pop (elastic bounce)
- `SHAKE_INTENSITY = 12` - Max shake pixels
- `SHAKE_DURATION = 0.15` - Shake duration per impact

**Dealing Animation Flow (poker dealer style):**
1. Call `game.calculateCoinsToAdd()` or `game_2048.calculateCoinsToAdd()` to pre-calculate destinations
2. Call `startDealing(coins_to_deal, mode, onComplete, onCoinLand, particles)`
3. Coins fly sequentially from dealer position (bottom center) to destination boxes
4. Each coin: arc trajectory with spin, lands with shake + particles + bounce
5. `onCoinLand(coin, box_idx, slot)` callback adds coin to game state
6. All done → `onComplete()` fires, animation returns to IDLE

**Configuration - Dealing:**
- `DEALING_DROP_DELAY = 0.12` - Delay between coins being dealt
- `DEALING_FLIGHT_DURATION = 0.3` - Flight time per coin
- `DEALING_ARC_HEIGHT = 120` - Arc height for card-like trajectory
- `DEALING_SPIN_SPEED = 8` - Rotation speed during flight
- `DEALING_BOUNCE_OVERSHOOT = 1.2` - Elastic bounce scale on landing

**Screen Shake:**
- Shake intensity scales with merge progress (40% for first impact → 100% for final)
- Apply via `love.graphics.translate(animation.getScreenShake())` in draw
- Use `love.graphics.push()`/`pop()` to isolate shake effect

**Key Math:**
- Bobbing: `y = amplitude * sin(time * speed * 2π + phase)`
- Flight: Quadratic bezier curve with ease-out: `t_eased = 1 - (1-t)²`
- Slide: Ease-out quadratic: `t_eased = 1 - (1-t)²`
- Pop: Elastic overshoot: `scale = 1 + (overshoot-1) * sin(t*π) * (1 - t*0.5)`

## Particle System (particles.lua)

Chunky bouncy coin fragment particles with custom physics. Fragments scatter, spin, and bounce off the ground for a weighty, impactful feel matching the merge animation style.

**Public API:**
- `particles.init()` - Initialize particle pool (300 max particles)
- `particles.update(dt)` - Update physics: gravity, movement, bouncing
- `particles.draw()` - Render all active fragment particles
- `particles.spawn(x, y, color)` - Burst 20 coin fragments upward
- `particles.spawnMergeExplosion(x, y, color)` - Burst 35 fragments (merge impact)
- `particles.spawnSqueezeParticles(x, y, color, count)` - Smaller fragment burst
- `particles.getActiveCount()` - Debug: get active particle count

**Configuration - Normal Burst:**
- `SPAWN_COUNT = 20` - Fragments per burst
- `SPAWN_SPEED = 400-900` - Initial velocity range
- `SPAWN_ANGLE_SPREAD = 2.2 rad` - ~126 degrees upward
- `LIFETIME = 1.2s` - Time before fade out
- `MAX_BOUNCES = 3` - Bounces before settling

**Configuration - Merge Explosion:**
- `MERGE_SPAWN_COUNT = 35` - More fragments
- `MERGE_SPEED = 500-1100` - Faster burst
- `MERGE_LIFETIME = 1.5s` - Longer visibility

**Physics:**
- `GRAVITY = 1800` - Downward acceleration
- `BOUNCE_DAMPING = 0.6` - Velocity retained after bounce (60%)
- `GROUND_Y = VH - 100` - Bounce surface
- Friction on bounce reduces horizontal velocity
- Side wall bouncing keeps fragments on screen

**Visual Effects (chunky pixel art):**
- Varied fragment sizes: 6px, 10px, 14px, 18px squares
- Spinning rotation with damping on bounce
- Subtle white highlight on larger fragments for depth
- Fade out in last 30% of lifetime
- Scale shrinks slightly over time

## Assets

- `/sfx/` - Sound effects (chip-lay-2.ogg, chips-handle-1.ogg, chips-collide-2.ogg)
- `/bgnd_music/` - Background music
- `/assets/` - Background images and sprites
- `comic shanns.otf` - Custom UI font

## Keyboard Shortcuts (In-Game)

- `a` - Add new row to boxes (increases BOX_ROWS)
- `b` - Add new box column (adds box and new color)
- `\` - Quit the game

## Layout Configuration (layout.lua)

Key settings in `layout.lua`:
- `VW`, `VH` - Virtual canvas dimensions (1080x2400)
- `WINDOW_SCALE` - Initial window size multiplier (0.5 = 540x1200 window)
- `COIN_R` - Coin radius (dynamic, set by `applyMetrics`)
- `ROW_STEP`, `COLUMN_STEP` - Grid spacing (dynamic, set by `applyMetrics`)
- `GRID_TOP_Y`, `GRID_LEFT_OFFSET` - Grid position
- `BUTTON_AREA_Y`, `BUTTON_WIDTH`, `BUTTON_HEIGHT` - Button layout at bottom
- `FONT_SIZE` - UI font size
- `SOUND_TOGGLE_SIZE`, `SOUND_TOGGLE_MARGIN`, `SOUND_TOGGLE_Y` - Sound toggle button layout

**Progressive Grid Scaling:**
- `layout.getColumnStep(num_columns)` - Calculate column step for dynamic grid size: `floor(VW / (num_columns + 1))`
- `layout.getGridMetrics(cols, rows)` - Compute all sizing from grid dimensions: `column_step`, `coin_r`, `row_step`, `overlapping`, `two_layer`, layer offsets
- `layout.applyMetrics(metrics)` - Write computed values to layout globals (`COIN_R`, `ROW_STEP`, `COLUMN_STEP`, `TWO_LAYER`, `LAYER_OFFSET_X/Y`)
- `layout.slotPosition(column, slot)` - Map (column, slot) to screen (x, y, layer), accounting for two-layer mode
- Coin radius: `min(60, floor(column_step * 0.45))` — shrinks progressively with more columns
- Row step: `min(130, floor(grid_height / (display_rows + 0.5)))` — uses visual rows in 2-layer mode

**Two-Layer Depth Mode (poker-chip stacking):**
- Activates when `rows >= TWO_LAYER_THRESHOLD` (default 8)
- Pairs slots into visual rows: 8 slots → 4 visual rows, 10 slots → 5 visual rows
- Odd slots (1,3,5...) = back layer, offset up-left by `(LAYER_OFFSET_X, LAYER_OFFSET_Y)`
- Even slots (2,4,6...) = front layer, offset down-right
- Layer offsets: `X = floor(coin_r * 0.35)`, `Y = floor(coin_r * 0.2)`
- `graphics.drawCoins2048` renders back layer first, then front layer for proper z-order
- `graphics.drawBoxes2048` draws wider containers to fit both layers

**Module Cache Refresh:**
- `graphics.updateMetrics()` / `input.updateMetrics()` - Refresh module-level cached layout values
- Must be called after `layout.applyMetrics()` (done in `game_2048_screen.enter()`)
- `animation.lua` reads `layout.*` directly (no cached locals), so positions auto-update

## Classic Mode (game.lua)

Classic mode where coins are color strings that merge when a full box has matching colors.

**Core Mechanics:**
- Coins are color strings (e.g., "green", "red", "blue")
- Placement rule: Can place on any box with available slots
- Merging: Full box with all same colors → box cleared, points awarded with combo multiplier

**Public API:**
- `game.init()` - Initialize with random colored coins
- `game.pick_coin_from_box(idx, opts)` - Pick same-color coins from top
- `game.add_coins()` - Spawn new coins (respects color limits)
- `game.calculateCoinsToAdd()` - Pre-calculate coins for dealing animation
- `game.merge()` - Execute classic merge (instant, no animation)
- `game.getMergeableBoxes()` - Get list of boxes that can merge (for animation)
- `game.executeMergeOnBox(box_idx, combo)` - Merge single box (used by animation callback)
- `game.getState()` - Return all state
- `game.update(dt)` - Update timers

**Animated Merge Flow:**
1. Call `getMergeableBoxes()` - returns array of `{box_idx, coins, color, color_name, new_color}`
2. Pass to `animation.startMerge()` with callbacks
3. Animation calls `executeMergeOnBox(box_idx, combo)` when each box's animation completes
4. This updates game state (removes coins, awards points with combo multiplier)

## 2048 Mode (game_2048.lua)

A separate game mode where coins have numbers instead of just colors.

**Core Mechanics:**
- Coins are objects `{number=N}` where N is 1-50
- Placement rule: Can only place coin on top of SAME number OR in empty slot
- Merging (2048-style): Full box of same number → `MERGE_OUTPUT` (2) coins of (number+1)
- Numbers displayed on coins with white text

**Coin Colors:**
- 5 cycling colors: red (1,6,11...), green (2,7,12...), purple (3,8,13...), blue (4,9,14...), pink (5,10,15...)
- Mapped via `coin_utils.numberToColor()` using `((number-1) % 5) + 1`

**Progression System:**
- `total_merges` tracks how many merges the player has done
- `max_spawn_number` governed by buffer cap: `floor(COLS * 0.70) + difficulty_extra_types` (hard cap: cols-1)
- Also respects progression cap: `min(10, 3 + floor(merges/10))`
- `max_spawn_number = min(progression_cap, buffer_cap)`

**Dealing Algorithm (`computeDeal()`):**
- **Initial deal** (`is_initial=true`): `2 * BOX_ROWS` coins, uniform across `1..max_spawn_number` (boosted by historical best)
- **Regular deal**: `BOX_ROWS * uniform(0.5, 0.9)` coins, weighted type distribution
- Lower numbers appear more often via hand-tuned weight tables (2-5 types) or geometric decay (0.82)
- 36% chance (`SKIP_TYPE_CHANCE`) to skip each type per deal, creating variety
- CDF-based weighted random selection for type choice
- Single `computeDeal()` function used by `init()`, `add_coins()`, and `calculateCoinsToAdd()`

**Balance Constants:**
- `MERGE_OUTPUT = 2` — coins produced per merge (tunable)
- `DEAL_MIN_FRACTION = 0.5`, `DEAL_MAX_FRACTION = 0.9` — deal size range as fraction of BOX_ROWS
- `SKIP_TYPE_CHANCE = 0.36` — per-type skip probability
- `DEFAULT_BUFFER_MIN = 0.30` — minimum fraction of columns kept as buffer

**Invalid Placement Feedback:**
- Box shakes with red highlight
- "Wrong number!" error message displayed temporarily
- Coins remain hovering - player must pick valid destination

**State Variables (in game_2048.lua):**
- `boxes` - Array of box arrays containing `{number=N}` coin objects
- `BOX_ROWS` - Slots per box (dynamic: 4 + extra_rows from upgrades)
- `merge_requirement = 2` - Coins needed to trigger merge (configurable)
- `total_merges` - Progression counter
- `max_spawn_number` - Current spawn range upper limit (boosted by historical best on init: `max(2, max_coin_reached - 2)`)
- `MAX_NUMBER = 50` - Absolute maximum coin number
- `MERGE_OUTPUT = 2` - Coins produced per merge
- Grid size: `upgrades.getBaseColumns()` columns (base 4) x `upgrades.getBaseRows()` rows (base 4)
- Initial fill: `2 * BOX_ROWS` coins via `computeDeal(true, ...)`, uniform across `1..max_spawn_number`

**Public API:**
- `game_2048.init()` - Initialize with dynamic grid from upgrades, initial deal of 2*BOX_ROWS coins (types 1..max_spawn_number, boosted by history)
- `game_2048.pick_coin_from_box(idx, opts)` - Pick same-number coins from top
- `game_2048.can_place(dest_idx, coins)` - Validate placement, returns (bool, error_msg)
- `game_2048.place_coin(dest_idx, coin)` - Add single coin to box
- `game_2048.merge()` - Execute 2048-style merge (instant, no animation)
- `game_2048.getMergeableBoxes()` - Get list of boxes that can merge (for animation)
- `game_2048.executeMergeOnBox(box_idx)` - Merge single box (used by animation callback)
- `game_2048.add_coins()` - Spawn new coins based on progression
- `game_2048.calculateCoinsToAdd()` - Pre-calculate coins for dealing animation (returns array of {coin, dest_box_idx, dest_slot})
- `game_2048.getState()` - Return all state (includes `max_coin_reached` from upgrades)
- `game_2048.setError(msg)` - Trigger error display
- `game_2048.isGameOver()` - True only when all boxes are full AND no merges possible

**Max Coin Tracking:**
- Both `executeMergeOnBox()` and `merge()` call `upgrades.setMaxCoinReached(new_number)` after computing the merged coin
- On `init()`, `max_spawn_number` is boosted: `max(2, upgrades.getMaxCoinReached() - 2)` so returning players start with higher coin types

**Animated Merge Flow:**
1. Call `getMergeableBoxes()` - returns array of `{box_idx, coins, old_number, new_number, color, new_color}`
2. Pass to `animation.startMerge()` with callbacks
3. Animation calls `executeMergeOnBox()` when each box's animation completes
4. This updates game state (removes coins, adds merged coin, awards points, tracks max coin)

## Dev Test Mode (game_dev.lua)

A testing/development mode with a single tall centered box filled with "1" coins.

**Purpose:**
- Quick testing of merge animations and mechanics
- Debugging coin stacking behavior
- Testing with many coins in a single column

**Configuration:**
- 1 centered box at `VW/2`
- 12 row slots (fills most of screen height)
- All coins initialized as `{number=1}`
- TOP_Y = 200 (higher start position for taller box)

**Key Differences from 2048 Mode:**
- Single box instead of 5 columns
- Centered layout instead of grid
- Custom hit testing via `isOnDevBox(x, y)`
- Custom drawing via `drawDevBox()` and `drawDevCoins()`

**Public API (same pattern as game_2048):**
- `game_dev.init()` - Initialize with single box full of "1" coins
- `game_dev.pick_coin_from_box(idx, opts)` - Pick same-number coins
- `game_dev.can_place(dest_idx, coins)` - Validate placement
- `game_dev.place_coin(dest_idx, coin)` - Add coin to box
- `game_dev.getMergeableBoxes()` - Get boxes that can merge (2+ same coins)
- `game_dev.executeMergeOnBox(box_idx)` - Execute merge on box
- `game_dev.add_coins()` - Refill with "1" coins
- `game_dev.calculateCoinsToAdd()` - Pre-calculate for dealing animation
- `game_dev.getState()` - Return state

## Coin Utilities (coin_utils.lua)

Helper functions for 2048 mode coin handling.

**Color Generation (5-color cycling):**
- `coin_utils.numberToColor(number, max)` - Map number to RGB via 5-color cycle (red/green/purple/blue/pink)
- `coin_utils.numberToShardColor(number)` - Map number to shard color name
- `coin_utils.getShardRGB(color_name)` - Get RGB for shard color name
- `coin_utils.getShardNames()` - Get ordered list: {"red", "green", "purple", "blue", "pink"}

**Coin Type Helpers:**
- `coin_utils.isCoin(value)` - Check if value is a coin object (table with .number)
- `coin_utils.getCoinNumber(coin)` - Extract number from coin object
- `coin_utils.createCoin(number)` - Create new coin object `{number=N}`

## Progression System (progression.lua)

Full unlock/achievement system with file-based persistence.

**Unlock Categories:**
- `modes` - Game modes (classic, mode_2048, future modes)
- `colors` - Coin colors for classic mode
- `backgrounds` - Background images (1-91)
- `powerups` - Future power-up abilities
- `cosmetics` - Visual customizations

**Stats Tracked:**
- `total_merges`, `total_points`, `games_played`
- `highest_score_classic`, `highest_score_2048`
- `total_coins_placed`

**Achievements:**
- `first_merge`, `merge_master` (100 merges), `merge_legend` (1000 merges)
- `point_hunter` (1000 points), `dedicated_player` (50 games)
- `color_collector` (unlock all colors)

**Public API:**
- `progression.init(enable_persistence)` - Initialize, load from file if persistence enabled
- `progression.reset()` - Reset all progress to defaults (for testing)
- `progression.save()` / `progression.load()` - Persist to/from file
- `progression.isUnlocked(category, key)` - Check if something is unlocked
- `progression.unlock(category, key)` - Unlock something
- `progression.getUnlockProgress(category, key)` - Get current/required progress
- `progression.addStat(key, amount)` / `progression.getStat(key)` - Track stats
- `progression.onMerge(mode, count)` - Call when merge happens
- `progression.onGameEnd(mode, score)` - Call when game ends
- `progression.onCoinPlaced()` - Call when coin is placed

**Persistence:**
- Saves to `progression.dat` in LÖVE save directory
- Uses simple Lua table serialization
- Can be disabled for testing: `progression.init(false)`

## Sound System (sound.lua)

Centralized sound management with toggle state.

**Public API:**
- `sound.init()` - Load all sounds, start background music
- `sound.isMusicEnabled()` / `sound.isSfxEnabled()` - Check toggle state
- `sound.toggleMusic()` / `sound.toggleSfx()` - Toggle on/off
- `sound.playPickup()` / `sound.playMerge()` / `sound.playAdd()` - Play SFX

## Input System (input.lua)

Hit testing and coordinate conversion utilities.

**Public API:**
- `input.boxAt(x, y, boxes, top_y)` - Determine clicked box column (classic mode)
- `input.boxAt2048(x, y, boxes, top_y)` - Determine clicked box column (2048 mode)
- `input.isInsideButton(x, y, btnX, btnY, btnW, btnH)` - Check if point is inside button
- `input.isOnSfxToggle(x, y)` / `input.isOnMusicToggle(x, y)` - Check sound toggle clicks
- `input.toGameCoords(x, y, ox, oy, scale)` - Convert screen to game coordinates
- `input.updateMetrics()` - Refresh cached layout values after `layout.applyMetrics()`

## Graphics System (graphics.lua)

Game rendering for coins, boxes, and background (NOT UI buttons).

**Public API:**
- `graphics.init(ballImage)` - Initialize with coin sprite
- `graphics.getBallImage()` - Get ball image (for animation module)
- `graphics.loadBackground(num)` - Load background by number (1-91)
- `graphics.nextBackground()` - Cycle to next background
- `graphics.updateBackgroundScroll(dt, speedX, speedY)` - Update scroll position
- `graphics.drawBackground()` - Draw scrolling background
- `graphics.drawCoins(boxes, COLORS, skipBoxes)` - Draw coins (classic mode, skipBoxes for merge animation)
- `graphics.drawCoins2048(boxes, MAX_NUMBER, font, skipBoxes)` - Draw coins with numbers (2048 mode)
- `graphics.drawBoxes(boxes, BOX_ROWS)` - Draw box grid (classic mode)
- `graphics.drawBoxes2048(boxes, BOX_ROWS, shakeState)` - Draw box grid with shake (2048 mode); auto-detects stack/2-layer mode
- `graphics.updateMetrics()` - Refresh cached layout values after `layout.applyMetrics()`

## Currency System (currency.lua)

Shard/crystal currency earned from merging. Pure data module (no drawing).

**Mechanics:**
- 5 shard colors: red, green, purple, blue, pink (mapped from coin number via `((number-1) % 5) + 1`)
- Each merge awards `floor(coin_count * 5 * shard_bonus_multiplier)` shards of the mapped color
- Shard bonus multiplier from `upgrades.getShardBonusMultiplier()` (1.0 at normal, higher with difficulty)
- 25 shards auto-convert to 1 crystal (checked after every award)
- Per-run tracking reset with `currency.startRun()`
- Persistence via `progression.getCurrencyData()` / `setCurrencyData()`

**Public API:**
- `currency.init()` - Load state from progression
- `currency.save()` - Persist to progression
- `currency.startRun()` - Reset per-run shard tracking
- `currency.onMerge(coin_count, coin_number)` - Award shards + auto-convert
- `currency.getShards()` / `getCrystals()` / `getRunShards()` - Read state
- `currency.spendCrystals(color, amount)` - Deduct single color if affordable, returns bool
- `currency.canAfford(cost_table)` - Check multi-color cost, e.g. `{red=1, green=1}`
- `currency.spendMulti(cost_table)` - Deduct multi-color cost if affordable, returns bool
- `currency.addCrystal(color, amount)` - Add crystals (house production)
- `currency.getShardsPerCrystal()` - Returns 25

## Upgrades System (upgrades.lua)

Permanent upgrades: houses, grid size, and difficulty. Pure data module (no drawing).

**Flat Cost:** All upgrades (houses, rows, columns) cost 1 red + 1 green crystal.

**Houses:**
- Up to 6 slots (3x2 grid), each costs 1 red + 1 green crystal
- Each house produces 0.25 crystals/minute of its selected color (ticks on all screens)
- Color changeable after build (free)

**Grid Upgrades:**
- Row/column upgrades each cost 1 red + 1 green crystal (flat, not escalating)
- Max 6 extra rows, max 11 extra columns (grid can reach 10 rows x 15 columns)
- Base grid: 4 columns x 4 rows (before upgrades)

**Difficulty Setting:**
- `difficulty_extra_types` (0 = Normal, 1 = Hard, 2 = Extreme, etc.)
- Adds extra coin types beyond the default buffer cap, shrinking the buffer
- Default buffer: 30% of columns. Each extra type removes ~1/COLS from buffer
- Shard bonus: +10% per 5% buffer decrease (e.g., 4 cols, +1 type → +20% shards)
- Max extra types: `(cols - 1) - floor(cols * 0.70)` (at least 1 buffer column must remain)
- Persisted alongside other upgrades data

**Public API:**
- `upgrades.init()` / `save()` - Load/save via progression
- `upgrades.getUpgradeCost()` - Returns `{red=1, green=1}` cost table
- `upgrades.getBaseRows()` / `getBaseColumns()` - Current grid size (4+extra, 4+extra)
- `upgrades.buyRow()` / `buyColumn()` - Purchase (no color param, uses flat cost)
- `upgrades.canBuyRow()` / `canBuyColumn()` - Check if upgrade available (not maxed)
- `upgrades.buildHouse(slot, production_color)` - Build at slot with flat cost, set production color
- `upgrades.setHouseColor(slot, color)` - Change production color (free)
- `upgrades.updateProduction(dt)` - Tick house production, returns `{slot, color}` events for each crystal produced
- `upgrades.getHouseRate()` - Returns crystals-per-minute rate (0.25)
- `upgrades.getHouses()` / `getMaxHouses()` - House state
- `upgrades.getDifficultyExtraTypes()` - Current difficulty setting (0, 1, 2...)
- `upgrades.setDifficultyExtraTypes(n)` - Set and persist difficulty
- `upgrades.getMaxDifficultyExtraTypes()` - Max allowed for current column count
- `upgrades.getShardBonusMultiplier()` - Returns 1.0 + bonus (e.g., 1.2 for +20%)
- `upgrades.getMaxCoinReached()` - Highest coin number ever created across all runs
- `upgrades.setMaxCoinReached(n)` - Sets if n > current max, auto-saves

## Power-ups System (powerups.lua)

Consumable power-ups purchasable on upgrades screen, usable during 2048 gameplay. Pure data module (no drawing).

**Power-ups:**
- **Auto Sort** - Rearranges all coins so each column contains one number type (maximizing merge potential). Uses dealing animation.
- **Hammer** - Clears an entire column. Player clicks hammer button, then taps a column to clear.

**Costs:**
- Auto Sort: 2 red + 2 green crystals per purchase
- Hammer: 1 red crystal per purchase
- Both start with 100 uses for dev/testing

**Persistence:** Via `progression.getPowerupsData()` / `setPowerupsData()`, defaults `{auto_sort=100, hammer=100}`.

**Public API:**
- `powerups.init()` / `save()` - Load/save via progression
- `powerups.getAutoSortCount()` / `getHammerCount()` - Current charges
- `powerups.useAutoSort()` / `useHammer()` - Decrement if >0, returns bool
- `powerups.buyAutoSort()` / `buyHammer()` - Spend crystals + increment, returns bool
- `powerups.getSortCost()` - Returns `{red=2, green=2}`
- `powerups.getHammerCost()` - Returns `{red=1}`

**Game Logic (in game_2048.lua):**
- `game_2048.autoSort()` - Collects all coins, sorts by number, redistributes left-to-right. Clears all boxes, returns `coins_to_deal` array for dealing animation.
- `game_2048.clearColumn(col_idx)` - Removes all coins from a column. Returns removed coins for particle effects.

**Hammer Targeting Mode (in game_2048_screen.lua):**
- `hammer_mode` flag activates when hammer button is released
- Red tint overlay drawn on columns, "TAP COLUMN TO CLEAR" hint shown
- Clicking a column: uses charge, clears column, spawns explosion particles
- Cancel: click hammer button again, press Escape

**UI Locations:**
- In-game: Sort/Hammer buttons at `POWERUP_Y` (below ADD/MERGE buttons)
- Upgrades screen: Buy Sort / Buy Hammer section at `POWERUP_SHOP_Y = 1280`

## Game Over Screen (game_over_screen.lua)

Shows run results after game over, transitions to upgrades.

**Display (per color row):**
- Run shards earned (`+20`)
- Shard progress bar toward next crystal (`15/25`)
- Crystal total count (diamond icon)
- `"25 shards = 1 crystal"` legend at bottom

**Flow:** Game over detected -> shows score + shard breakdown + crystal totals -> "Continue" -> upgrades screen

## Upgrades Screen (upgrades_screen.lua)

Meta/shop screen between runs.

**Layout (1080x2400 canvas):**
- Best coin stat (y~65): "Best Coin: N" with coin-colored diamond icon (hidden if 0)
- Currency display (y~100): 5 color diamonds with crystal counts + shard progress bars (X/25)
- House grid (y~460): 3x2 grid, empty slots show pulsating "+" (green if affordable, dim red if not), built slots show color + progress bar + M:SS countdown timer
- Upgrade panel (y~1200): Buy Row / Buy Column buttons with costs (green if affordable, red if not, gray if maxed)
- Difficulty toggle (y~1450): `[<] DIFFICULTY: Hard (+40% shards) [>]` with buffer/types stats line
- Play button (y~1800): Large green button -> starts new 2048 run
- Notification area (y~1720): Red error text with 2s fade for failed purchases

**Affordability Indicators:**
- House slots: green border/pulse if any crystal can afford, red if none can
- Row/Column buttons: green background if affordable, dark red if not, gray if maxed
- Text dims to 40% alpha when unaffordable or maxed

**Color Picker Popup (houses only):**
- Shown when building a house (choose production color) or changing a built house's color
- Row/column upgrades buy directly on click (no picker needed - flat cost)

**Flying Crystal Animation (self-contained in upgrades_screen):**
- When a house produces a crystal, a diamond flies from the house progress bar to the matching currency diamond at top
- Arc trajectory with ease-out, sparkle highlight, elastic pop/overshoot on landing
- Config: 0.6s flight, 200px arc height, 0.25s pop with 1.4x overshoot
- Multiple crystals animate independently; cleared on screen enter

**Error Notifications:**
- `"Not enough crystals! Need 1 red + 1 green"` when clicking unaffordable upgrade
- `"Rows/Columns already at maximum!"` when clicking maxed upgrade
- Fade out over last 0.3s of 2s duration

## 2048 Gameplay Screen (game_2048_screen.lua)

**HUD Elements (top of screen):**
- Currency diamonds (y=50): 5 color diamonds with crystal counts
- Best coin progress bar (y=85): 600px wide, 16px tall, filled to `max_coin_reached / MAX_NUMBER`, colored by coin color via `coin_utils.numberToColor()`, label "Best: N / 50"
- Merge/spawn info (y=HINT_Y): "Merges: N | Max Spawn: N"
- Points (y=POINTS_Y): "Points: N"

**Responsive Input (fast gameplay):**
- Input is only blocked during coin flight (~0.23s with 1.5x speed) — NOT during merge or dealing
- Player can pick up and place coins while merge/dealing animations play in the background
- Boxes locked by an active merge animation (`getMergeLockedBoxes()`) cannot be interacted with
- Merge/Add buttons still require full idle state (`not animation.isAnimating()`) to fire
- Classic mode and dev mode screens retain old blocking behavior (block all non-hover animations)

## Screen Flow (Roguelike Loop)

App launches directly into 2048 mode (no mode select menu). Escape key goes to upgrades screen.

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

**Per-run cycle:**
1. `game_2048_screen.enter()` → recalculates grid from upgrades, inits game, resets run shard tracking
2. Player plays until all boxes full + no merges → `game_2048.isGameOver()` returns true
3. Game over check runs after: flight landing, dealing completion, merge completion
4. `game_over_screen` shows run stats with shard progress + crystal totals
5. "Continue" → `upgrades_screen` for buying houses/rows/columns
6. "Play" → back to step 1 with upgraded grid

**House production:** `upgrades.updateProduction(dt)` ticks on all screens (game_2048, game_over, upgrades), accumulating crystals passively. On the upgrades screen, production events trigger a flying crystal animation.
