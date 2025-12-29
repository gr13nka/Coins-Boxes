# User instructions, editing not allowed
Do no try to test the project running in with love . .User will test it on its own.
When file becomes bigger then 1.5k lines suggest refactoring.
Use love2d and lua best coding practicies.
DO NOT use goto, it breaks the web build.
# End of user instructions. 

## Architecture

**Module Structure:**
- `main.lua` - Minimal entry point: LÖVE callbacks, window setup, asset loading, screen registration (~140 lines)
- `game.lua` - Classic mode game state and mechanics. Coins are color strings.
- `game_2048.lua` - 2048 mode game state and mechanics. Coins are `{number=N}` objects.
- `game_screen.lua` - Classic mode gameplay screen (UI, input handling, drawing)
- `game_2048_screen.lua` - 2048 mode gameplay screen (UI, input handling, drawing)
- `graphics.lua` - Game rendering: coins, boxes, background (NOT UI buttons)
- `input.lua` - Input handling: hit testing, coordinate conversion
- `sound.lua` - Sound management: loading, playback, toggle state
- `progression.lua` - Full unlock/achievement system with persistence
- `coin_utils.lua` - Utility functions for 2048 mode: HSL color conversion, number-to-color mapping
- `animation.lua` - Coin animation system for hover (bobbing) and flight (arc trajectory) effects
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
- **Goto-based retry**: Uses `goto` with labels (`::box::`, `::color::`) for random placement retries
- **Immediate-mode UI**: Buttons drawn as rectangles, hit-tested on mouse click

## Screen System (screens.lua)

**Screen Manager API:**
- `screens.register(name, screen)` - Register a screen table with a name
- `screens.switch(name)` - Switch to a registered screen (calls `exit()` on old, `enter()` on new)
- `screens.update(dt)`, `screens.draw()`, `screens.mousepressed()`, `screens.keypressed()` - Delegate to current screen

**Screen Table Structure:**
Each screen is a table with optional methods: `enter()`, `exit()`, `update(dt)`, `draw()`, `mousepressed(x, y, button)`, `keypressed(key, scancode, isrepeat)`

**Available Screens:**
- `mode_select` - Initial menu with game mode buttons (includes unlock status display)
- `game` - Classic mode gameplay screen (defined in `game_screen.lua`)
- `game_2048` - 2048 mode gameplay screen (defined in `game_2048_screen.lua`)

**Adding New Screens:**
1. Create a new file `my_screen.lua` with screen table and methods
2. Add `my_screen.init(assets)` function to receive shared assets
3. In `main.lua`, require and init the screen, then register with `screens.register()`
4. Add a button in `mode_select` to switch to it (with unlock_key if lockable)

## Animation System (animation.lua)

Handles visual animations when picking up, placing, and merging coins.

**Animation States:**
- `IDLE` - No animation active
- `HOVERING` - Coins bob up and down after being picked up, spread horizontally
- `FLYING` - Coins fly in arc trajectory to destination, dropping one by one
- `MERGING` - Coins slide up one-by-one into each other with particles and screen shake

**Public API:**
- `animation.startHover(coins, source_box_index)` - Begin hover animation with bobbing
- `animation.startFlight(dest_box_idx, dest_slot, callback, coinLandCallback)` - Begin flight to destination
- `animation.startMerge(merge_data, callback, boxMergeCallback, particlesRef)` - Begin merge animation
- `animation.update(dt)` - Called from screen's `update(dt)`
- `animation.draw(ballImage, COLORS, mode, font)` - Draw hover/flight animated coins
- `animation.drawMerge(ballImage, font)` - Draw merge animation (call separately)
- `animation.isAnimating()`, `isHovering()`, `isFlying()`, `isMerging()` - State queries
- `animation.getHoveringCoins()` - Get array of coin data (strings for classic, tables for 2048)
- `animation.getMergingBoxIndices()` - Get table of box indices being animated (for skipping static draw)
- `animation.getScreenShake()` - Get (x, y) shake offset to apply to drawing
- `animation.cancel()` - Reset to idle state

**Hover/Flight Animation Flow:**
1. Click box with coins → `startHover()` → coins bob up/down, spread horizontally
2. Click destination box → `startFlight()` → coins fly in arc, drop one by one
3. Each coin landing triggers `coinLandCallback` (adds to box, plays sound)
4. All landed → `callback` fires, animation returns to IDLE

**Merge Animation Flow (supports N coins dynamically):**
1. Call `game_2048.getMergeableBoxes()` to get boxes that can merge
2. Call `startMerge(merge_data, onComplete, onBoxMerge, particles)`
3. For each box (sequentially with delay):
   - Bottom coin slides up into second-from-bottom (particles + shake)
   - Combined slides up into next coin (particles + shake)
   - Repeat until all coins merged at top slot
   - `onBoxMerge(box_data)` callback fires (update game state)
   - New coin pops with elastic bounce + final particles
4. All boxes done → `onComplete()` fires, animation returns to IDLE

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

Visual particle effects for coin interactions.

**Public API:**
- `particles.init()` - Create particle system with soft circular image
- `particles.update(dt)` - Update particle physics
- `particles.draw()` - Render all active particles
- `particles.spawn(x, y, color)` - Burst 45 particles upward (coin landing)
- `particles.spawnMergeExplosion(x, y, color)` - Burst 120 particles in all directions (merge impact)
- `particles.spawnSqueezeParticles(x, y, color, count)` - Small burst during squeeze (optional)

