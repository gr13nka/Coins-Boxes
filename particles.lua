-- particles.lua
-- Chunky bouncy coin fragment particles (pixel art style)

local layout = require("layout")
local mobile = require("mobile")

local particles = {}

-- Mobile-aware configuration (fewer particles on mobile for performance)
local IS_MOBILE = mobile.isMobile()
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

-- Particle pool
local pool = {}
local activeCount = 0

-- Initialize empty pool
function particles.init()
    pool = {}
    activeCount = 0
    for i = 1, MAX_PARTICLES do
        pool[i] = {
            active = false,
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
    end
end

-- Get an inactive particle from pool
local function getParticle()
    for i = 1, MAX_PARTICLES do
        if not pool[i].active then
            return pool[i]
        end
    end
    -- Pool exhausted, reuse oldest (first active)
    for i = 1, MAX_PARTICLES do
        if pool[i].active then
            return pool[i]
        end
    end
    return pool[1]
end

-- Spawn a single fragment
local function spawnFragment(x, y, color, speed_min, speed_max, lifetime)
    local p = getParticle()

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
    p.active = true

    -- Chunky rotation
    p.rotation = math.random() * math.pi * 2
    p.rotationSpeed = (math.random() - 0.5) * 12

    activeCount = activeCount + 1
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

-- Update all particles with bouncy physics
function particles.update(dt)
    activeCount = 0

    for i = 1, MAX_PARTICLES do
        local p = pool[i]
        if p.active then
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

            -- Bounce off sides (optional, keeps fragments on screen)
            if p.x < 50 then
                p.x = 50
                p.vx = -p.vx * 0.5
            elseif p.x > layout.VW - 50 then
                p.x = layout.VW - 50
                p.vx = -p.vx * 0.5
            end

            -- Decrease lifetime
            p.lifetime = p.lifetime - dt

            -- Deactivate when expired
            if p.lifetime <= 0 then
                p.active = false
            else
                activeCount = activeCount + 1
            end
        end
    end
end

-- Draw all active particles
function particles.draw()
    for i = 1, MAX_PARTICLES do
        local p = pool[i]
        if p.active then
            -- Calculate alpha based on lifetime (fade out in last 30%)
            local lifeRatio = p.lifetime / p.maxLifetime
            local alpha = 1
            if lifeRatio < 0.3 then
                alpha = lifeRatio / 0.3
            end

            -- Scale down slightly as lifetime decreases
            local scale = 0.7 + lifeRatio * 0.3
            local size = p.size * scale

            -- Draw chunky square with rotation
            love.graphics.push()
            love.graphics.translate(p.x, p.y)
            love.graphics.rotate(p.rotation)

            love.graphics.setColor(p.r, p.g, p.b, alpha)
            love.graphics.rectangle("fill", -size/2, -size/2, size, size)

            -- Subtle highlight on top-left for depth (skip on mobile for performance)
            if not IS_MOBILE and size > 8 then
                love.graphics.setColor(1, 1, 1, alpha * 0.3)
                love.graphics.rectangle("fill", -size/2, -size/2, size * 0.4, size * 0.4)
            end

            love.graphics.pop()
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Get active particle count (for debugging)
function particles.getActiveCount()
    return activeCount
end

return particles
