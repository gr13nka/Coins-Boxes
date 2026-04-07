# Codebase Structure

**Analysis Date:** 2026-04-05

## Directory Layout

```
Coins-Boxes/               # Project root — all .lua files live here (flat)
├── main.lua               # LOVE2D entry point, window setup, LOVE callbacks
├── conf.lua               # LOVE2D window config, debugger bootstrap
│
├── screens.lua            # Screen manager + dormant mode_select screen
│
├── coin_sort_screen.lua   # Coin Sort gameplay UI + input
├── arena_screen.lua       # Merge Arena UI + input (drag-and-drop, orders strip)
├── game_over_screen.lua   # Post-run stats and Continue button
├── skill_tree_screen.lua  # PoE-style upgrade tree UI (pannable canvas)
│
├── coin_sort.lua          # Coin Sort game logic (pure data, no draw)
├── arena.lua              # Merge Arena game logic (pure data, no draw)
├── arena_chains.lua       # 12 chain definitions + generator drop tables (static data)
├── arena_orders.lua       # 10-level order data + completion/reward logic (static data)
│
├── resources.lua          # Fuel + Stars resource system (pure data)
├── bags.lua               # Coin bag inventory + free-bag timer (pure data)
├── powerups.lua           # AutoSort + Hammer consumable counts (pure data)
├── drops.lua              # Cross-mode variable drop system (pure data)
├── commissions.lua        # Coin Sort session commissions (pure data)
├── skill_tree.lua         # PoE2-style skill tree nodes + query API (pure data)
├── progression.lua        # Single save file, all persistence (pure data)
│
├── animation.lua          # Dual-track animation state machine (pick/flight + merge/deal)
├── graphics.lua           # Shared coin/box rendering primitives (no UI buttons)
├── particles.lua          # Particle pool + SpriteBatch
├── layout.lua             # Virtual canvas constants + grid metric computation
├── input.lua              # Hit testing + screen-to-game coordinate conversion
├── tab_bar.lua            # Bottom tab bar UI component
├── sound.lua              # Sound loading, playback, toggle state
├── coin_utils.lua         # Coin number → color mapping + coin object helpers
├── utils.lua              # each_coin() iterator
├── mobile.lua             # OS/platform detection, haptic feedback
├── yandex.lua             # Yandex Games SDK bridge via Emscripten FFI
│
├── currency.lua           # Shard/crystal currency (legacy, not in active loop)
├── upgrades.lua           # Permanent row/column/house upgrades (legacy)
├── game.lua               # Classic mode logic (legacy, dormant)
├── game_screen.lua        # Classic mode screen (legacy, dormant)
├── upgrades_screen.lua    # Upgrades UI screen (legacy, dormant)
├── emoji.lua              # Procedurally drawn food emoji icons (legacy UI)
├── tutorial.lua           # Placeholder (empty stub)
├── lldebugger.lua         # VS Code Lua debugger adapter (dev tool, not game logic)
│
├── assets/                # Sprites
│   ├── ball.png           # Single coin sprite (tinted per coin color at runtime)
│   ├── add_button.png / add_button_pressed.png
│   ├── merge_button.png / merge_button_pressed.png
│   └── Red.png, Green.png, Blue.png, Purple.png, Pink.png  # Color swatches (legacy)
│
├── sfx/                   # Sound effects (.ogg)
├── bgnd_music/            # Background music (.mp3)
├── comic shanns.otf       # Custom UI font (used for all text)
│
├── .planning/             # GSD planning documents (not shipped)
│   └── codebase/          # Codebase analysis documents
├── .github/workflows/     # CI: deploy-itch.yml
├── love-web-builder-main/ # Web export toolchain (Emscripten/love.js)
├── .vscode/               # VS Code debug launch config
├── CLAUDE.md              # Project instructions + module table
└── MOBILE_BUILD.md        # Mobile/web build notes
```

## Directory Purposes

**Root (`.lua` files):**
- Purpose: All game source code lives flat in the project root. No subdirectories for Lua source.
- Key files: `main.lua` (entry), `screens.lua` (screen manager), every `*_screen.lua` (UI), every module without `_screen` (logic/data)

**`assets/`:**
- Purpose: All sprites. Loaded once in `love.load()` and passed to screens via the `assets` bundle table.
- Key files: `ball.png` — the only coin sprite; tinted at draw time by `graphics.lua` using `love.graphics.setColor()`.

**`sfx/`:**
- Purpose: Sound effect files (.ogg). Loaded by `sound.lua`.

**`bgnd_music/`:**
- Purpose: Background music tracks (.mp3). `sound.lua` loads the active track as a streaming source.

