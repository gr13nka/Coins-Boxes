# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Do no try to test the project running in with love . .User will test it on its own.

## Architecture

**Module Structure:**
- `main.lua` - Entry point with LÖVE callbacks (load/update/draw/input). Handles rendering, UI, and input coordination.
- `game.lua` - Game state and mechanics module. Exports functions via table: `game.init()`, `game.getState()`, `game.merge()`, `game.add_coins()`, `game.pick_from_box()`, `game.place_into_box()`
- `utils.lua` - Utility functions including `each_coin()` iterator and debugger setup
- `conf.lua` - LÖVE window configuration (resizable, HiDPI)
- `layout.lua` - Centralized layout configuration (canvas size, element positions, scaling)
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
