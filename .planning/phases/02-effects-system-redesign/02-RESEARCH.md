# Phase 2: Effects System Redesign - Research

**Researched:** 2026-04-05
**Domain:** LOVE2D particle/effects system, web/WASM performance, visual feedback patterns
**Confidence:** HIGH

## Summary

This phase redesigns the existing `particles.lua` system from a binary LOW/HIGH tier into a three-tier quality system (HIGH/MED/LOW), adds new visual effect types for merges, chest opens, resource gains, and UI polish, all while ensuring 50-60fps on browser/WASM builds. The current codebase has a solid foundation: a pre-allocated pool with SpriteBatch rendering in `particles.lua` (267 lines), a dual-track animation state machine in `animation.lua` (894 lines) with screen shake and merge callbacks, and platform detection via `mobile.isLowPerformance()`. The codebase uses NO shaders and NO `love.graphics.ParticleSystem` -- everything is custom Lua with SpriteBatch.

The primary risk is GC pressure from Lua table allocations during effect spawning on WASM/Emscripten, where the Lua GC runs inside a single-threaded WASM sandbox. The existing pool pattern in `particles.lua` already addresses this for the main particle type, but new effect types (fly-to-bar icons, pulse animations, glow overlays) will need the same pre-allocation discipline. The Arena merge effects (glow/dissolve) should use alpha-tween on existing draw primitives rather than shaders, keeping the implementation simple and web-compatible.

