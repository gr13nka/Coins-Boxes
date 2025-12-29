-- particles.lua
-- Juicy coin landing particle effects

local layout = require("layout")

local particles = {}

-- Configuration (over-the-top and FAST!)
local PARTICLE_COUNT = 45       -- Particles per burst
local LIFETIME_MIN = 0.25       -- Minimum particle lifetime
local LIFETIME_MAX = 0.5        -- Maximum particle lifetime
local SPEED_MIN = 500           -- Minimum initial speed
local SPEED_MAX = 900           -- Maximum initial speed
local GRAVITY = 1200            -- Downward acceleration
local SIZE_START = 0.8          -- Starting size multiplier
local SIZE_END = 0.15           -- Ending size multiplier
local SPREAD_ANGLE = 2.1        -- Spread in radians (~120 degrees)

-- Merge explosion config (EXPLOSIVE FLOOD!)
local MERGE_PARTICLE_COUNT = 120    -- Massive burst!
local MERGE_LIFETIME_MIN = 0.4      -- Longer lifetime
local MERGE_LIFETIME_MAX = 0.8
local MERGE_SPEED_MIN = 600         -- Faster burst
local MERGE_SPEED_MAX = 1200
local MERGE_SPREAD_ANGLE = math.pi * 2  -- Full 360 degrees!

-- Particle system
local particleSystem
local particleImage

-- Create a soft circular particle image
local function createParticleImage()
    local size = 32
    local canvas = love.graphics.newCanvas(size, size)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)

    -- Draw a soft glowing circle
    love.graphics.setColor(1, 1, 1, 1)
    local cx, cy = size / 2, size / 2
    local radius = size / 2 - 2

    -- Multiple circles for soft glow effect
    for r = radius, 1, -2 do
        local alpha = (r / radius) ^ 0.5
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.circle("fill", cx, cy, r)
    end

    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)
    return canvas
end

function particles.init()
    particleImage = createParticleImage()

    particleSystem = love.graphics.newParticleSystem(particleImage, 500)

    -- Particle lifetime
    particleSystem:setParticleLifetime(LIFETIME_MIN, LIFETIME_MAX)

    -- Emission rate (0 = manual emit only)
    particleSystem:setEmissionRate(0)

    -- Initial velocity (upward burst)
    particleSystem:setSpeed(SPEED_MIN, SPEED_MAX)

    -- Direction: upward with spread
    -- -math.pi/2 is straight up, spread creates the arc
    particleSystem:setDirection(-math.pi / 2)
    particleSystem:setSpread(SPREAD_ANGLE)

    -- Gravity pulls particles down
    particleSystem:setLinearAcceleration(0, GRAVITY, 0, GRAVITY)

    -- Size: start big, shrink
    particleSystem:setSizes(SIZE_START, SIZE_END)

    -- Fade out
    particleSystem:setColors(
        1, 1, 1, 1,     -- Start: full opacity
        1, 1, 1, 0.8,   -- Mid: slight fade
        1, 1, 1, 0      -- End: fully transparent
    )

    -- Slight rotation for visual interest
    particleSystem:setSpin(-2, 2)
    particleSystem:setRotation(-math.pi, math.pi)
end

function particles.spawn(x, y, color)
    if not particleSystem then return end

    -- Set color (with slight brightness variation for juiciness)
    local r, g, b = color[1], color[2], color[3]

    -- Brighten the color slightly for particles
    r = math.min(1, r * 1.2 + 0.1)
    g = math.min(1, g * 1.2 + 0.1)
    b = math.min(1, b * 1.2 + 0.1)

    particleSystem:setColors(
        r, g, b, 1,
        r, g, b, 0.8,
        r, g, b, 0
    )

    -- Position and emit
    particleSystem:setPosition(x, y)
    particleSystem:emit(PARTICLE_COUNT)
end

function particles.update(dt)
    if particleSystem then
        particleSystem:update(dt)
    end
end

function particles.draw()
    if particleSystem then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(particleSystem, 0, 0)
    end
end

-- Explosive merge burst (120 particles, full 360 degree spread)
function particles.spawnMergeExplosion(x, y, color)
    if not particleSystem then return end

    -- Brighten color for extra juiciness
    local r = math.min(1, color[1] * 1.3 + 0.15)
    local g = math.min(1, color[2] * 1.3 + 0.15)
    local b = math.min(1, color[3] * 1.3 + 0.15)

    -- Configure for merge explosion
    particleSystem:setParticleLifetime(MERGE_LIFETIME_MIN, MERGE_LIFETIME_MAX)
    particleSystem:setSpeed(MERGE_SPEED_MIN, MERGE_SPEED_MAX)
    particleSystem:setSpread(MERGE_SPREAD_ANGLE)
    particleSystem:setDirection(0)  -- All directions
    particleSystem:setSizes(1.0, 0.6, 0.2)  -- Bigger starting size

    particleSystem:setColors(
        r, g, b, 1,
        r, g, b, 0.9,
        r * 0.8, g * 0.8, b * 0.8, 0.5,
        r * 0.5, g * 0.5, b * 0.5, 0
    )

    -- Emit the explosion
    particleSystem:setPosition(x, y)
    particleSystem:emit(MERGE_PARTICLE_COUNT)

    -- Reset to normal settings
    particleSystem:setParticleLifetime(LIFETIME_MIN, LIFETIME_MAX)
    particleSystem:setSpeed(SPEED_MIN, SPEED_MAX)
    particleSystem:setSpread(SPREAD_ANGLE)
    particleSystem:setDirection(-math.pi / 2)
    particleSystem:setSizes(SIZE_START, SIZE_END)
end

-- Smaller squeeze particles (emitted during squeeze animation)
function particles.spawnSqueezeParticles(x, y, color, count)
    if not particleSystem then return end
    count = count or 5

    local r = math.min(1, color[1] * 1.2 + 0.1)
    local g = math.min(1, color[2] * 1.2 + 0.1)
    local b = math.min(1, color[3] * 1.2 + 0.1)

    particleSystem:setColors(
        r, g, b, 0.8,
        r, g, b, 0.4,
        r, g, b, 0
    )

    particleSystem:setPosition(x, y)
    particleSystem:emit(count)
end

return particles
