-- particles.lua
-- Chunky bouncy coin fragment particles (pixel art style)
-- Uses active-list pool + SpriteBatch for minimal draw calls

local layout = require("layout")
local mobile = require("mobile")

local particles = {}

-- Mobile-aware configuration (fewer particles on mobile for performance)
local IS_MOBILE = mobile.isLowPerformance()
local MAX_PARTICLES = IS_MOBILE and 150 or 300
local GRAVITY = 1800
local BOUNCE_DAMPING = 0.6      -- Velocity retained after bounce
local GROUND_Y = layout.VH - 100 -- Where particles bounce

-- Fragment sizes (chunky pixel look)
local SIZES = {6, 10, 14, 18}   -- Varied chunk sizes

-- Spawn settings
local SPAWN_COUNT = IS_MOBILE and 10 or 20
local SPAWN_SPEED_MIN = 400
local SPAWN_SPEED_MAX = 900
local SPAWN_ANGLE_SPREAD = 2.2  -- ~126 degrees upward
local LIFETIME = IS_MOBILE and 0.8 or 1.2
local MAX_BOUNCES = IS_MOBILE and 2 or 3

-- Merge explosion settings
local MERGE_SPAWN_COUNT = IS_MOBILE and 18 or 35
local MERGE_SPEED_MIN = 500
local MERGE_SPEED_MAX = 1100
local MERGE_LIFETIME = IS_MOBILE and 1.0 or 1.5

-- Particle pool (flat array, indexed by active list)
local pool = {}
local activeCount = 0

-- Active-list pool: compact array of active pool indices + free stack
local active = {}       -- active[1..activeCount] = pool indices
local freeStack = {}    -- stack of free pool indices
local freeCount = 0
local poolToActive = {} -- pool index -> position in active[] (for swap-remove)

-- SpriteBatch for single draw call
local pixelImage  -- 1x1 white pixel image
local batch       -- SpriteBatch

-- Initialize empty pool + SpriteBatch
function particles.init()
    -- Create 1x1 white pixel image procedurally
    local imgData = love.image.newImageData(1, 1)
    imgData:setPixel(0, 0, 1, 1, 1, 1)
    pixelImage = love.graphics.newImage(imgData)

    -- Create sprite batch (main quad + optional highlight per particle)
    batch = love.graphics.newSpriteBatch(pixelImage, MAX_PARTICLES * 2, "stream")

    pool = {}
    active = {}
    activeCount = 0
    freeStack = {}
    freeCount = MAX_PARTICLES
    poolToActive = {}

    for i = 1, MAX_PARTICLES do
        pool[i] = {
            x = 0, y = 0,
            vx = 0, vy = 0,
            size = 10,
            r = 1, g = 1, b = 1,
            lifetime = 0,
            maxLifetime = 1,
            bounces = 0,
            rotation = 0,
            rotationSpeed = 0
        }
        freeStack[i] = i  -- all slots start free
    end
end

-- Get a free pool index (O(1) pop from free stack, or steal first active)
local function getPoolIndex()
    if freeCount > 0 then
        local idx = freeStack[freeCount]
        freeCount = freeCount - 1
        return idx
    end
    -- Pool exhausted, steal first active particle
    if activeCount > 0 then
        local idx = active[1]
        -- Swap-remove from active list
        poolToActive[idx] = nil
        if activeCount > 1 then
            active[1] = active[activeCount]
            poolToActive[active[1]] = 1
        end
        activeCount = activeCount - 1
        return idx
    end
    return 1  -- fallback
end