**Configuration - Normal Burst:**
- `PARTICLE_COUNT = 45` - Particles per burst
- `LIFETIME = 0.25-0.5s` - Particle lifetime range
- `SPEED = 500-900` - Initial velocity range
- `SPREAD_ANGLE = 2.1 rad` - ~120 degrees upward arc
- `GRAVITY = 1200` - Downward acceleration

**Configuration - Merge Explosion:**
- `MERGE_PARTICLE_COUNT = 120` - Massive burst
- `MERGE_LIFETIME = 0.4-0.8s` - Longer lifetime
- `MERGE_SPEED = 600-1200` - Faster burst
- `MERGE_SPREAD_ANGLE = 2π` - Full 360 degrees

**Visual Effects:**
- Particles start large (0.8-1.0 scale), shrink to 0.15-0.2
- Color brightened from source coin color
- Alpha fades from 1 → 0.8 → 0 over lifetime
- Slight spin for visual interest

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
- `COIN_R` - Coin radius
- `ROW_STEP`, `COLUMN_STEP` - Grid spacing
- `GRID_TOP_Y`, `GRID_LEFT_OFFSET` - Grid position
- `BUTTON_AREA_Y`, `BUTTON_WIDTH`, `BUTTON_HEIGHT` - Button layout at bottom
- `FONT_SIZE` - UI font size
- `SOUND_TOGGLE_SIZE`, `SOUND_TOGGLE_MARGIN`, `SOUND_TOGGLE_Y` - Sound toggle button layout

## 2048 Mode (game_2048.lua)

A separate game mode where coins have numbers instead of just colors.

**Core Mechanics:**
- Coins are objects `{number=N}` where N is 1-50
- Placement rule: Can only place coin on top of SAME number OR in empty slot
- Merging (2048-style): 2 coins of same number → 1 coin of (number+1)
- Numbers displayed on coins with white text

**Coin Colors:**
- Colors generated algorithmically via `coin_utils.numberToColor()`
- Uses golden angle (137.5°) for hue distribution - ensures adjacent numbers have distinct colors
- Saturation/lightness also vary slightly for additional distinction

**Progression System:**
- `total_merges` tracks how many merges the player has done
- `max_spawn_number` starts at 3, increases by 1 every 10 merges (caps at 10)
- New coins spawn with random number in range `[1, max_spawn_number]`

**Invalid Placement Feedback:**
- Box shakes with red highlight
- "Wrong number!" error message displayed temporarily
- Coins remain hovering - player must pick valid destination

**State Variables (in game_2048.lua):**
- `boxes` - Array of box arrays containing `{number=N}` coin objects
- `BOX_ROWS = 3` - Slots per box
- `merge_requirement = 2` - Coins needed to trigger merge (configurable)
- `total_merges` - Progression counter
- `max_spawn_number` - Current spawn range upper limit
- `MAX_NUMBER = 50` - Absolute maximum coin number

**Public API:**
- `game_2048.init()` - Initialize with coins numbered 1-3
- `game_2048.pick_coin_from_box(idx, opts)` - Pick same-number coins from top
- `game_2048.can_place(dest_idx, coins)` - Validate placement, returns (bool, error_msg)
- `game_2048.place_coin(dest_idx, coin)` - Add single coin to box
- `game_2048.merge()` - Execute 2048-style merge (instant, no animation)
- `game_2048.getMergeableBoxes()` - Get list of boxes that can merge (for animation)
- `game_2048.executeMergeOnBox(box_idx)` - Merge single box (used by animation callback)
- `game_2048.add_coins()` - Spawn new coins based on progression
- `game_2048.getState()` - Return all state
- `game_2048.setError(msg)` - Trigger error display

**Animated Merge Flow:**
1. Call `getMergeableBoxes()` - returns array of `{box_idx, coins, old_number, new_number, color, new_color}`
2. Pass to `animation.startMerge()` with callbacks
3. Animation calls `executeMergeOnBox()` when each box's animation completes
4. This updates game state (removes coins, adds merged coin, awards points)

## Coin Utilities (coin_utils.lua)

Helper functions for 2048 mode coin handling.

**Color Generation:**
- `coin_utils.hslToRgb(h, s, l)` - Convert HSL (0-1 range) to RGB
- `coin_utils.numberToColor(number, max)` - Map number to unique color using golden angle

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

## Graphics System (graphics.lua)

Game rendering for coins, boxes, and background (NOT UI buttons).

**Public API:**
- `graphics.init(ballImage)` - Initialize with coin sprite
- `graphics.getBallImage()` - Get ball image (for animation module)
- `graphics.loadBackground(num)` - Load background by number (1-91)
- `graphics.nextBackground()` - Cycle to next background
- `graphics.updateBackgroundScroll(dt, speedX, speedY)` - Update scroll position
- `graphics.drawBackground()` - Draw scrolling background
- `graphics.drawCoins(boxes, COLORS)` - Draw coins (classic mode)
- `graphics.drawCoins2048(boxes, MAX_NUMBER, font)` - Draw coins with numbers (2048 mode)
- `graphics.drawBoxes(boxes, BOX_ROWS)` - Draw box grid (classic mode)
- `graphics.drawBoxes2048(boxes, BOX_ROWS, shakeState)` - Draw box grid with shake (2048 mode)
