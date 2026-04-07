-- effects.lua
-- Screen-level visual effects: fly-to-bar icons, overlay flash, celebration burst
-- Pre-allocated pools for zero GC pressure during gameplay

local layout = require("layout")
local mobile = require("mobile")

local effects = {}

-- Shared easing functions (centralized for reuse across effect types)

local function easeOutCubic(t)
    return 1 - (1 - t) * (1 - t) * (1 - t)
end

local function easeOutElastic(t)
    if t == 0 or t == 1 then return t end
    return math.pow(2, -10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi / 3)) + 1
end

local function easeInQuad(t)
    return t * t
end

-- Tier-aware budgets for effect scaling
local TIER_BUDGETS = {
    HIGH = { burst_count = 20, fly_icon_duration = 0.6 },
    MED  = { burst_count = 12, fly_icon_duration = 0.5 },
    LOW  = { burst_count = 6,  fly_icon_duration = 0.4 },
}

-- Active tier budgets (set during init)
local tier_budgets = nil

--------------------------------------------------------------------------------
-- Resource bar target system (for fly-to-bar -- targets set by screen modules)
--------------------------------------------------------------------------------

local resource_targets = {
    fuel = {x = 0, y = 0},
    star = {x = 0, y = 0},
}

function effects.setResourceBarTargets(fuel_x, fuel_y, star_x, star_y)
    resource_targets.fuel.x = fuel_x
    resource_targets.fuel.y = fuel_y
    resource_targets.star.x = star_x
    resource_targets.star.y = star_y
end

function effects.getResourceTarget(icon_type)
    return resource_targets[icon_type]
end

-- Convenience: spawn fly icon toward stored resource target
function effects.spawnResourceFly(from_x, from_y, icon_type)
    local target = resource_targets[icon_type]
    if target and (target.x ~= 0 or target.y ~= 0) then
        effects.spawnFlyToBar(from_x, from_y, target.x, target.y, icon_type)
    end
end

--------------------------------------------------------------------------------
-- Fly-to-bar icon pool (D-05: resource gain fly-to-bar)
--------------------------------------------------------------------------------

local MAX_FLY_ICONS = 15

-- Pre-allocated pool with free-stack
local fly_pool = {}
local fly_active = {}       -- fly_active[1..fly_active_count] = pool indices
local fly_active_count = 0
local fly_free_stack = {}
local fly_free_count = 0

-- Icon color lookup
local ICON_COLORS = {
    fuel = {r = 1, g = 0.75, b = 0.15},
    star = {r = 0.95, g = 0.85, b = 0.25},
}

-- Icon radius lookup
local ICON_RADII = {
    fuel = 14,
    star = 12,
}

function effects.spawnFlyToBar(from_x, from_y, target_x, target_y, icon_type)
    if fly_free_count <= 0 then return end

    local idx = fly_free_stack[fly_free_count]
    fly_free_count = fly_free_count - 1

    local icon = fly_pool[idx]
    icon.x = from_x
    icon.y = from_y
    icon.start_x = from_x
    icon.start_y = from_y
    icon.target_x = target_x
    icon.target_y = target_y
    icon.time = 0
    icon.duration = tier_budgets.fly_icon_duration
    icon.icon_type = icon_type
    icon.active = true

    local c = ICON_COLORS[icon_type] or ICON_COLORS.fuel
    icon.r = c.r
    icon.g = c.g
    icon.b = c.b

    fly_active_count = fly_active_count + 1
    fly_active[fly_active_count] = idx
end

function effects.updateFlyIcons(dt)
    local i = 1
    while i <= fly_active_count do
        local idx = fly_active[i]
        local icon = fly_pool[idx]

        icon.time = icon.time + dt
        local t = math.min(icon.time / icon.duration, 1)
        local eased = easeOutCubic(t)

        -- Lerp position with arc (sin curve for height)
        icon.x = icon.start_x + (icon.target_x - icon.start_x) * eased
        icon.y = icon.start_y + (icon.target_y - icon.start_y) * eased
                 - math.sin(math.pi * t) * 80

        if t >= 1 then
            -- Release back to free stack
            icon.active = false
            fly_free_count = fly_free_count + 1
            fly_free_stack[fly_free_count] = idx

            -- Swap-remove from active list
            if i < fly_active_count then
                fly_active[i] = fly_active[fly_active_count]
            end
            fly_active_count = fly_active_count - 1
        else
            i = i + 1
        end
    end
end

function effects.drawFlyIcons()
    if fly_active_count == 0 then return end

    for i = 1, fly_active_count do
        local icon = fly_pool[fly_active[i]]
        local t = math.min(icon.time / icon.duration, 1)

        -- Alpha fades to 0.5 at end
        local alpha = 1 - t * 0.5

        local radius = ICON_RADII[icon.icon_type] or 12

        -- Draw filled circle
        love.graphics.setColor(icon.r, icon.g, icon.b, alpha)
        love.graphics.circle("fill", icon.x, icon.y, radius)

        -- Draw "+1" text centered above
        love.graphics.setColor(1, 1, 1, alpha)
        local text = "+1"
        local tw = love.graphics.getFont():getWidth(text)
        local th = love.graphics.getFont():getHeight()
        love.graphics.print(text, icon.x - tw / 2, icon.y - radius - th)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

--------------------------------------------------------------------------------
-- Overlay flash (D-06: big reward flash)
--------------------------------------------------------------------------------