**Primary recommendation:** Extend the existing `particles.lua` pool+SpriteBatch architecture with a tiered config system and add new effect modules (`effects.lua` for screen-level effects like fly-to-bar and flash overlays, plus tween extensions in each screen module). Do NOT introduce LOVE2D's built-in `ParticleSystem` or GLSL shaders -- the current approach is already optimized for this codebase's constraints.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Merge celebrations use a "satisfying pop" style -- enhanced particles + screen shake + brief flash, amplifying the existing chunky fragment aesthetic rather than introducing new visual paradigms
- **D-02:** Effect intensity scales with coin level -- low merges (L2-L3) get a small pop, high merges (L5+) get full celebration with more particles, stronger shake, and optional brief flash
- **D-03:** Coin Sort and Arena have mode-specific merge effects -- CS coins explode into chunky fragments (current style, amplified), Arena items glow/dissolve into the merged result rather than exploding (kitchen objects don't shatter like coins)
- **D-04:** Chest opens use a "lid pop + item reveal" sequence -- chest shakes briefly, lid pops off with chain-colored particles, item rises up and settles into its grid cell. Each tap is a mini-reveal moment
- **D-05:** Resource gains (Fuel/Stars from merges) use icon fly-to-bar -- small fuel/star icons fly from the merge point to the corresponding resource bar at the top, showing where the resource went
- **D-06:** Big rewards (level completions, large star gains, commission completions) get a distinct celebration -- brief overlay flash or radial star burst, separate from the normal fly-to-bar treatment. Makes big moments feel meaningfully different from routine gains
- **D-07:** Button press feedback uses scale bounce -- button shrinks to ~95% on press, bounces back with subtle overshoot. Quick and tactile, works well for mobile touch
- **D-08:** Tab bar switches are instant (no slide/crossfade animation) but the active tab highlight/underline slides smoothly to the new position. Fast, doesn't block gameplay
- **D-09:** Actionable items get subtle pulse feedback -- generators with charges gently pulse, completed orders glow. Helps players identify what's interactive, especially useful for new players

### Claude's Discretion
- Quality tier system (HIGH/MED/LOW) -- how to detect platform capability, whether to allow player override, exact particle budgets per tier. Current binary IS_MOBILE gating in particles.lua is the starting point
- Exact particle counts, speeds, and timing curves for each effect
- GC pressure reduction strategy for web builds
- Whether high-level merges (L6-L7) get brief slow-mo or just more particles
- Arena glow/dissolve implementation approach (shader vs alpha tween vs particle overlay)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FX-01 | Particle system redesigned with tiered quality (HIGH/MED/LOW) and reduced GC pressure for web | Tier system architecture, pool pre-allocation strategy, GC reduction patterns |
| FX-02 | Web performance verified -- particles run at 50-60fps on browser/WASM during peak effects | Particle budget analysis, WASM/Emscripten perf characteristics, benchmark approach |
| FX-03 | Merge celebration effects -- particles, screen shake enhancement, coin fly-up on merge (both CS and Arena) | CS fragment explosion scaling, Arena glow/dissolve approach, screen shake amplification |
| FX-04 | Chest/reward effects -- particles on chest open, star gain animations, fuel gain animations | Chest shake+pop sequence, fly-to-bar animation pattern, big reward overlay flash |
| FX-05 | Button/UI polish -- button press feedback, hover glow, tab bar transition effects | Scale bounce pattern (already partially exists), tab highlight tween, pulse feedback |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **No goto** -- use `repeat/until` loops for retries. Goto breaks the web build.
- **Logic/visual separation** -- data modules have zero drawing code; screen modules handle all rendering. New effect logic modules must follow this pattern.
- **File size limit** -- suggest refactoring when files exceed 1.5k lines. `arena_screen.lua` (1437 lines) and `coin_sort_screen.lua` (1206 lines) are already near limit -- new effects code should go in separate modules, not bloat screen files.
- **LOVE2D and Lua best practices** -- use idiomatic patterns.
- **Document what you have done** -- update CLAUDE.md module table for new files.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| LOVE2D | 12.0 (web builder) / 11.5 (desktop) | Game framework | Already in use, web build via love-web-builder [VERIFIED: love-web-builder-main/README.md] |
| Custom SpriteBatch particles | N/A (in-project) | Particle rendering | Already proven pattern in particles.lua -- O(1) alloc, 1 draw call [VERIFIED: particles.lua] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| love.graphics.SpriteBatch | Built-in | Batched particle rendering | All particle types -- extend existing batch [VERIFIED: particles.lua:56] |
| love.timer.getTime() | Built-in | Time-based pulse/glow animations | Pulse feedback on generators, glow on orders [VERIFIED: arena_screen.lua:540] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom SpriteBatch particles | love.graphics.ParticleSystem (built-in) | Built-in has C++ update loop (faster), but less control over individual particle behavior like bouncing, chunky rotation, and our swap-remove pool. Switching would require rewriting the entire particle aesthetic. **Keep custom.** |
| Alpha tween for Arena dissolve | GLSL shader dissolve | Shader would look smoother but adds complexity: GLSL compatibility issues between desktop (GLSL) and web (GLSL ES), no shaders in codebase currently, and dpiscale=1 canvas means per-pixel effects are less impactful. **Use alpha tween.** |
| Per-effect SpriteBatch | Single shared SpriteBatch | Multiple batches = multiple draw calls. Single batch with different sizes/colors is already the pattern. **Keep single batch, increase capacity.** |

**Installation:** No new dependencies required. All effects use existing LOVE2D APIs.

## Architecture Patterns

### Recommended Project Structure
```
particles.lua          # Redesigned: 3-tier config, expanded pool, new spawn functions
effects.lua            # NEW: Screen-level effects (fly-to-bar, overlay flash, big reward burst)
animation.lua          # Extended: enhanced screen shake, level-scaled intensity
coin_sort_screen.lua   # Modified: hook new CS merge effects, button polish
arena_screen.lua       # Modified: hook arena merge/chest effects, button polish
tab_bar.lua            # Modified: sliding highlight animation
mobile.lua             # Extended: 3-tier detection (getPerformanceTier)
```

### Pattern 1: Three-Tier Quality System
**What:** Replace binary `IS_MOBILE` flag with a 3-tier system that gates particle counts, effect complexity, and animation features.
**When to use:** Every effect spawn, every draw decision that scales with platform.

```lua
-- In mobile.lua (extend existing module)
-- Source: Codebase pattern from mobile.isLowPerformance()

local tier_cache = nil

function mobile.getPerformanceTier()
  if tier_cache then return tier_cache end
  if mobile.isMobile() then
    tier_cache = "LOW"
  elseif mobile.isWeb() then
    tier_cache = "MED"
  else
    tier_cache = "HIGH"
  end
  return tier_cache
end

-- Allow runtime override (future: settings menu)
function mobile.setPerformanceTier(t)
  tier_cache = t
end
```

**Tier budgets (recommendation):**

| Setting | HIGH (desktop) | MED (web/WASM) | LOW (mobile native) |
|---------|---------------|----------------|---------------------|
| MAX_PARTICLES | 200 | 100 | 50 |
| Spawn per burst | 12 | 7 | 4 |
| Merge explosion | 20 | 12 | 6 |
| Particle lifetime | 1.5s | 1.0s | 0.7s |
| Max bounces | 3 | 2 | 1 |
| Highlight pass | Yes | No | No |
| Fly-to-bar icons | Yes | Yes | Yes (fewer) |
| Overlay flash | Yes | Yes (shorter) | Alpha only |
| Screen shake mult | 1.0x | 1.0x | 0.7x |
| Generator pulse | Yes | Yes | Yes (simpler) |

### Pattern 2: Pre-Allocated Effect Pool (GC Reduction)
**What:** All effect objects (particles, fly icons, pulse states) are pre-allocated at init time and recycled via free-stack, never creating new tables during gameplay.
**When to use:** Every effect type that spawns during gameplay.

```lua
-- Pattern from existing particles.lua pool (proven)
-- Source: particles.lua:34-78 [VERIFIED: codebase]

-- Pre-allocate at init:
local pool = {}
local freeStack = {}
local freeCount = MAX_SIZE

for i = 1, MAX_SIZE do
    pool[i] = { x=0, y=0, vx=0, vy=0, lifetime=0, ... }
    freeStack[i] = i
end

-- Acquire (O(1), zero allocation):
local function acquire()
    if freeCount > 0 then
        local idx = freeStack[freeCount]
        freeCount = freeCount - 1
        return pool[idx], idx
    end
    return nil  -- pool exhausted
end

-- Release (O(1)):
local function release(idx)
    freeCount = freeCount + 1
    freeStack[freeCount] = idx
end
```

### Pattern 3: Logic/Visual Separation for Effects
**What:** New `effects.lua` module holds effect state and update logic (data only). Screen modules call `effects.draw*()` methods for rendering. This follows the project's established pattern where data modules have zero drawing code.
**When to use:** All new effect types that are shared across screens.

**Exception:** `effects.lua` will contain draw functions because effects ARE visual by nature. This is analogous to how `particles.lua` contains both update AND draw. The separation here is: effects module manages its own visual state; screen modules decide WHEN to trigger effects and WHERE coordinates come from.

### Pattern 4: Arena Glow/Dissolve via Alpha Tween
**What:** Arena merge effects use alpha-based animation on the existing geometric shape drawing, not shaders or particle overlays.
**When to use:** Arena merges (D-03 specifies glow/dissolve, not fragment explosion).

```lua
-- Arena merge: source item fades out while brightening (glow effect)
-- then merged result scales in with jelly tween (already exists as JELLY_DURATION)
-- Source: Design decision D-03

-- In the merge tween system (already slot_tweens in arena_screen.lua):
-- Add a "dissolve" style alongside existing "jelly" and elastic:
if tw.style == "dissolve_out" then
    -- Item brightens and fades out
    local t = tw.time / tw.duration
    local ease = t * t  -- accelerating
    tween_alpha = 1 - ease
    local glow = 1 + ease * 0.5  -- brighten colors by up to 50%
    draw_color_mult = glow
end
```

### Anti-Patterns to Avoid
- **Creating tables in update loops:** Every `{x, y, color}` created per frame becomes GC pressure. Pre-allocate all effect state. [CITED: lua-users.org/wiki/OptimisingGarbageCollection]
- **Multiple SpriteBatches for particles:** Each batch = 1 draw call. Keep particle types in a single batch where possible. [ASSUMED]
- **Shader-based effects on web:** The codebase has zero shaders. Adding shaders introduces GLSL/GLSL ES compatibility concerns and breaks the established rendering pattern. Alpha tweens achieve the required dissolve/glow effects without shader complexity.
- **Blocking animations:** D-08 explicitly says tab switches are instant. Never block gameplay for visual effects. Effects must be fire-and-forget or tied to existing non-blocking animation tracks.
- **Bloating screen files:** `arena_screen.lua` is 1437 lines, `coin_sort_screen.lua` is 1206 lines. Both approach the 1500-line refactoring threshold from CLAUDE.md. New effect integration code must be minimal in screen files -- put logic in `effects.lua`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Easing functions | Custom math per effect | Centralized easing table in effects.lua | Arena already has `easeOutElastic()` and `easeOutCubic()` as local functions -- extract and share |
| Per-particle physics | New physics system | Extend existing particles.lua bounce/gravity | Particles already have gravity, bounce damping, ground collision, side collision |
| Screen shake | New shake system | Extend animation.getScreenShake() | Already has shake intensity, duration, and decay -- just add level-scaling |
| Tab highlight slide | Custom interpolation | Simple lerp in tab_bar.draw() | Just track `current_highlight_x` and lerp toward target each frame |
| Pulse animation | Timer system | `math.sin(love.timer.getTime() * speed)` | Already used for chest pulse in arena_screen.lua:540 |

**Key insight:** The codebase already has 80% of the building blocks. The particle pool, SpriteBatch rendering, screen shake, easing functions, tween system, and pulse animations all exist in some form. This phase is about systematizing and expanding, not building from scratch.

## Common Pitfalls

### Pitfall 1: GC Stalls on Web/WASM
**What goes wrong:** Lua's garbage collector runs inside the single WASM thread. When many small tables are created (particle spawn, effect state, callbacks), GC pauses cause frame drops.
**Why it happens:** WASM doesn't have concurrent GC. Lua's incremental collector still pauses the main thread. On desktop this is imperceptible; on WASM with a 16ms frame budget, a 2-3ms GC pause causes visible stutter.
**How to avoid:** Pre-allocate ALL effect pools at init time. Never create tables during gameplay. Reuse fields via field-reset rather than creating new table instances. String concatenation in effect notifications should use pre-built strings or `string.format()` (which is faster than `..` chains). [CITED: lua-users.org/wiki/OptimisingGarbageCollection]
**Warning signs:** FPS drops that correlate with merge frequency, not particle count.

### Pitfall 2: SpriteBatch Capacity Overflow
**What goes wrong:** `SpriteBatch` has a fixed capacity set at creation. If effects exceed it, LOVE2D silently drops draws or errors.
**Why it happens:** Current batch capacity is `MAX_PARTICLES * 2` (for main quad + highlight). Adding new effect types to the same batch without increasing capacity causes overflow during peak activity.
**How to avoid:** Calculate max possible concurrent draws: particles (200) + highlights (200) + fly-icons (10) + flash quads (5) = 415 minimum. Set batch capacity to 500 with headroom. Or use a second SpriteBatch for fly-to-bar icons (different texture/quad needed anyway).
**Warning signs:** Missing particles during multi-merge celebrations.

### Pitfall 3: Fly-to-Bar Coordinate System Mismatch
**What goes wrong:** Fly-to-bar icons start at grid coordinates (inside screen shake transform) but target the resource bar (which should NOT shake). If drawn inside the shake push/pop, icons appear to jitter during flight.
**Why it happens:** Screen shake applies via `love.graphics.translate()` inside a push/pop block. Everything drawn inside that block shakes. The resource bar is drawn inside the shake block in `coin_sort_screen.lua:783`.
**How to avoid:** Draw fly-to-bar icons AFTER the shake pop, compensating source coordinates for shake offset. Or draw the resource HUD and fly icons in a separate non-shaking layer.
**Warning signs:** Flying icons that wobble/jitter during merge celebrations.

### Pitfall 4: Arena Screen File Size Explosion
**What goes wrong:** Adding chest open effects, merge glow/dissolve, resource fly-ups, generator pulse, and order glow all to `arena_screen.lua` pushes it past 1500 lines (already at 1437).
**Why it happens:** Natural tendency to add effect code inline where the trigger happens.
**How to avoid:** Create `effects.lua` with shared effect pools and draw functions. Screen files only call `effects.spawnFlyToBar(x, y, type)` and `effects.draw()`. Keep integration points minimal.
**Warning signs:** Any screen file exceeding 1500 lines triggers CLAUDE.md refactoring rule.

### Pitfall 5: Effect Timing Conflicts with Animation System
**What goes wrong:** New effects (celebration flash, fly-to-bar) play at the same time as existing merge/dealing animations, competing for visual attention or causing state confusion.
**Why it happens:** The animation system has a dual-track architecture (pick + background). Effects are a third layer. Without clear layering rules, effects can visually collide with animations.
**How to avoid:** Define a clear draw order: 1) Background, 2) Grid/coins, 3) Animation overlays, 4) Particles, 5) Fly-to-bar icons, 6) UI elements, 7) Overlay flash. Effects trigger FROM animation callbacks (onBoxMerge, coinLandCallback) which are already sequenced correctly.
**Warning signs:** Visual chaos during multi-box merges with simultaneous celebrations.

