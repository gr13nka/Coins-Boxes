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
- `DEALING` - Coins dealt poker-style from bottom of screen to destination boxes

**Public API:**
- `animation.startHover(coins, source_box_index)` - Begin hover animation with bobbing
- `animation.startFlight(dest_box_idx, dest_slot, callback, coinLandCallback)` - Begin flight to destination
- `animation.startMerge(merge_data, callback, boxMergeCallback, particlesRef)` - Begin merge animation
- `animation.startDealing(coins_to_deal, mode, callback, coinLandCallback, particlesRef)` - Begin dealing animation
- `animation.update(dt)` - Called from screen's `update(dt)`
- `animation.draw(ballImage, COLORS, mode, font)` - Draw hover/flight animated coins
- `animation.drawMerge(ballImage, font)` - Draw merge animation (call separately)
- `animation.drawDealing(ballImage, COLORS, font)` - Draw dealing animation
- `animation.isAnimating()`, `isHovering()`, `isFlying()`, `isMerging()`, `isDealing()` - State queries
- `animation.getHoveringCoins()` - Get array of coin data (strings for classic, tables for 2048)
- `animation.getMergingBoxIndices()` - Get table of box indices being animated (for skipping static draw)
- `animation.getScreenShake()` - Get (x, y) shake offset to apply to drawing
- `animation.cancel()` - Reset to idle state

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
- `COIN_R` - Coin radius
- `ROW_STEP`, `COLUMN_STEP` - Grid spacing
- `GRID_TOP_Y`, `GRID_LEFT_OFFSET` - Grid position
- `BUTTON_AREA_Y`, `BUTTON_WIDTH`, `BUTTON_HEIGHT` - Button layout at bottom
- `FONT_SIZE` - UI font size
- `SOUND_TOGGLE_SIZE`, `SOUND_TOGGLE_MARGIN`, `SOUND_TOGGLE_Y` - Sound toggle button layout

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
- `game_2048.calculateCoinsToAdd()` - Pre-calculate coins for dealing animation (returns array of {coin, dest_box_idx, dest_slot})
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
- `graphics.drawCoins(boxes, COLORS, skipBoxes)` - Draw coins (classic mode, skipBoxes for merge animation)
- `graphics.drawCoins2048(boxes, MAX_NUMBER, font, skipBoxes)` - Draw coins with numbers (2048 mode)
- `graphics.drawBoxes(boxes, BOX_ROWS)` - Draw box grid (classic mode)
- `graphics.drawBoxes2048(boxes, BOX_ROWS, shakeState)` - Draw box grid with shake (2048 mode)
