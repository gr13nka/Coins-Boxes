-- tutorial.lua -- Spotlight tutorial system: step state, animations, localization, input blocking (data/logic only, no drawing)

local layout = require("layout")

local M = {}

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local SLIDE_DURATION    = 0.3   -- seconds for spotlight to slide between targets (D-04)
local OVERLAY_OPACITY   = 0.6   -- dark overlay alpha (D-02)
local PULSE_SPEED       = 1.5   -- pulse cycles per second (D-03)
local HAND_TAP_PERIOD   = 1.5   -- seconds per tap animation cycle (D-14)
local HAND_DRAG_PERIOD  = 2.0   -- seconds per drag animation cycle (D-14)
local CUTOUT_PADDING    = 12    -- pixels of padding around target element
local CUTOUT_RADIUS     = 12    -- corner radius for rounded rect cutout
local TEXT_MARGIN       = 20    -- margin from spotlight edge for text positioning

--------------------------------------------------------------------------------
-- Step registry (populated by Plan 02 / Plan 03 via registerSteps)
--------------------------------------------------------------------------------

-- Each entry in a steps table is:
-- {
--   text       = { en = "...", ru = "..." },
--   getRect    = function() -> {x, y, w, h} or nil  (virtual canvas coords)
--   hand       = "tap" | "drag" | "none"
--   drag_target = function() -> {x, y}  (only when hand == "drag")
--   check      = function() -> bool      (precondition gate, D-17 / TUT-04)
--   on_enter   = function() or nil       (setup action when step activates)
-- }

local STEPS = {
    coin_sort    = {},  -- populated by M.registerSteps("coin_sort", steps_table)
    arena        = {},  -- populated by M.registerSteps("arena",     steps_table)
    fuel_bridge  = {},  -- populated by M.registerSteps("fuel_bridge", steps_table)
}

--------------------------------------------------------------------------------
-- Module state
--------------------------------------------------------------------------------

local active_tutorial  = nil   -- nil | "coin_sort" | "arena"
local current_step     = 0
local prev_rect        = nil   -- {x, y, w, h}
local next_rect        = nil   -- {x, y, w, h}
local slide_timer      = 0
local pulse_timer      = 0
local hand_timer       = 0
local lang             = "en"  -- default English (font lacks Cyrillic; switch via setLang)
local queued_advance   = false -- gated advance waiting for animation idle

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function easeOutCubic(t)
    return 1 - (1 - t) * (1 - t) * (1 - t)
end

-- Lazy accessor to avoid circular deps
local function getProgression()
    return require("progression")
end

-- Lazy accessor to avoid circular deps (also prevents top-level require problems)
local function getAnimation()
    return require("animation")
end

-- Internal: advance to next step (no idle check — caller ensures preconditions).
local function doAdvance()
    queued_advance = false

    if not active_tutorial then return end

    local steps = STEPS[active_tutorial]
    local new_step = current_step + 1

    if new_step > #steps then
        M.markDone()
        return
    end

    -- Validate check() precondition; skip up to 3 broken steps gracefully (D-17).
    local attempts = 0
    while new_step <= #steps and attempts < 4 do
        local step = steps[new_step]
        if not step.check or step.check() then
            break
        end
        new_step = new_step + 1
        attempts = attempts + 1
    end

    if new_step > #steps then
        M.markDone()
        return
    end

    -- Record current interpolated rect as start of the slide.
    prev_rect = M.getSpotlight()
    current_step = new_step

    local step = steps[current_step]
    next_rect = step.getRect and step.getRect() or nil
    slide_timer  = 0
    hand_timer   = 0

    if step.on_enter then
        step.on_enter()
    end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Register step definitions for a tutorial.
-- Called by coin_sort_screen / arena_screen before starting the tutorial.
-- @param tutorial_id  "coin_sort" | "arena"
-- @param steps_table  Array of step definition tables.
function M.registerSteps(tutorial_id, steps_table)
    STEPS[tutorial_id] = steps_table
end

--- Start a tutorial from step 1.
-- @param tutorial_id  "coin_sort" | "arena"
function M.start(tutorial_id)
    active_tutorial = tutorial_id
    current_step    = 0
    prev_rect       = nil
    next_rect       = nil
    slide_timer     = 0
    pulse_timer     = 0
    hand_timer      = 0
    queued_advance  = false

    -- doAdvance() from step 0 → step 1
    doAdvance()
end

--- Update timers.  Call from screen.update(dt).
-- @param dt  Delta time in seconds.
function M.update(dt)
    if not active_tutorial then return end

    -- Slide transition
    if slide_timer < SLIDE_DURATION then
        slide_timer = slide_timer + dt
        if slide_timer > SLIDE_DURATION then
            slide_timer = SLIDE_DURATION
        end
    end

    -- Pulse / hand timers (continuous)
    pulse_timer = pulse_timer + dt
    hand_timer  = hand_timer  + dt

    -- Wrap hand timer at its period
    local step = STEPS[active_tutorial] and STEPS[active_tutorial][current_step]
    if step then
        local period = (step.hand == "drag") and HAND_DRAG_PERIOD or HAND_TAP_PERIOD
        hand_timer = hand_timer % period
    end

    -- Process queued advance once animation track goes idle.
    if queued_advance then
        if getAnimation().isIdle() then
            doAdvance()
        end
    end
end