### Pitfall 6: Web Performance Without Baseline
**What goes wrong:** Phase success requires "50-60fps during peak effects" but no baseline measurement exists.
**Why it happens:** STATE.md notes: "Will need web profiling baseline before redesign -- no perf measurements exist yet."
**How to avoid:** First task must establish a web build + FPS baseline BEFORE making changes. The game already draws an FPS counter (`main.lua:166`). Test with current particles at peak (multi-box merge with max active particles). This baseline is the comparison point.
**Warning signs:** Making changes without knowing if the original already hits 50fps.

## Code Examples

### Example 1: Tiered Particle Config (particles.lua redesign)
```lua
-- Source: Extension of existing particles.lua pattern [VERIFIED: particles.lua:10-30]

local mobile = require("mobile")

-- Tier-based configuration tables
local TIER_CONFIG = {
    HIGH = {
        max_particles = 200,
        spawn_count = 12,
        merge_spawn_count = 20,
        lifetime = 1.5,
        merge_lifetime = 1.8,
        max_bounces = 3,
        highlight = true,
    },
    MED = {
        max_particles = 100,
        spawn_count = 7,
        merge_spawn_count = 12,
        lifetime = 1.0,
        merge_lifetime = 1.2,
        max_bounces = 2,
        highlight = false,
    },
    LOW = {
        max_particles = 50,
        spawn_count = 4,
        merge_spawn_count = 6,
        lifetime = 0.7,
        merge_lifetime = 0.9,
        max_bounces = 1,
        highlight = false,
    },
}

local config  -- set during init()

function particles.init()
    local tier = mobile.getPerformanceTier()
    config = TIER_CONFIG[tier]
    -- ... rest of pool init using config.max_particles
end
```

