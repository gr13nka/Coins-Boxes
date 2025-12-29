-- animation.lua
-- Handles coin hover (bobbing) and flight (arc) animations

local layout = require("layout")
local coin_utils = require("coin_utils")

local animation = {}

-- Animation states
local STATE = {
    IDLE = "idle",
    HOVERING = "hovering",
    FLYING = "flying"
}

-- Module state
local state = STATE.IDLE
local hovering_coins = {}     -- {coin, offset_x, phase} per coin (coin can be string or table)
local hover_time = 0          -- Accumulated time for sine wave
local flight_time = 0         -- 0.0 to 1.0 progress
local flight_start_coins = {} -- Frozen positions at flight start

-- Configuration
local HOVER_BOB_AMPLITUDE = 15   -- pixels up/down
local HOVER_BOB_SPEED = 1.5      -- cycles per second (slower bobbing)
local HOVER_SPREAD = 90          -- pixels between coin centers (COIN_R * 1.5)
local FLIGHT_DURATION = 0.35     -- seconds per coin
local FLIGHT_ARC_HEIGHT = 150    -- pixels above trajectory
local DROP_DELAY = 0.15          -- delay between each coin starting to drop

-- Positions
local source_box = 0
local hover_center_x, hover_center_y = 0, 0
local dest_x, dest_y = 0, 0
local dest_box_index = 0
local dest_base_slot = 0

-- Callback
local on_flight_complete = nil
local on_coin_land = nil        -- Called when each coin lands
local coins_landed = 0          -- How many coins have landed

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

    for i, coin_data in ipairs(coins) do
        hovering_coins[i] = {
            coin = coin_data,  -- store full coin (string for classic, table for 2048)
            offset_x = start_offset + (i - 1) * HOVER_SPREAD,
            phase = (i - 1) * 0.3  -- stagger bobbing
        }
    end
end

-- Start flight animation to destination box
-- callback: called when ALL coins have landed
-- coinLandCallback: called when EACH coin lands (receives coin data)
function animation.startFlight(dest_box_idx, dest_slot, callback, coinLandCallback)
    state = STATE.FLYING
    flight_time = 0
    on_flight_complete = callback
    on_coin_land = coinLandCallback
    coins_landed = 0
    dest_box_index = dest_box_idx
    dest_base_slot = dest_slot

    -- Freeze current hover positions as flight start
    -- Coins drop one by one, so each has a staggered start time
    flight_start_coins = {}
    for i, hcoin in ipairs(hovering_coins) do
        local bob_offset = math.sin((hover_time + hcoin.phase) * HOVER_BOB_SPEED * math.pi * 2) * HOVER_BOB_AMPLITUDE
        flight_start_coins[i] = {
            x = hover_center_x + hcoin.offset_x,
            y = hover_center_y + bob_offset,
            coin = hcoin.coin,  -- store full coin data
            offset_x = hcoin.offset_x,
            start_delay = (i - 1) * DROP_DELAY,  -- stagger start times
            landed = false,
            dest_slot = dest_slot + (i - 1)      -- each coin goes to next slot down
        }
    end

    -- Calculate destination X (same for all coins in column)
    dest_x = layout.GRID_LEFT_OFFSET + layout.COLUMN_STEP * dest_box_idx
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

        -- If coin has landed, return its final position
        if coin.landed then
            local final_y = layout.GRID_TOP_Y + layout.ROW_STEP * coin.dest_slot
            return dest_x, final_y
        end

        -- Calculate this coin's individual progress (accounting for stagger delay)
        local coin_elapsed = flight_time - coin.start_delay
        if coin_elapsed < 0 then
            -- Coin hasn't started yet, stay at hover position
            return coin.x, coin.y
        end

        local t = math.min(coin_elapsed / FLIGHT_DURATION, 1.0)

        -- Ease-out quadratic for smooth landing
        local t_eased = 1 - (1 - t) * (1 - t)

        -- Start position (frozen from hover)
        local start_x = coin.x
        local start_y = coin.y

        -- Destination Y for this specific coin
        local coin_dest_y = layout.GRID_TOP_Y + layout.ROW_STEP * coin.dest_slot

        -- Control point for arc (midpoint, elevated)
        local mid_x = (start_x + dest_x) / 2
        local mid_y = math.min(start_y, coin_dest_y) - FLIGHT_ARC_HEIGHT

        -- Quadratic bezier: B(t) = (1-t)^2*P0 + 2(1-t)t*P1 + t^2*P2
        local x = (1 - t_eased) * (1 - t_eased) * start_x + 2 * (1 - t_eased) * t_eased * mid_x + t_eased * t_eased * dest_x
        local y = (1 - t_eased) * (1 - t_eased) * start_y + 2 * (1 - t_eased) * t_eased * mid_y + t_eased * t_eased * coin_dest_y

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
        flight_time = flight_time + dt

        -- Check each coin for landing
        for i, coin in ipairs(flight_start_coins) do
            if not coin.landed then
                local coin_elapsed = flight_time - coin.start_delay
                if coin_elapsed >= FLIGHT_DURATION then
                    -- This coin has landed
                    coin.landed = true
                    coins_landed = coins_landed + 1

                    -- Call per-coin callback
                    if on_coin_land then
                        on_coin_land(coin.coin, coin.dest_slot)
                    end
                end
            end
        end

        -- Check if all coins have landed
        if coins_landed >= #flight_start_coins then
            state = STATE.IDLE

            -- Execute final callback
            if on_flight_complete then
                on_flight_complete()
                on_flight_complete = nil
            end

            on_coin_land = nil
            hovering_coins = {}
            flight_start_coins = {}
        end
    end