--- Signal that the required action for the current step has been completed.
-- Defers if an animation is still running, unless force is true.
-- @param force  If true, advance immediately regardless of animation state.
--               Use for interactive states like coin hover where the player
--               needs to see the next spotlight while still holding coins.
function M.advance(force)
    if not active_tutorial then return end

    if not force and not getAnimation().isIdle() then
        queued_advance = true
        return
    end
    doAdvance()
end

--- Returns true when any tutorial is active.
function M.isActive()
    return active_tutorial ~= nil
end

--- Returns the active tutorial id string, or nil.
function M.getActiveTutorial()
    return active_tutorial
end

--- Returns the padded, eased spotlight rect for the current frame.
-- Returns nil when no tutorial is active or no target defined.
-- The rect already includes CUTOUT_PADDING expansion on all sides.
function M.getSpotlight()
    if not active_tutorial or not next_rect then return nil end

    local nr = next_rect

    local function padded(r)
        return {
            x = r.x - CUTOUT_PADDING,
            y = r.y - CUTOUT_PADDING,
            w = r.w + CUTOUT_PADDING * 2,
            h = r.h + CUTOUT_PADDING * 2,
        }
    end

    if not prev_rect then
        return padded(nr)
    end

    local pr = prev_rect
    local t  = math.min(slide_timer / SLIDE_DURATION, 1)
    local e  = easeOutCubic(t)

    -- Lerp between prev and next, then pad
    local interp = {
        x = pr.x + (nr.x - pr.x) * e,
        y = pr.y + (nr.y - pr.y) * e,
        w = pr.w + (nr.w - pr.w) * e,
        h = pr.h + (nr.h - pr.h) * e,
    }
    return padded(interp)
end

--- Returns the overlay opacity constant.
function M.getOverlayOpacity()
    return OVERLAY_OPACITY
end

--- Returns a 0..1 alpha value for the pulsing border (D-03).
function M.getPulseAlpha()
    return 0.4 + 0.4 * math.sin(pulse_timer * math.pi * 2 * PULSE_SPEED)
end

--- Returns the cutout corner radius constant.
function M.getCutoutRadius()
    return CUTOUT_RADIUS
end

--- Returns the localized text for the current step, or "".
function M.getText()
    if not active_tutorial then return "" end
    local step = STEPS[active_tutorial] and STEPS[active_tutorial][current_step]
    if not step or not step.text then return "" end
    return step.text[lang] or step.text["en"] or ""
end

--- Returns "above" or "below" for instruction text placement (D-15).
-- @param spotlight_rect  The rect returned by getSpotlight().
function M.getTextPosition(spotlight_rect)
    if not spotlight_rect then return "below" end
    local center_y = spotlight_rect.y + spotlight_rect.h * 0.5
    if center_y < layout.VH * 0.5 then
        return "below"
    else
        return "above"
    end
end

--- Returns hand animation data for the current step.
-- @return table {type="tap"|"drag"|"none", progress=0..1, drag_target={x,y}|nil}
function M.getHandAnim()
    if not active_tutorial then
        return { type = "none", progress = 0, drag_target = nil }
    end

    local step = STEPS[active_tutorial] and STEPS[active_tutorial][current_step]
    if not step then
        return { type = "none", progress = 0, drag_target = nil }
    end

    local hand_type = step.hand or "none"
    local period    = (hand_type == "drag") and HAND_DRAG_PERIOD or HAND_TAP_PERIOD
    local progress  = (period > 0) and (hand_timer / period) or 0

    local drag_target = nil
    if hand_type == "drag" and step.drag_target then
        drag_target = step.drag_target()
    end

    return {
        type        = hand_type,
        progress    = progress,
        drag_target = drag_target,
    }
end

--- Returns true if the given virtual-canvas point is within the spotlight zone.
-- Returns true (pass-through) when no tutorial is active.
-- @param gx  X in virtual canvas coordinates.
-- @param gy  Y in virtual canvas coordinates.
function M.isInputAllowed(gx, gy)
    if not active_tutorial then return true end

    local rect = M.getSpotlight()
    if not rect then return true end

    return gx >= rect.x and gx <= rect.x + rect.w
       and gy >= rect.y and gy <= rect.y + rect.h
end

--- Returns true when the specified tutorial has been marked completed.
-- @param tutorial_id  "coin_sort" | "arena"
function M.isDone(tutorial_id)
    local td = getProgression().getTutorialData()
    return td[tutorial_id .. "_done"] == true
end

--- Mark the active tutorial as done, persist, and reset state.
function M.markDone()
    if not active_tutorial then return end

    local prog = getProgression()
    local td   = prog.getTutorialData()
    td[active_tutorial .. "_done"] = true
    prog.setTutorialData(td)
    prog.save()

    active_tutorial = nil
    current_step    = 0
    prev_rect       = nil
    next_rect       = nil
    queued_advance  = false
end

--- Returns the current step index (0 when inactive).
function M.getCurrentStep()
    return current_step
end

--- Returns the total step count for the active tutorial (0 when inactive).
function M.getStepCount()
    if not active_tutorial then return 0 end
    return #(STEPS[active_tutorial] or {})
end

--- Convenience accessor: returns tutorial_data from progression.
function M.getTutorialData()
    return getProgression().getTutorialData()
end

--- Set the display language.
-- @param language  "en" | "ru"
function M.setLang(language)
    lang = language
end

--- Legacy load stub (called by main.lua; no-op, module initialises at require time).
function M.load()
    -- no-op: all state is initialised at module load above
end

return M