local flash_alpha = 0
local flash_duration = 0
local flash_time = 0
local flash_r = 1
local flash_g = 1
local flash_b = 1

function effects.spawnFlash(duration, r, g, b)
    flash_duration = duration or 0.3
    flash_time = flash_duration
    flash_r = r or 1
    flash_g = g or 1
    flash_b = b or 1
    flash_alpha = 0.3
end

function effects.updateFlash(dt)
    if flash_time <= 0 then
        flash_alpha = 0
        return
    end
    flash_time = flash_time - dt
    if flash_time <= 0 then
        flash_alpha = 0
    else
        flash_alpha = 0.3 * (flash_time / flash_duration)
    end
end

function effects.drawFlash()
    if flash_alpha <= 0 then return end
    love.graphics.setColor(flash_r, flash_g, flash_b, flash_alpha)
    love.graphics.rectangle("fill", 0, 0, layout.VW, layout.VH)
    love.graphics.setColor(1, 1, 1, 1)
end

--------------------------------------------------------------------------------
-- Celebration burst (D-06: radial star burst for big moments)
--------------------------------------------------------------------------------

local MAX_BURST_PARTICLES = 20

-- Pre-allocated pool with free-stack
local burst_pool = {}
local burst_active = {}
local burst_active_count = 0
local burst_free_stack = {}
local burst_free_count = 0

function effects.spawnBurst(cx, cy, count, color)
    count = count or 12
    -- Cap by tier budget
    local max_count = tier_budgets.burst_count
    if count > max_count then count = max_count end
    -- Cap by pool size
    if count > burst_free_count then count = burst_free_count end

    local r = color and color[1] or 1
    local g = color and color[2] or 0.9
    local b = color and color[3] or 0.3

    for i = 1, count do
        if burst_free_count <= 0 then return end

        local idx = burst_free_stack[burst_free_count]
        burst_free_count = burst_free_count - 1

        local p = burst_pool[idx]
        p.x = cx
        p.y = cy

        -- Random angle, radial outward
        local angle = math.random() * math.pi * 2
        local speed = 300 + math.random() * 300
        p.vx = math.cos(angle) * speed
        p.vy = math.sin(angle) * speed

        p.time = 0
        p.duration = 0.5 + math.random() * 0.3
        p.size = 8 + math.random() * 8
        p.r = r
        p.g = g
        p.b = b
        p.active = true

        burst_active_count = burst_active_count + 1
        burst_active[burst_active_count] = idx
    end
end

function effects.updateBurst(dt)
    local i = 1
    while i <= burst_active_count do
        local idx = burst_active[i]
        local p = burst_pool[idx]

        p.time = p.time + dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt

        -- Slow down over time
        p.vx = p.vx * (1 - 2 * dt)
        p.vy = p.vy * (1 - 2 * dt)

        if p.time >= p.duration then
            -- Release back to free stack
            p.active = false
            burst_free_count = burst_free_count + 1
            burst_free_stack[burst_free_count] = idx

            -- Swap-remove from active list
            if i < burst_active_count then
                burst_active[i] = burst_active[burst_active_count]
            end
            burst_active_count = burst_active_count - 1
        else
            i = i + 1
        end
    end
end

function effects.drawBurst()
    if burst_active_count == 0 then return end

    for i = 1, burst_active_count do
        local p = burst_pool[burst_active[i]]
        local t = p.time / p.duration
        local alpha = 1 - easeInQuad(t)
        local size = p.size * (1 - t * 0.5)

        love.graphics.setColor(p.r, p.g, p.b, alpha)
        love.graphics.circle("fill", p.x, p.y, size)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

--------------------------------------------------------------------------------
-- Master init, update, draw
--------------------------------------------------------------------------------

function effects.init()
    -- Set tier budgets
    local tier = mobile.getPerformanceTier()
    tier_budgets = TIER_BUDGETS[tier]

    -- Pre-allocate fly-to-bar icon pool
    fly_pool = {}
    fly_active = {}
    fly_active_count = 0
    fly_free_stack = {}
    fly_free_count = MAX_FLY_ICONS

    for i = 1, MAX_FLY_ICONS do
        fly_pool[i] = {
            x = 0, y = 0,
            start_x = 0, start_y = 0,
            target_x = 0, target_y = 0,
            time = 0, duration = 0.5,
            icon_type = "fuel",
            active = false,
            r = 1, g = 1, b = 1,
        }
        fly_free_stack[i] = i
    end

    -- Pre-allocate burst particle pool
    burst_pool = {}
    burst_active = {}
    burst_active_count = 0
    burst_free_stack = {}
    burst_free_count = MAX_BURST_PARTICLES

    for i = 1, MAX_BURST_PARTICLES do
        burst_pool[i] = {
            x = 0, y = 0,
            vx = 0, vy = 0,
            time = 0, duration = 0.5,
            size = 10,
            r = 1, g = 1, b = 1,
            active = false,
        }
        burst_free_stack[i] = i
    end

    -- Reset flash state
    flash_alpha = 0
    flash_time = 0
    flash_duration = 0
end

-- Master update: call from screen update(dt)
function effects.update(dt)
    effects.updateFlyIcons(dt)
    effects.updateFlash(dt)
    effects.updateBurst(dt)
end

-- Master draw: call from screen draw() (excludes flash for layering control)
function effects.draw()
    effects.drawFlyIcons()
    effects.drawBurst()
end

return effects
