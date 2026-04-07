# Feature Landscape

**Domain:** Merge puzzle game (mobile/web) -- v1.0 release polish features
**Researched:** 2026-04-05
**Confidence:** MEDIUM (research based on merge genre conventions, LOVE2D ecosystem knowledge, and codebase analysis)

## Scope

This document covers ONLY the four new feature areas for the v1.0 release polish milestone:

1. Effects system redesign (particles/visual effects)
2. Spotlight tutorial system (Coin Sort + Arena rebuild)
3. Persistent commissions (cross-session, cross-mode)
4. Reward popups (celebration moments)

Each section maps features to table stakes / differentiator / anti-feature, notes complexity relative to the existing codebase, and identifies dependencies on existing modules.

---

## 1. Effects System Redesign

The current `particles.lua` uses an active-list pool + SpriteBatch for coin fragment particles. It already has mobile-aware config (`IS_MOBILE` halves counts/lifetimes). The problem: it causes lag on web/WASM during Coin Sort despite these optimizations. The redesign must support MORE effect types while using LESS GPU/CPU budget.

### Table Stakes

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| Merge explosion particles | Core "juice" -- every merge game has satisfying burst feedback on merge | Low (exists) | `particles.lua`, `animation.lua` | Already implemented but causes web lag. Must survive redesign, not be removed. |
| Coin landing feedback | Visual confirmation that a coin arrived at destination | Low | `animation.lua` callbacks | Currently handled by particle spawn in `coinLandCallback`. Needs lightweight alternative for web. |
| Alpha fade + scale decay on particles | Particles that pop in and fade out gracefully, not hard-cut | Low (exists) | `particles.lua` | Already implemented (last 30% lifetime fade, 0.7+0.3*ratio scale). Keep as-is. |
| Frame-rate independent animation | Effects must look identical at 30fps and 60fps | Low (exists) | `animation.lua` dt-based | Already dt-based. Just don't introduce frame-count-dependent code. |
| Web performance budget: 60fps with effects active | Merge games set 60fps as baseline. Frame drops during effects feel broken. | High | `particles.lua`, `main.lua` canvas pipeline | THE core constraint. Current system fails this on web. |

### Differentiators

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| Effect type registry / pluggable effects system | Decouple effect definitions from the pool/renderer so new effects (star gains, chest opens, button presses) can be added without touching the core engine | Medium | New `effects.lua` module | Current system is particles-only. A registry pattern lets each screen register effect types without modifying the pool. |
| Canvas-based effect compositing | Render effects to a separate canvas, composite in `main.lua` draw. Allows blur, glow, or opacity on the entire effects layer without per-particle cost. | Medium | `main.lua` canvas pipeline | LOVE2D supports multiple canvases cheaply. Drawing effects to a separate canvas then compositing = 1 extra draw call but enables layer-level effects. |
| Tiered effect quality (3 levels) | Instead of binary IS_MOBILE, support HIGH/MEDIUM/LOW quality with graceful degradation. Web gets MEDIUM, native mobile gets LOW, desktop gets HIGH. | Low | `mobile.lua` | Current binary LOW/HIGH is too coarse. A 3-tier system lets web run more effects than native mobile while staying under budget. |
| Screen shake scaling with effect intensity | Already partially exists for merge. Extending it to other big moments (chest open, level up) makes the game feel reactive. | Low | `animation.lua` `getScreenShake()` | Already implemented for merges. Just needs parameterized intensity for new trigger points. |
| Star/resource gain fly animation | Numbers or icons that fly from the merge point to the resource counter (fuel bar, star display). Standard in Merge Mansion, Merge Dragons. | Medium | `resources.lua` display positions, new tween in effects system | Not a particle -- it is a UI tween. Needs a lightweight "flyTo" animation system separate from the particle pool. |
| Button press juice (scale bounce + color flash) | Tactile feedback on buttons. `coin_sort_screen.lua` already has `buttonState` with press scale. Needs to be generalized. | Low | Screen modules' button rendering | `BUTTON_PRESS_SCALE = 0.85` and `BUTTON_ANIM_SPEED = 12` exist in CS screen. Extract to a shared utility. |
| Chest open burst effect | Dramatic visual when tapping a chest on the arena grid. Merge games make chest/crate opening a mini-celebration. | Medium | Arena chest tap in `arena_screen.lua`, effects system | New effect type. Colored burst matching chest's `chain_id` color. Should use the effect registry, not hardcode in arena_screen. |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| LOVE2D built-in ParticleSystem | Tempting because it is built-in, but it allocates per-system, has no pooling across types, and its API changed between LOVE2D 11 and 12. The custom pool in `particles.lua` is already more performant for this use case. | Keep and extend the custom pool. It already does O(1) alloc, swap-remove, SpriteBatch. |
| Per-particle shaders | Applying a GLSL shader per particle kills the SpriteBatch batching advantage. WebGL shader switches are expensive. | Apply shaders at the canvas/layer level if needed (e.g., bloom on the entire effects canvas), never per-particle. |
| Continuous background ambient particles | Floating sparkles, dust, idle effects that run even when nothing is happening. These chew through the web perf budget for zero gameplay value. | Only spawn effects in response to player actions or game events. No idle particles. |
| Complex physics (springs, cloth, ropes) | Overkill for a merge puzzle. CPU cost does not justify the visual. | Stick with ballistic trajectories (gravity + bounce) and simple tweens. |
| HDR / bloom post-processing on web | WebGL 1.0 (which Emscripten/LOVE2D targets) has limited post-processing support. Bloom requires render-to-texture + blur passes = frame budget destroyer. | Use additive blending on bright particles for a "fake glow" effect. One `love.graphics.setBlendMode("add")` call, zero extra passes. |

