-- animation.lua
-- Handles coin hover (bobbing) and flight (arc) animations

local layout = require("layout")

local animation = {}

-- Animation states
local STATE = {
    IDLE = "idle",
    HOVERING = "hovering",
    FLYING = "flying"
}

-- Module state
local state = STATE.IDLE
local hovering_coins = {}     -- {color, offset_x, phase} per coin
local hover_time = 0          -- Accumulated time for sine wave
local flight_time = 0         -- 0.0 to 1.0 progress
local flight_start_coins = {} -- Frozen positions at flight start

-- Configuration
local HOVER_BOB_AMPLITUDE = 15   -- pixels up/down
local HOVER_BOB_SPEED = 3        -- cycles per second
local HOVER_SPREAD = 90          -- pixels between coin centers (COIN_R * 1.5)
local FLIGHT_DURATION = 0.4      -- seconds
local FLIGHT_ARC_HEIGHT = 150    -- pixels above trajectory

-- Positions
local source_box = 0
local hover_center_x, hover_center_y = 0, 0
local dest_x, dest_y = 0, 0

-- Callback
local on_flight_complete = nil

-- Start hovering animation when coins are picked up
function animation.startHover(coins, source_box_index)
    state = STATE.HOVERING
    hover_time = 0
    hovering_coins = {}
    source_box = source_box_index

    -- Calculate hover position: centered on screen, above grid
    hover_center_x = layout.VW / 2
    hover_center_y = layout.GRID_TOP_Y - layout.ROW_STEP

    -- Spread coins horizontally with staggered bob phases
    local total_width = (#coins - 1) * HOVER_SPREAD
    local start_offset = -total_width / 2

    for i, color in ipairs(coins) do
        hovering_coins[i] = {
            color = color,
            offset_x = start_offset + (i - 1) * HOVER_SPREAD,
            phase = (i - 1) * 0.3  -- stagger bobbing
        }
    end
end

-- Start flight animation to destination box
function animation.startFlight(dest_box_index, dest_slot, callback)
    state = STATE.FLYING
    flight_time = 0
    on_flight_complete = callback

    -- Freeze current hover positions as flight start
    flight_start_coins = {}
    for i, coin in ipairs(hovering_coins) do
        local bob_offset = math.sin((hover_time + coin.phase) * HOVER_BOB_SPEED * math.pi * 2) * HOVER_BOB_AMPLITUDE
        flight_start_coins[i] = {
            x = hover_center_x + coin.offset_x,
            y = hover_center_y + bob_offset,
            color = coin.color,
            offset_x = coin.offset_x
        }
    end

    -- Calculate destination position (center of target slot)
    dest_x = layout.GRID_LEFT_OFFSET + layout.COLUMN_STEP * dest_box_index
    dest_y = layout.GRID_TOP_Y + layout.ROW_STEP * dest_slot
end

-- Get position of a coin during animation
local function getCoinPosition(index)
    if state == STATE.HOVERING then
        local coin = hovering_coins[index]
        -- Bobbing: sine wave motion
        local bob_offset = math.sin((hover_time + coin.phase) * HOVER_BOB_SPEED * math.pi * 2) * HOVER_BOB_AMPLITUDE
        return hover_center_x + coin.offset_x, hover_center_y + bob_offset

    elseif state == STATE.FLYING then
        local coin = flight_start_coins[index]
        local t = flight_time

        -- Ease-out quadratic for smooth landing
        local t_eased = 1 - (1 - t) * (1 - t)

        -- Start position (frozen from hover)
        local start_x = coin.x
        local start_y = coin.y

        -- Control point for arc (midpoint, elevated)
        local mid_x = (start_x + dest_x) / 2
        local mid_y = math.min(start_y, dest_y) - FLIGHT_ARC_HEIGHT

        -- Quadratic bezier: B(t) = (1-t)^2*P0 + 2(1-t)t*P1 + t^2*P2
        local x = (1 - t_eased) * (1 - t_eased) * start_x + 2 * (1 - t_eased) * t_eased * mid_x + t_eased * t_eased * dest_x
        local y = (1 - t_eased) * (1 - t_eased) * start_y + 2 * (1 - t_eased) * t_eased * mid_y + t_eased * t_eased * dest_y

        -- Converge coins horizontally as they approach destination
        local spread_factor = 1 - t_eased
        x = x + coin.offset_x * spread_factor

        return x, y
    end

    return 0, 0
end

-- Update animation each frame
function animation.update(dt)
    if state == STATE.HOVERING then
        hover_time = hover_time + dt

    elseif state == STATE.FLYING then
        flight_time = flight_time + dt / FLIGHT_DURATION

        if flight_time >= 1.0 then
            flight_time = 1.0
            state = STATE.IDLE

            -- Execute callback to place coins
            if on_flight_complete then
                on_flight_complete()
                on_flight_complete = nil
            end

            hovering_coins = {}
            flight_start_coins = {}
        end
    end
end

-- Draw animated coins
function animation.draw(ballImage, COLORS)
    if state == STATE.IDLE then
        return
    end

    local imgW, imgH = ballImage:getDimensions()
    local spriteScale = (layout.COIN_R * 2) / imgW

    local coins_to_draw = (state == STATE.HOVERING) and hovering_coins or flight_start_coins

    for i, coin in ipairs(coins_to_draw) do
        local x, y = getCoinPosition(i)
        local col = COLORS[coin.color] or {1, 1, 1}

        love.graphics.setColor(col)
        love.graphics.draw(ballImage, x, y, 0, spriteScale, spriteScale, imgW / 2, imgH / 2)
    end
end

-- Query functions
function animation.isAnimating()
    return state ~= STATE.IDLE
end

function animation.isHovering()
    return state == STATE.HOVERING
end

function animation.isFlying()
    return state == STATE.FLYING
end

-- Get colors of hovering coins
function animation.getHoveringCoins()
    local colors = {}
    for i, coin in ipairs(hovering_coins) do
        colors[i] = coin.color
    end
    return colors
end

-- Cancel animation and reset to idle
function animation.cancel()
    state = STATE.IDLE
    hovering_coins = {}
    flight_start_coins = {}
    on_flight_complete = nil
end

return animation
