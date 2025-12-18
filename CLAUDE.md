# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Do no try to test the project running in with love . .User will test it on its own.

## Architecture

**Module Structure:**
- `main.lua` - Entry point with LÖVE callbacks (load/update/draw/input). Handles rendering, UI, and input coordination.
- `game.lua` - Game state and mechanics module. Exports functions via table: `game.init()`, `game.getState()`, `game.merge()`, `game.add_coins()`, `game.pick_from_box()`, `game.place_into_box()`
- `animation.lua` - Coin animation system for hover (bobbing) and flight (arc trajectory) effects
- `utils.lua` - Utility functions including `each_coin()` iterator and debugger setup
- `conf.lua` - LÖVE window configuration (resizable, HiDPI)
- `layout.lua` - Centralized layout configuration (canvas size, element positions, scaling)
- `screens.lua` - Screen management system with mode selection and game screens
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
- `mode_select` - Initial menu with game mode buttons ("Classic Mode", "Coming Soon...")
- `game` - Main gameplay screen (defined in main.lua as `game_screen`)

**Adding New Screens:**
1. Create a screen table with required methods in `screens.lua`
2. Register it with `screens.register("screen_name", screen_table)`
3. Add a button in `mode_select` to switch to it

## Animation System (animation.lua)

Handles visual animations when picking up and placing coins.

**Animation States:**
- `IDLE` - No animation active
- `HOVERING` - Coins bob up and down after being picked up, spread horizontally
- `FLYING` - Coins fly in arc trajectory to destination, dropping one by one

**Public API:**
- `animation.startHover(coins, source_box_index)` - Begin hover animation with bobbing
- `animation.startFlight(dest_box_idx, dest_slot, callback, coinLandCallback)` - Begin flight to destination
- `animation.update(dt)` - Called from `game_screen.update(dt)`
- `animation.draw(ballImage, COLORS)` - Called from `game_screen.draw()` after `draw_all_coins()`
- `animation.isAnimating()`, `isHovering()`, `isFlying()` - State queries
- `animation.getHoveringCoins()` - Get array of hovering coin colors
- `animation.cancel()` - Reset to idle state

**Animation Flow:**
1. Click box with coins → `startHover()` → coins bob up/down, spread horizontally
2. Click destination box → `startFlight()` → coins fly in arc, drop one by one
3. Each coin landing triggers `coinLandCallback` (adds to box, plays sound)
4. All landed → `callback` fires, animation returns to IDLE

**Configuration (in animation.lua):**
- `HOVER_BOB_AMPLITUDE = 15` - Pixels up/down for bobbing
- `HOVER_BOB_SPEED = 1.5` - Bobbing cycles per second
- `HOVER_SPREAD = 90` - Pixels between coins while hovering
- `FLIGHT_DURATION = 0.35` - Seconds per coin flight
- `FLIGHT_ARC_HEIGHT = 150` - Arc height above trajectory
- `DROP_DELAY = 0.15` - Delay between each coin starting to drop

**Key Math:**
- Bobbing: `y = amplitude * sin(time * speed * 2π + phase)`
- Flight: Quadratic bezier curve with ease-out: `t_eased = 1 - (1-t)²`

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