---

## 2. Spotlight Tutorial System

The current arena tutorial is an 18-step state machine with tooltip text and cell highlighting. It has known bugs (step 8/9 duplicate handlers). Coin Sort has NO tutorial at all. The v1.0 plan is spotlight-style tutorials for both modes: a dark mask with a cutout over the target element, controlled interaction (only the spotlighted element is tappable).

### Table Stakes

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| Dark overlay with spotlight cutout | Industry standard for guided tutorials. Merge Mansion, Merge Dragons, and virtually every top merge game uses this pattern. Player sees only the target. | Medium | LOVE2D stencil API (12.0 uses new `setStencilMode`/`setStencilState` replacing deprecated `stencil`/`setStencilTest`), screen draw pipeline | Core rendering challenge. Draw semi-transparent black rect over entire screen, use stencil to cut out the spotlight region. LOVE2D 12.0 changed the stencil API -- must use the new `setStencilMode` functions, not the deprecated 11.x API. |
| Controlled interaction (only spotlight area tappable) | Without this, players tap randomly and break the guided flow. The current arena tutorial does NOT restrict input -- hence the bugs. | Medium | `input.lua`, screen `mousepressed` handlers | Must intercept `mousepressed` at the screen level. If tutorial active and tap is outside spotlight bounds, consume the event (no-op). Bounds must match the visual cutout. |
| Tooltip / instruction text near spotlight | Player needs to know WHAT to do, not just WHERE. A short text label near the cutout. | Low | Font rendering, layout math | Already partially exists (`TUTORIAL_TOOLTIPS` in arena_screen). Needs positioning logic relative to the cutout (above if cutout is low, below if high). |
| Step-by-step state machine | Tutorial must advance only when the correct action is taken. | Low (exists for arena) | `arena.lua` tutorial state, new coin sort tutorial module | Arena already has `getTutorialStep()`. Coin Sort needs equivalent. Both should follow the same pattern for maintainability. |
| Skip / dismiss option | Some players already know the game. Forced un-skippable tutorials drive churn in casual games. Even Merge Mansion is criticized for long forced onboarding. | Low | Tutorial state machine | Add "Skip" button in corner. On skip, mark tutorial as complete, save to progression. Keep tutorials SHORT (5-8 steps for CS) so even non-skippers finish quickly. |
| Tutorial completion persistence | Must not replay on every session. | Low | `progression.lua` | Arena already saves `tutorial_step` in `arena_data`. Coin Sort needs `coin_sort_data.tutorial_complete = true` or similar. |