### Example 2: Level-Scaled Merge Celebration (CS mode)
```lua
-- Source: Extends existing onBoxMerge callback [VERIFIED: coin_sort_screen.lua:1071-1104]
-- D-02: Effect intensity scales with coin level

local MERGE_CELEBRATION = {
    -- [resulting_level] = { particle_mult, shake_mult, flash_duration }
    [2] = { particle_mult = 0.5, shake_mult = 0.5, flash = 0 },
    [3] = { particle_mult = 0.7, shake_mult = 0.7, flash = 0 },
    [4] = { particle_mult = 1.0, shake_mult = 1.0, flash = 0.05 },
    [5] = { particle_mult = 1.3, shake_mult = 1.2, flash = 0.08 },
    [6] = { particle_mult = 1.6, shake_mult = 1.5, flash = 0.12 },
    [7] = { particle_mult = 2.0, shake_mult = 2.0, flash = 0.15 },
}

-- In onBoxMerge callback:
local level = box_data.new_number
local celebration = MERGE_CELEBRATION[level] or MERGE_CELEBRATION[2]
-- Particles already spawn in animation.lua merge flow;
-- amplify via celebration.particle_mult
-- Enhanced shake: multiply animation.lua's existing SHAKE_INTENSITY
-- Brief flash: effects.spawnFlash(duration)
```