end

-- Draw animated coins
-- COLORS: color lookup table for classic mode (string->RGB)
-- mode: "classic" or "2048" (optional, default "classic")
-- font: font for drawing numbers in 2048 mode (optional)
function animation.draw(ballImage, COLORS, mode, font)
    if state == STATE.IDLE then
        return
    end

    mode = mode or "classic"
    local imgW, imgH = ballImage:getDimensions()
    local spriteScale = (layout.COIN_R * 2) / imgW

    local coins_to_draw = (state == STATE.HOVERING) and hovering_coins or flight_start_coins

    for i, anim_coin in ipairs(coins_to_draw) do
        -- Skip coins that have already landed (they're now in boxes array)
        if not anim_coin.landed then
            local x, y = getCoinPosition(i)
            local coin_data = anim_coin.coin
            local col

            if mode == "2048" and coin_utils.isCoin(coin_data) then
                -- 2048 mode: get color from number
                col = coin_utils.numberToColor(coin_data.number, 50)
            else
                -- Classic mode: lookup color by name
                col = COLORS[coin_data] or {1, 1, 1}
            end

            love.graphics.setColor(col)
            love.graphics.draw(ballImage, x, y, 0, spriteScale, spriteScale, imgW / 2, imgH / 2)

            -- Draw number on coin for 2048 mode
            if mode == "2048" and coin_utils.isCoin(coin_data) and font then
                love.graphics.setColor(1, 1, 1)  -- white text
                love.graphics.setFont(font)
                local num_str = tostring(coin_data.number)
                local text_width = font:getWidth(num_str)
                local text_height = font:getHeight()
                love.graphics.print(num_str, x - text_width / 2, y - text_height / 2)
            end
        end
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

-- Get coin data of hovering coins (returns array of coin data - strings or tables)
function animation.getHoveringCoins()
    local coins = {}
    for i, hcoin in ipairs(hovering_coins) do
        coins[i] = hcoin.coin
    end
    return coins
end

-- Cancel animation and reset to idle
function animation.cancel()
    state = STATE.IDLE
    hovering_coins = {}
    flight_start_coins = {}
    on_flight_complete = nil
end

-- Get source box index (for returning coins)
function animation.getSourceBox()
    return source_box
end

-- Split hovering coins: keep first N for placing, return the rest
-- Returns array of coins that were removed (to be returned to source)
function animation.splitHoveringCoins(keep_count)
    if state ~= STATE.HOVERING then
        return {}
    end

    local removed_coins = {}

    -- Remove coins beyond keep_count
    while #hovering_coins > keep_count do
        local removed = table.remove(hovering_coins)
        table.insert(removed_coins, removed.coin)
    end

    -- Recalculate horizontal spread for remaining coins
    local total_width = (#hovering_coins - 1) * HOVER_SPREAD
    local start_offset = -total_width / 2
    for i, hcoin in ipairs(hovering_coins) do
        hcoin.offset_x = start_offset + (i - 1) * HOVER_SPREAD
    end

    return removed_coins
end

return animation