### Differentiators

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| Animated spotlight transition | Spotlight smoothly moves/resizes between steps instead of hard-cutting. Feels polished. | Medium | Tween system for spotlight x/y/w/h | Linear interpolation over ~0.3s. Needs 4 values tweened: cx, cy, width, height of cutout. |
| Hand pointer animation | An animated finger/hand icon pointing at the spotlight target. Universal "tap here" signifier used across mobile games. | Low | Sprite asset + simple bob animation | Need a hand pointer sprite. Animate it with a gentle up-down bob (sin wave, 2px amplitude). |
| Pulsing spotlight glow | The edge of the spotlight cutout pulses gently to draw attention. | Low | Additive blend circle at cutout edge | Draw a slightly larger circle with low alpha additive blend. Pulse alpha with sin(time*3). |
| Multi-shape spotlights | Rectangular cutouts for buttons/bars, circular for grid cells, pill-shaped for tab bar items. | Medium | Stencil drawing functions per shape | Stencil function draws the shape (rect, circle, rounded rect). Need a shape parameter in the tutorial step definition. |
| Contextual tooltip positioning | Tooltip with a small arrow/triangle pointing toward the spotlighted element. Auto-positions to avoid going off-screen. | Low-Medium | Layout math for arrow positioning | Calculate which side of the cutout has more space, place tooltip there, draw triangle pointing at cutout center. |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Tutorial that blocks ALL input including system controls | Players must always be able to leave. Trapping them feels like a bug. | Block game-area input only. Keep system buttons (tab bar if appropriate, volume toggle) functional. |
| Tutorial for every new feature unlock | "Tutorial creep" where every skill tree unlock or new chain triggers a guided sequence. Patronizing for engaged players. | Use tooltips or gentle highlights (non-blocking) for secondary features. Reserve spotlight tutorials for initial onboarding only. |
| Full-screen text instruction pages between steps | Walls of text between tutorial steps. Players do not read them. | One sentence per step, max 8-10 words. Show the action, do not explain the theory. |
| Replay tutorial button | Waste of dev effort. Virtually no one uses it. Adds UI clutter. | If someone needs it, they can reset progression (already exists via hold-3s reset button in coin_sort_screen). |
| Tutorial steps that wait for RNG outcomes | "Wait for a Level-5 merge" as a tutorial step is unpredictable. Player might wait forever. | All tutorial steps must have deterministic outcomes. Pre-place coins, force specific deals, or use hardcoded drops (arena tutorial already does this for steps 8-9). |

---

## 3. Persistent Commissions

Currently `commissions.lua` is purely per-session: `generate()` creates 2 commissions, they live in a local `active` table, rewards collected on game over via `collectRewards()`, then `clear()`. No persistence at all -- `progression.lua` has zero commission data slots. No cross-mode visibility. If the player switches to Arena mid-session, commission progress is invisible and lost on next CS init.

### Table Stakes

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| Commission state saved to disk | Must survive app close/reopen. Current system loses everything on session end. | Medium | `progression.lua` (add `commissions_data` slot), `commissions.lua` save/load | Need `commissions.sync()` + `progression.setCommissionsData()` + `progression.getCommissionsData()`. Follow existing pattern from `drops.lua` which does exactly this. |
| Commission progress visible from both modes | Player earns fuel in CS, should see commission progress update. When in Arena, should see CS commissions to know what to work toward. | Medium | `commissions.lua` API, `coin_sort_screen.lua`, `arena_screen.lua` | Draw a compact commission strip/card on both screens. CS shows full detail (active mode). Arena shows read-only summary with progress. |
| Commission refresh on timer or completion | Per-session refresh punishes players who close the app. Timer-based (e.g., every 8-24 hours) or refresh-on-all-complete is industry standard for casual games. | Medium | `commissions.lua` timer logic, `bags.lua` free bag timer as reference pattern | Follow `bags.lua` free bag timer pattern: store `refresh_timestamp` or elapsed timer, tick in `update(dt)`, generate new set when all complete or timer expires. |
| Progress bar / fraction indicator | Player must see how close they are (3/5 merges, 1/2 Level-5 coins). Without this, commissions feel invisible. | Low | `commissions.getActive()` already returns `progress`/`target` fields | UI only. Draw a small progress bar or "3/5" text. Data already exists in the commission objects. |
| Reward preview before completion | Player must know what they are working toward (2 Bags + 5 Stars). | Low | `commissions.lua` REWARDS table, already structured by difficulty | Show reward icons/text next to each commission card. Data already available. |
| Gate commissions against player capabilities | Never show "Create a Level-6 coin" to a player whose `max_coin_reached` is 3. Current system already gates by `max_coin` parameter but needs to be robust for persistence (player might unlock new levels between refreshes). | Low (partially exists) | `commissions.generate(max_coin)`, `progression.upgrades_data.max_coin_reached` | Current gating works. Just ensure persistent commissions re-validate on load (do not show impossible commissions from an old save). |