### Example 3: Fly-to-Bar Icon Pool
```lua
-- Source: New pattern for effects.lua, using particles.lua pool model

local MAX_FLY_ICONS = 15  -- max concurrent fly-to-bar animations

local fly_pool = {}
local fly_active = {}
local fly_count = 0
local fly_free = {}
local fly_free_count = MAX_FLY_ICONS

function effects.init()
    for i = 1, MAX_FLY_ICONS do
        fly_pool[i] = {
            x = 0, y = 0,
            target_x = 0, target_y = 0,
            time = 0, duration = 0.6,
            icon_type = "fuel",  -- "fuel" or "star"
            active = false,
        }
        fly_free[i] = i
    end
end

function effects.spawnFlyToBar(from_x, from_y, target_x, target_y, icon_type)
    if fly_free_count <= 0 then return end
    local idx = fly_free[fly_free_count]
    fly_free_count = fly_free_count - 1
    local icon = fly_pool[idx]
    icon.x = from_x
    icon.y = from_y
    icon.target_x = target_x
    icon.target_y = target_y
    icon.time = 0
    icon.icon_type = icon_type
    icon.active = true
    fly_count = fly_count + 1
    fly_active[fly_count] = idx
end
```

### Example 4: Tab Bar Sliding Highlight
```lua
-- Source: Extension of tab_bar.lua [VERIFIED: tab_bar.lua:36-92]

local highlight_x = 0      -- current animated x position
local highlight_target = 0  -- target x for active tab
local HIGHLIGHT_SPEED = 12  -- lerp speed

function tab_bar.draw(active_tab)
    local tab_w = VW / #TABS

    -- Calculate target highlight position
    for i, tab in ipairs(TABS) do
        if tab.id == active_tab then
            highlight_target = (i - 1) * tab_w
        end
    end

    -- Smooth lerp
    highlight_x = highlight_x + (highlight_target - highlight_x) * math.min(1, HIGHLIGHT_SPEED * love.timer.getDelta())

    -- Draw sliding indicator bar (replaces per-tab static bar)
    love.graphics.setColor(0.35, 0.75, 0.45)
    love.graphics.rectangle("fill", highlight_x + 20, TAB_Y, tab_w - 40, 3, 2, 2)
    -- ... rest of tab drawing
end
```