**`.planning/codebase/`:**
- Purpose: GSD codebase analysis documents (this file's home).
- Generated: Yes (by GSD commands)
- Committed: Yes

**`love-web-builder-main/`:**
- Purpose: Web export toolchain. Contains `lovejs_source/` with Emscripten compatibility shims and HTML theme.
- Generated: No (vendored)
- Committed: Yes

## Key File Locations

**Entry Points:**
- `main.lua`: LOVE2D callbacks (`love.load`, `love.update`, `love.draw`, `love.mousepressed`, `love.mousereleased`, `love.mousemoved`, `love.focus`, `love.quit`)
- `conf.lua`: LOVE2D window config evaluated before `love.load`

**Screen Registration:**
- `main.lua` lines 126–142: `require()` each screen, call `.init(assets)`, then `screens.register(name, screen)`

**Persistence:**
- `progression.lua`: `SAVE_FILENAME = "progression.dat"` — saved via `love.filesystem.write()` to the LOVE2D save directory
- Save is triggered by each logic module after state-mutating operations, or batched in `arena.save()`

**Layout Constants:**
- `layout.lua`: `VW = 1080`, `VH = 1920` (virtual canvas). Arena screen overrides VH to 1920 but uses a local `GRID_TOP_Y = 260`. All pixel positions for UI elements are defined here or as local constants inside each screen module.

**Core Game Logic:**
- Coin Sort rules: `coin_sort.lua` (`executeMergeOnBox()`, `computeDeal()`, `canMerge()`, `autoSort()`)
- Arena rules: `arena.lua` (`mergeItems()`, `tapGenerator()`, `moveItem()`, `tapDispenser()`)

**Chain/Order Data:**
- `arena_chains.lua`: `CHAIN_DATA` table — all 12 chains, items, colors, generator thresholds, produce tables
- `arena_orders.lua`: `ORDERS` table — 10 levels × N orders each, reward specs

**Skill Tree Node Definitions:**
- `skill_tree.lua`: `NODES` table — 30 nodes with id, type, cost, description, grid position, connections

**Asset Loading:**
- `main.lua` lines 90–122: all images and fonts loaded here, bundled into `assets` table
- `sound.lua`: `sound.init()` loads all audio sources

**Testing:**
- No test files present. Manual testing only.

## Naming Conventions

**Files:**
- `snake_case.lua` for all source files
- `*_screen.lua` suffix: UI + input screen modules
- `*_chains.lua` / `*_orders.lua` suffix: static data modules for arena subsystems

**Lua modules:**
- Each file returns a single table: `local module_name = {}` ... `return module_name`
- Public functions: `module_name.functionName()` (camelCase function names)
- Private/local functions: `local function camelCase()` inside the module file
- Local constants: `SCREAMING_SNAKE_CASE` (e.g., `GRID_COLS`, `MERGE_OUTPUT`, `GEN_CHARGE_TABLE`)
- Local state variables: `snake_case` (e.g., `local grid = {}`, `local fuel = 0`)

**Directories:**
- All lowercase, no hyphens in Lua source dirs. Vendor/tooling dirs use original naming (`love-web-builder-main`).

**Assets:**
- Sprites: `snake_case.png`
- Sound effects: `kebab-case-N.ogg` (e.g., `chip-lay-2.ogg`)

## Where to Add New Code

**New game screen:**
1. Create `my_screen.lua` with `local my_screen = {}` and optional screen methods (`enter`, `exit`, `update`, `draw`, `mousepressed`, `mousereleased`, `keypressed`, `mousemoved`)
2. Add `my_screen.init(assets)` to receive the shared asset bundle from `main.lua`
3. In `main.lua`: `require("my_screen")`, call `.init(assets)`, call `screens.register("my_screen", my_screen)`
4. Add tab to `tab_bar.lua`'s `TABS` array if it needs a tab bar entry

**New pure-data logic module:**
1. Create `my_module.lua` at project root with `local my_module = {}` ... `return my_module`
2. Add `init()` that loads from `progression.lua` and `save()` that writes back
3. Add a data slice in `progression.lua`'s `getDefaultData()` and getter/setter functions
4. `require()` in `main.lua`'s `love.load()` and call `my_module.init()`

**New static data module:**
1. Create `my_data.lua` at project root — no `init()`, no `save()`, just a table of constants
2. `require()` only from modules that need it (no registration in main)

**New persistent data field:**
1. Add field to the appropriate slice in `progression.lua`'s `getDefaultData()` (handles fresh installs)
2. Add migration/default in the relevant module's `init()` (handles old saves missing the field)

**New arena chain:**
1. Add entry to `CHAIN_DATA` in `arena_chains.lua` with `name`, `color`, `items`, optional `generator_threshold`, `produces`
2. Add chain ID to `CHAIN_IDS` array in `arena_chains.lua`
3. If it has a generator, add a skill tree node in `skill_tree.lua`'s `NODES` and wire `CHAIN_PRODUCER` mapping in `arena_orders.lua`

**New skill tree node:**
1. Add entry to `NODES` in `skill_tree.lua` with `name`, `type` (small/notable/keystone), `cost`, `desc`, `x`, `y`, `connections`
2. Add query function to `skill_tree.lua` if the node grants a new capability
3. Add that query to the relevant logic module (lazy `require("skill_tree")` inside the function)

**New drop type:**
1. Add chance table to `drops.lua`
2. Add state variable and init/sync in `drops.lua`
3. Add apply logic to the relevant screen's `enter()` (for CS drops) or `arena.lua` callback (for arena drops)

## Special Directories

**`.planning/`:**
- Purpose: GSD workflow planning and codebase analysis documents
- Generated: Yes
- Committed: Yes

**`love-web-builder-main/`:**
- Purpose: Vendored web export toolchain
- Generated: No
- Committed: Yes
- Note: Contains `lovejs_source/compat/` (Emscripten shims) and `lovejs_source/theme/` (HTML wrapper)

**`.github/workflows/`:**
- Purpose: CI pipeline — `deploy-itch.yml` automates builds and uploads to itch.io
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-04-05*