### Differentiators

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| Commission difficulty scaling with full progression | As player advances (higher `max_coin_reached`, more skill nodes), commissions scale up in difficulty AND rewards. Current system has partial scaling (easy/medium/hard based on `max_coin`). | Low (enhance existing) | `commissions.generate()`, `skill_tree.lua` query API | Enhance: factor in skill tree progress (more nodes = harder commissions = better rewards). Simple: count unlocked nodes, adjust difficulty thresholds. |
| Cross-mode commission types | "Merge 3 items in Arena" or "Complete 1 order" as commissions visible during Coin Sort. Creates deliberate pull to switch modes. | Medium | `arena.lua` hooks for `commissions.onArenaMerge()`, `commissions.onArenaOrder()`, new template types | Requires new commission types beyond the current forge/harvest. New templates: `arena_merge`, `arena_order`, `arena_generator`. Needs hooks in arena logic. |
| "Collect" button with celebration | Instead of auto-collecting on game over, show a tappable "Collect" button that triggers the reward popup (feature 4). Makes reward collection a deliberate dopamine moment. | Medium | Reward popup system (feature 4), commissions UI | Ties into the reward popup feature. Commission completion -> popup -> collect button -> animation -> resources added. |
| Commission notification badge on tab bar | When a commission completes while player is in Arena (e.g., from a fuel-earning merge that happened previously), show a badge on the CS tab. | Low | `tab_bar.lua` badge system (already exists for drops cross-mode rewards) | Tab bar already has badge infrastructure. Add commission completion badge count. Minimal new code. |
| Refresh-on-complete with cooldown | Completing all commissions immediately generates a new set (no waiting), but with a 2-hour cooldown before the NEXT set can refresh. Keeps engaged players busy without infinite farming. | Medium | Timer state in commission persistence | Balance consideration: too fast = resource inflation, too slow = feels punitive. Start with 4-8 hour cooldown, tune from playtesting. |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Real-time server clock dependence | Game is offline-first (Yandex web, no backend server). Using server time would require network calls that may fail. Clock manipulation is trivial but irrelevant for a single-player game. | Use elapsed play-time or `os.time()` for refresh timestamps. Accept that players can manipulate their system clock. |
| Commission expiry with penalty | "Complete in 4 hours or lose progress" creates anxiety, not fun. Punishing timers in a casual merge game drive churn. | Commissions refresh but never penalize. Incomplete commissions just get replaced when the refresh triggers. Lost progress is penalty enough. |
| More than 3 active commissions | Screen real estate is limited (1080x1920 virtual canvas with grid + buttons + tab bar already packed). More than 3 creates visual clutter and decision paralysis. | 2-3 active commissions max. Current 2 is fine. Could expand to 3 if adding one cross-mode commission. |
| Premium/paid commission refresh | No monetization beyond Yandex ads for v1.0. Paid commission refresh adds complexity for zero revenue. | All commissions are free. If monetization is needed later, add as a separate system. |
| Commission types requiring locked generators | "Tap Blender generator 3 times" when player has not unlocked Blending via skill tree. Creates impossible commissions. | Filter commission templates against `skill_tree.isGeneratorUnlocked()`. Same gating pattern `arena_orders.lua` already uses for order visibility. |

---

## 4. Reward Popups

The game currently has notification toasts in arena_screen (small sliding text near top of grid, `notifications` array with slide-in animation) and the fuel depletion overlay (full modal with dimmed background). But there are no celebration moments for big achievements: completing a commission, reaching a new merge level, opening a chest, completing an arena level. Merge games universally treat these as dopamine peaks -- the "Peggle moment."