### Example 5: Chest Open Sequence (Arena)
```lua
-- Source: Based on D-04 decision, integrating with existing arena_screen.lua chest tap flow
-- [VERIFIED: arena_screen.lua:1302-1318]

-- Chest open is a multi-phase effect triggered from arena_screen mousereleased:
-- Phase 1: Chest shakes (0.2s) -- use existing shakeState pattern from coin_sort_screen
-- Phase 2: Lid pop -- brief scale up then particles in chain color
-- Phase 3: Item rises from chest position and settles into grid cell (gen_fly pattern)

-- Reuses existing patterns:
-- shakeState from coin_sort_screen.lua:38 (shake timing)
-- slot_tweens from arena_screen.lua:72 (pop-in elastic)
-- gen_fly from arena_screen.lua:77 (item flight to cell)
-- particles.spawnMergeExplosion (chain-colored burst)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Binary IS_MOBILE | 3-tier (HIGH/MED/LOW) | This phase | Web gets a middle ground instead of worst-case mobile settings |
| Flat particle counts | Level-scaled celebrations | This phase | L7 merges feel dramatically different from L2 merges |
| Text-only resource popups | Icon fly-to-bar | This phase | Spatial feedback connects merge location to resource bar |
| Static buttons | Scale-bounce press feedback | Partially exists | `buttonState` with `BUTTON_PRESS_SCALE` already in coin_sort_screen.lua:56-59 |
| No Arena merge effects | Glow/dissolve tween | This phase | Arena merges feel distinct from CS merges (D-03) |

**Already partially implemented:**
- Button press feedback: `buttonState.add/merge` with `BUTTON_PRESS_SCALE = 0.85` exists in `coin_sort_screen.lua:56-59` [VERIFIED: codebase]
- Chest pulse: `math.sin(love.timer.getTime() * 3)` pulse already on chests in `arena_screen.lua:540` [VERIFIED: codebase]
- Pop-in tweens: `slot_tweens` with elastic and jelly styles already in `arena_screen.lua:72-74` [VERIFIED: codebase]
- Resource popups: Float-up text already in `coin_sort_screen.lua:91-174` [VERIFIED: codebase]
- Box unlock flash: `box_unlock_flashes` already in `coin_sort_screen.lua:99-101` [VERIFIED: codebase]

## Assumptions Log

> List all claims tagged `[ASSUMED]` in this research.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Multiple SpriteBatches cause meaningful performance overhead vs single batch | Anti-Patterns | LOW -- could use separate batch for fly icons if needed; performance difference is marginal for 2-3 batches |
| A2 | WASM GC pauses are 2-3ms for Lua incremental collector | Pitfall 1 | MEDIUM -- actual numbers depend on allocation rate; baseline benchmark will validate |
| A3 | Web tier should be MED (between desktop HIGH and mobile LOW) | Pattern 1 | LOW -- web is slower than desktop but has more resources than mobile; MED is a safe default |
| A4 | 200 max particles is sufficient for HIGH tier peak effects | Tier budgets | LOW -- current MAX is 150 for desktop; 200 gives 33% headroom with new celebration effects |

**If this table is empty:** N/A -- four assumptions identified above.

## Open Questions

1. **High-level merge slow-mo (L6-L7)**
   - What we know: D-02 says L5+ get "full celebration." Claude's Discretion includes whether L6-L7 get brief slow-mo or just more particles.
   - What's unclear: Whether slow-mo (reducing `SPEED_MULT` briefly) enhances or disrupts the game feel.
   - Recommendation: Start with "just more particles + stronger shake + longer flash" for L6-L7. Slow-mo can be added later if the celebration doesn't feel impactful enough. Simpler to implement and doesn't risk disrupting animation timing.

2. **Player performance tier override**
   - What we know: Claude's Discretion mentions whether to allow player override of quality tier.
   - What's unclear: Whether the game needs a settings screen for this.
   - Recommendation: Implement `mobile.setPerformanceTier()` API now but don't build a settings UI. Can be exposed later. The auto-detection (desktop=HIGH, web=MED, mobile=LOW) covers the common cases.

3. **Fly-to-bar icon rendering**
   - What we know: D-05 says fuel/star icons fly from merge point to resource bar.
   - What's unclear: What the icons look like -- use `ball.png` tinted gold/blue? Simple colored circles? Text (+1)?
   - Recommendation: Use simple colored circles (fuel=orange, stars=blue) for the flying icon, matching the existing resource bar colors. No need for new sprite assets. These are small, fast-moving -- simple shapes work fine.

4. **Big reward overlay flash scope**
   - What we know: D-06 says big rewards get a "distinct celebration -- brief overlay flash or radial star burst."
   - What's unclear: Whether this is a full-screen white flash (alpha overlay) or a localized radial burst.
   - Recommendation: Full-screen white flash (alpha 0.3 -> 0 over 0.3s) for level completions. Cheaper than radial burst, unmissable, and trivial to implement. Can combine with resource fly-to-bar for the stars/bags earned.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| LOVE2D | All effects | Yes | 11.5 (desktop) / 12.0 (web) | -- |
| love-web-builder | FX-02 web testing | Yes | love-web-builder-main/ in repo | -- |
| Web browser | FX-02 verification | Yes | System browser | -- |
| SpriteBatch API | Particle rendering | Yes | Built-in | -- |
| love.timer.getTime() | Pulse/glow animations | Yes | Built-in | -- |

**Missing dependencies with no fallback:** None
**Missing dependencies with fallback:** None

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual visual testing + FPS counter |
| Config file | None -- LOVE2D game, no automated test framework |
| Quick run command | `love /home/username/Documents/Coins-Boxes/` |
| Full suite command | `love /home/username/Documents/Coins-Boxes/` + manual verification |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FX-01 | Tiered quality system loads correct config per platform | manual-only | Desktop: `love .` and verify HIGH tier; no automated platform switching | N/A |
| FX-02 | 50-60fps during peak effects on web | manual-only | Build web: `cd love-web-builder-main && ./build.sh ..` then open in browser, trigger multi-merge, read FPS counter | N/A |
| FX-03 | Merge celebrations visible in both CS and Arena | manual-only | `love .` -> CS: merge coins at various levels, verify particle scaling; Arena: merge items, verify glow/dissolve | N/A |
| FX-04 | Chest/reward effects play correctly | manual-only | `love .` -> Arena: tap chest, verify shake+pop+particles; merge for resources, verify fly-to-bar | N/A |
| FX-05 | Button feedback and UI polish | manual-only | `love .` -> tap buttons, verify scale bounce; switch tabs, verify sliding highlight; check generator pulse | N/A |

**Justification for manual-only:** LOVE2D games do not have a standard automated test runner. Visual effects are inherently visual and require human verification. The FPS counter (`main.lua:166`) provides quantitative performance data during manual testing.

### Sampling Rate
- **Per task commit:** `love /home/username/Documents/Coins-Boxes/` -- quick visual smoke test
- **Per wave merge:** Web build + browser FPS verification
- **Phase gate:** Full manual verification of all 5 requirements + web FPS baseline comparison

### Wave 0 Gaps
- None -- no automated test infrastructure needed. Manual testing via `love .` and web builds.

## Security Domain

> Not applicable. This phase is purely visual effects within a client-side game. No authentication, session management, access control, input validation from untrusted sources, or cryptography is involved. All effect parameters are hardcoded, not user-configurable via input.

## Sources

### Primary (HIGH confidence)
- `particles.lua` (267 lines) -- current pool+SpriteBatch particle system, fully analyzed [VERIFIED: codebase]
- `animation.lua` (894 lines) -- dual-track animation, screen shake, merge/deal callbacks [VERIFIED: codebase]
- `mobile.lua` (81 lines) -- platform detection, isLowPerformance() [VERIFIED: codebase]
- `arena_screen.lua` (1437 lines) -- slot_tweens, gen_fly, chest tap, merge execution [VERIFIED: codebase]
- `coin_sort_screen.lua` (1206 lines) -- resource popups, button animation, merge callbacks [VERIFIED: codebase]
- `tab_bar.lua` (112 lines) -- tab drawing, highlight, badge system [VERIFIED: codebase]
- `graphics.lua` (274 lines) -- coin rendering, SpriteBatch usage, metrics caching [VERIFIED: codebase]
- `love-web-builder-main/README.md` -- LOVE 12.0 Emscripten port [VERIFIED: codebase]

### Secondary (MEDIUM confidence)
- [LOVE2D forums - Particles optimization](https://love2d.org/forums/viewtopic.php?t=81808) -- community discussion on SpriteBatch vs ParticleSystem tradeoffs
- [LOVE2D forums - SpriteBatch performance](https://love2d.org/forums/viewtopic.php?t=78271) -- draw call reduction benefits
- [LOVE2D wiki - Shader](https://love2d.org/wiki/Shader) -- GLSL/GLSL ES compatibility considerations

### Tertiary (LOW confidence)
- [Lua-users wiki - Optimising Garbage Collection](http://lua-users.org/wiki/OptimisingGarbageCollection) -- table reuse patterns, general GC advice (not WASM-specific)
- [V8 blog - WASM GC](https://v8.dev/blog/wasm-gc-porting) -- WASM GC context (not Lua-specific)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all technology is already in the codebase, no new dependencies
- Architecture: HIGH -- extending proven patterns (pool, SpriteBatch, callbacks), not introducing new paradigms
- Pitfalls: HIGH -- identified from direct codebase analysis (file sizes, coordinate systems, GC patterns)
- Performance targets: MEDIUM -- 50-60fps target is reasonable but needs baseline measurement to confirm

**Research date:** 2026-04-05
**Valid until:** 2026-05-05 (stable -- LOVE2D APIs don't change frequently)