-- Spawn a single fragment
local function spawnFragment(x, y, color, speed_min, speed_max, lifetime)
    local idx = getPoolIndex()
    local p = pool[idx]

    -- Position
    p.x = x + math.random(-10, 10)
    p.y = y + math.random(-10, 10)

    -- Velocity (upward burst with spread)
    local angle = -math.pi/2 + (math.random() - 0.5) * SPAWN_ANGLE_SPREAD
    local speed = speed_min + math.random() * (speed_max - speed_min)
    p.vx = math.cos(angle) * speed
    p.vy = math.sin(angle) * speed

    -- Random chunk size
    p.size = SIZES[math.random(#SIZES)]

    -- Color (brightened)
    p.r = math.min(1, color[1] * 1.2 + 0.1)
    p.g = math.min(1, color[2] * 1.2 + 0.1)
    p.b = math.min(1, color[3] * 1.2 + 0.1)

    -- Lifetime and state
    p.lifetime = lifetime
    p.maxLifetime = lifetime
    p.bounces = 0

    -- Chunky rotation
    p.rotation = math.random() * math.pi * 2
    p.rotationSpeed = (math.random() - 0.5) * 12

    -- Add to active list
    activeCount = activeCount + 1
    active[activeCount] = idx
    poolToActive[idx] = activeCount
end

-- Spawn burst of coin fragments
function particles.spawn(x, y, color)
    for i = 1, SPAWN_COUNT do
        spawnFragment(x, y, color, SPAWN_SPEED_MIN, SPAWN_SPEED_MAX, LIFETIME)
    end
end

-- Spawn merge explosion (more fragments, faster)
function particles.spawnMergeExplosion(x, y, color)
    for i = 1, MERGE_SPAWN_COUNT do
        spawnFragment(x, y, color, MERGE_SPEED_MIN, MERGE_SPEED_MAX, MERGE_LIFETIME)
    end
end

-- Smaller squeeze particles
function particles.spawnSqueezeParticles(x, y, color, count)
    count = count or 8
    for i = 1, count do
        spawnFragment(x, y, color, SPAWN_SPEED_MIN * 0.6, SPAWN_SPEED_MAX * 0.6, LIFETIME * 0.7)
    end
end

-- Update active particles only (swap-remove dead ones)
function particles.update(dt)
    local VW = layout.VW
    local i = 1
    while i <= activeCount do
        local idx = active[i]
        local p = pool[idx]

        -- Apply gravity
        p.vy = p.vy + GRAVITY * dt

        -- Move
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt

        -- Rotate (chunky spin)
        p.rotation = p.rotation + p.rotationSpeed * dt

        -- Bounce off ground
        if p.y > GROUND_Y and p.vy > 0 then
            p.y = GROUND_Y
            p.vy = -p.vy * BOUNCE_DAMPING
            p.vx = p.vx * 0.8  -- Friction
            p.bounces = p.bounces + 1
            p.rotationSpeed = p.rotationSpeed * 0.5

            -- Stop bouncing after max bounces
            if p.bounces >= MAX_BOUNCES then
                p.vy = 0
                p.vx = p.vx * 0.3
            end
        end

        -- Bounce off sides
        if p.x < 50 then
            p.x = 50
            p.vx = -p.vx * 0.5
        elseif p.x > VW - 50 then
            p.x = VW - 50
            p.vx = -p.vx * 0.5
        end

        -- Decrease lifetime
        p.lifetime = p.lifetime - dt

        -- Deactivate when expired
        if p.lifetime <= 0 then
            -- Return to free stack
            freeCount = freeCount + 1
            freeStack[freeCount] = idx
            poolToActive[idx] = nil

            -- Swap-remove: move last active into this slot
            if i < activeCount then
                active[i] = active[activeCount]
                poolToActive[active[i]] = i
            end
            activeCount = activeCount - 1
            -- Don't increment i; process the swapped element next
        else
            i = i + 1
        end
    end
end

-- Draw all active particles via SpriteBatch (single draw call)
function particles.draw()
    if activeCount == 0 then return end

    batch:clear()

    for i = 1, activeCount do
        local p = pool[active[i]]

        -- Alpha fade out in last 30% of lifetime
        local lifeRatio = p.lifetime / p.maxLifetime
        local alpha = lifeRatio < 0.3 and (lifeRatio / 0.3) or 1

        -- Scale down slightly as lifetime decreases
        local size = p.size * (0.7 + lifeRatio * 0.3)

        -- Main colored square
        batch:setColor(p.r, p.g, p.b, alpha)
        batch:add(p.x, p.y, p.rotation, size, size, 0.5, 0.5)

        -- Highlight on top-left for depth (desktop only, large fragments)
        if not IS_MOBILE and size > 8 then
            local hs = size * 0.4
            batch:setColor(1, 1, 1, alpha * 0.3)
            -- Approximate top-left offset (skip trig, imperceptible on moving fragments)
            batch:add(p.x - size * 0.2, p.y - size * 0.2, p.rotation, hs, hs, 0.5, 0.5)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(batch)
end

-- Get active particle count (for debugging)
function particles.getActiveCount()
    return activeCount
end

return particles