### Table Stakes

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| Modal popup with dimmed background | Semi-transparent dark overlay + centered card. THE standard pattern for reward moments in every mobile game. | Low-Medium | New `popup.lua` module, screen draw pipeline | Follow the existing `drawFuelDepletionOverlay()` pattern in `arena_screen.lua` (dimmed bg, centered panel, buttons) but generalize into a reusable module. |
| Animated entrance (scale bounce or slide up) | Popup must animate in, not just appear. Elastic scale from 0 to 1 over ~0.3s is the merge genre standard. | Low | `easeOutElastic` already exists in `arena_screen.lua` line 100 | Extract the existing elastic easing function to a shared utility module. Reuse for all popup animations. |
| Reward item display (icon + count) | Show WHAT was earned: "+2 Bags", "+5 Stars", "Level 5 Reached". Icons + numbers. | Low | Resource colors from existing rendering, `resources.lua` data | Use colored rectangles or text-based representation consistent with existing immediate-mode UI. No new sprite assets needed. |
| Tap-to-dismiss or tap-to-collect | Player must be able to continue playing. Never trap them in a popup indefinitely. | Low | Input handling in popup module | Tap "Collect" or "Continue" button = dismiss. Merge games typically require deliberate tap (not tap-anywhere) for reward popups to force acknowledgment. |
| Queue system (one popup at a time) | Multiple rewards can trigger simultaneously (merge -> commission complete + new merge level). Must show sequentially, not stack. | Medium | `popup.lua` FIFO queue array | FIFO queue. Show first, on dismiss show next. Critical for preventing visual chaos. |
| Block game input while popup is visible | Tapping behind the popup must not trigger game actions (picking coins, tapping generators). | Low | Screen `mousepressed` intercept | If popup is visible, consume all mouse events except the popup's own buttons. Same pattern as fuel overlay already uses. |

### Differentiators

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| Particle burst behind popup | Confetti/stars exploding behind the reward card when it appears. The "Peggle Extreme Fever" moment. Makes rewards feel earned and exciting. | Medium | Effects system (feature 1), popup lifecycle hooks | Spawn celebration particles at popup center when it opens. Use existing particle pool with golden/reward colors. Requires effects system to be built first. |
| Reward fly-to animation on dismiss | After dismissing popup, reward icons fly from popup center to their respective resource counters (bags fly to bag count, stars fly to star display). Confirms where the reward went. | Medium | Layout positions of resource counters, tween system | Need screen-space positions of fuel bar, star counter, bag counter. Tween from popup center to target position over 0.5s. Standard in Merge Mansion. |
| Rarity-tiered popup styles | Three tiers: small toast for minor rewards (fuel surge, +1 bag), medium card for commissions, full celebration with particles for level-ups and first-time achievements. | Medium | Popup module with `tier` parameter ("small"/"medium"/"large") | CRITICAL for preventing "popup fatigue." If every tiny reward gets a full-screen celebration, players learn to ignore all popups. Tier the importance. |
| Sound effects synced to popup | A satisfying chime or fanfare synchronized with the popup entrance animation. Different sounds for different reward tiers. | Low | `sound.lua`, 2-3 new audio files | Small: soft ding. Medium: bright chime. Large: short fanfare. Keep audio files tiny for web load budget. |
| "Collect" button with visual feedback | Instead of auto-granting rewards, popup shows a glowing "Collect" button. Tap triggers a brief scale-down + reward icons animate. Adds agency to the reward moment. | Low-Medium | Reward application deferred until button tap, popup button state | Merge Mansion and top merge games use this pattern. The deliberate "Collect" tap feels more rewarding than auto-grant. One extra tap is acceptable for big moments. |

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Unskippable popup animations longer than 2 seconds | Player wants to get back to playing. Long forced celebrations cause frustration, especially after the 50th commission completion. | Keep entrance animation under 0.5s. Allow tap to dismiss at any point, even during entrance animation. |
| Popup for every single merge | Merges happen every few seconds in active play. A popup each time would make the game unplayable. | Use lightweight inline effects (particles, screen shake, number fly) for merges. Reserve popups ONLY for milestones: commission completions, arena level completions, first time reaching a new coin level. |
| Interstitial ad disguised as reward popup | "Watch ad for 2x reward" button on every reward popup. Aggressive monetization erodes trust. | Rewarded ads should be opt-in from a dedicated location (like the existing fuel overlay ad button in arena_screen), never injected into reward celebration popups. |
| Multiple simultaneous popups / stacking | Two popups overlapping is visual garbage and confusing. | Strict FIFO queue. One popup at a time. Next appears only after current is dismissed. |
| Popup blocking during active animations | If a popup appears mid-merge-animation or while coins are flying, it interrupts the flow and can cause state bugs. | Queue popups to appear only during IDLE animation state. Check `animation.getPickState() == "IDLE" and animation.getBgState() == "IDLE"` before showing next queued popup. |
| Auto-dismiss timer on important popups | Auto-dismissing a "Commission Complete!" popup after 3 seconds means the player might miss it entirely. | Auto-dismiss only for small toasts (fuel surge, minor drops). Medium and large popups require deliberate tap to dismiss. |

---

## Feature Dependencies

```
Effects System (1) -- FOUNDATION, build first
  |
  +--> Reward Popups (4) -- popups use particle bursts, fly-to animations
  |
  +--> Spotlight Tutorial (2) -- tutorial completion can trigger celebration effect
  |
  +--> Persistent Commissions (3) -- commission complete notification uses effects

Spotlight Tutorial (2) -- HIGH USER IMPACT, build second
  |
  +--> Uses LOVE2D 12.0 stencil API (setStencilMode / setStencilState)
  |
  +--> Depends on: animation states (must be able to check idle)
  |
  +--> Needs: progression.lua slot for CS tutorial state
  |
  +--> Independent of commissions and popups

Persistent Commissions (3) -- RETENTION, build third
  |
  +--> progression.lua -- needs new commissions_data slot
  |
  +--> Both screen modules -- needs compact UI on both CS and Arena
  |
  +--> Reward Popups (4) -- completion triggers popup (soft dependency, can notify without popup initially)

Reward Popups (4) -- POLISH, build last
  |
  +--> Effects System (1) -- celebration particles behind popup
  |
  +--> sound.lua -- reward sounds
  |
  +--> Enhances commissions and tutorials but not required for them to function
```

**Build order rationale:**
1. **Effects system first** because it is a dependency for popups AND fixes the web performance regression that blocks everything else. Cannot add more visual feedback without fixing the performance foundation.
2. **Spotlight tutorials second** because they are the highest-impact user-facing feature (CS has zero onboarding) and are independent of the other features.
3. **Persistent commissions third** because they need persistence plumbing in `progression.lua` and cross-screen UI, but can function with just inline notifications before popups exist.
4. **Reward popups last** because they depend on the effects system being done and enhance (but are not required for) commissions and tutorials.

---

## MVP Recommendation

### Must ship for v1.0:

1. **Effects system redesign** -- without this, adding any new visual feedback causes web lag. Foundation for everything else. Prioritize: tiered quality system (3 levels not 2), effect type registry, fix the web performance regression in particles.lua.

2. **Coin Sort spotlight tutorial** -- CS has NO onboarding. New players on Yandex Games land on CS first and have no guidance. This is the highest-impact user-facing feature for retention. Keep it to 5-8 steps: pick coins, place coins, merge, deal from bag.

3. **Persistent commissions with cross-mode visibility** -- persistence + visible from both modes. Refresh when all complete (with optional cooldown). This is the primary return-visit retention mechanism beyond the core loop.

4. **Reward popups for commissions and level-ups** -- at minimum, commission completion and arena level completion need celebration moments. Dimmed modal + reward display + tap to collect. Small toasts for minor drops.

### Defer to post-v1.0:

- **Cross-mode commission types** ("Merge 3 items in Arena") -- adds complexity to commission generation and requires new hooks in arena.lua. Standard same-mode commissions are sufficient for v1.0 launch.
- **Streak bonus for consecutive commission completions** -- retention optimization that requires data on actual player behavior to tune correctly.
- **Animated spotlight transitions between steps** -- smooth movement between spotlight positions is nice polish but hard-cut transitions are perfectly functional.
- **Reward fly-to animation** (icons flying from popup to resource counters) -- satisfying but not blocking. Auto-grant-on-collect with a particle burst is sufficient for v1.0.
- **Arena tutorial rebuild to spotlight-style** -- the existing 18-step tutorial works (despite bugs). Fix the step 8/9 bug, but a full spotlight rebuild can follow the CS tutorial pattern established in v1.0.

---

## Complexity Budget Summary

| Feature Area | Table Stakes Effort | Differentiator Effort | Total Estimate |
|--------------|--------------------|-----------------------|----------------|
| Effects System Redesign | HIGH (web perf fix, quality tiers) | MEDIUM (registry, canvas compositing, fly-to tweens) | **HIGH** |
| Spotlight Tutorial (CS + Arena) | MEDIUM (stencil rendering, input blocking, state machine) | LOW-MEDIUM (animated transitions, hand pointer, shapes) | **MEDIUM** |
| Persistent Commissions | MEDIUM (save/load plumbing, timer, dual-screen UI) | LOW-MEDIUM (cross-mode types, badges, collect interaction) | **MEDIUM** |
| Reward Popups | LOW-MEDIUM (modal, queue, entrance animation) | MEDIUM (particle bursts, fly-to, tiered styles, sounds) | **MEDIUM** |

**Total milestone complexity: HIGH** -- the effects system redesign is the riskiest piece due to web/WASM performance constraints and the fact that it touches the rendering pipeline used by every screen. The other three features are standard game UI work with well-understood patterns and clear reference implementations in the existing codebase (fuel overlay for popups, drops.lua for persistence, arena tutorial for state machines).

---

## Sources

- [Game Design UX Best Practices -- GameDev.net](https://gamedev.net/tutorials/game-design/ux-for-games/game-design-user-experience-best-practices-ultimate-guide-r5204/)
- [Juicy UI: Why the Smallest Interactions Make the Biggest Difference -- Medium](https://medium.com/@mezoistvan/juicy-ui-why-the-smallest-interactions-make-the-biggest-difference-5cb5a5ffc752)
- [Juice -- Brad Woods Design Garden](https://garden.bradwoods.io/notes/design/juice)
- [3 Game Juice Techniques from Slime Road -- Game Developer](https://www.gamedeveloper.com/design/3-game-juice-techniques-from-slime-road)
- [Popup UI Best Practices 2025 -- Eleken](https://www.eleken.co/blog-posts/popup-ui)
- [Modal UX Design 2026 -- Userpilot](https://userpilot.com/blog/modal-ux-design/)
- [Progression Systems in Mobile Games -- Udonis](https://www.blog.udonis.co/mobile-marketing/mobile-games/progression-systems)
- [Daily Rewards, Streaks, and Battle Passes -- DesignTheGame](https://www.designthegame.com/learning/tutorial/daily-rewards-streaks-battle-passes-player-retention)
- [Feature Spotlight: Progression in Daily Rewards -- GameRefinery](https://www.gamerefinery.com/feature-spotlight-progression-daily-rewards/)
- [How to Create Seamless UI/UX in Mobile Games -- AppSamurai](https://appsamurai.com/blog/how-to-create-a-seamless-ui-ux-in-mobile-games/)
- [LOVE2D stencil API wiki](https://love2d.org/wiki/love.graphics.stencil)
- [LOVE2D 12.0 changelog](https://love2d.org/wiki/12.0)
- [LOVE2D Particles Optimization -- forum](https://love2d.org/forums/viewtopic.php?t=81808)
- [Understanding Merge2 Mobile Games -- PlayableMaker](https://playablemaker.com/understanding-merge2-mobile-games-a-comprehensive-guide/)
- [Merge Dragons Critical Play -- Medium](https://mattkber.medium.com/merge-dragons-a-critical-play-cb0add46f176)
- [Yandex Games Requirements](https://yandex.com/dev/games/doc/en/concepts/requirements)
- [10 Guidelines for Overlays/Modals -- UXfortheMasses](https://www.uxforthemasses.com/overlays/)
- [Optimizing Unity UI for Mobile -- PlayMobile](https://playmobile.online/optimizing-unity-ui-for-mobile-games-with-low-end-devices/) (principles transfer to LOVE2D)
- [WebAssembly 2025 Opportunities and Risks -- aklic.com](https://aklic.com/web-assembly-2025-opportunities-risks-game-changing/)

---

*Feature landscape: 2026-04-05*
