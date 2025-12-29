-- animation.lua
-- Handles coin hover (bobbing) and flight (arc) animations

local layout = require("layout")
local coin_utils = require("coin_utils")

local animation = {}

-- Animation states
local STATE = {
    IDLE = "idle",
    HOVERING = "hovering",
    FLYING = "flying",
    MERGING = "merging"
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

-- Merge animation configuration
local MERGE_SLIDE_DURATION = 0.15     -- time for one coin to slide into another
local MERGE_IMPACT_PAUSE = 0.05       -- brief pause on impact
local MERGE_POP_DURATION = 0.2        -- new coin pops after final merge
local MERGE_BOX_DELAY = 0.2           -- delay between sequential boxes
local MERGE_POP_OVERSHOOT = 1.3       -- scale overshoot on pop

-- Screen shake
local SHAKE_INTENSITY = 12            -- max shake pixels
local SHAKE_DURATION = 0.15           -- shake duration per impact
local screen_shake_time = 0
local screen_shake_intensity = 0

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

-- Merge animation state
local merge_boxes = {}          -- Array of merge data from getMergeableBoxes()
local merge_time = 0            -- Total elapsed time
local current_merge_box = 0     -- Which box is currently animating (1-indexed)
local on_merge_complete = nil   -- Called when all boxes done
local on_box_merge = nil        -- Called when each box completes merge
local particles_module = nil    -- Reference to particles module (set at runtime)

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

-- Start merge animation for multiple boxes
-- merge_data: array from game_2048.getMergeableBoxes()
-- callback: called when ALL merges complete
-- boxMergeCallback: called when EACH box finishes merging (receives merge info)
-- particlesRef: reference to particles module
function animation.startMerge(merge_data, callback, boxMergeCallback, particlesRef)
    if #merge_data == 0 then
        if callback then callback() end
        return
    end

    state = STATE.MERGING
    merge_boxes = merge_data
    merge_time = 0
    current_merge_box = 1
    on_merge_complete = callback
    on_box_merge = boxMergeCallback
    particles_module = particlesRef
    screen_shake_time = 0
    screen_shake_intensity = 0

    -- Initialize animation state for each box
    for i, box_data in ipairs(merge_boxes) do
        box_data.start_time = (i - 1) * MERGE_BOX_DELAY
        box_data.phase = "waiting"
        box_data.phase_time = 0

        -- Calculate box X position
        local box_x = layout.GRID_LEFT_OFFSET + layout.COLUMN_STEP * box_data.box_idx
        box_data.center_x = box_x

        -- Get number of coins in this box
        local num_coins = #box_data.coins
        box_data.num_coins = num_coins

        -- Slot Y positions for all coins (1=top, N=bottom)
        box_data.slot_y = {}
        for slot = 1, num_coins do
            box_data.slot_y[slot] = layout.GRID_TOP_Y + layout.ROW_STEP * slot
        end

        -- Track which coins are still visible (bottom coin starts sliding first)
        box_data.coins_visible = {}
        for slot = 1, num_coins do
            box_data.coins_visible[slot] = true
        end

        -- Current slide step (1 = bottom slides to second-from-bottom, etc.)
        -- Total slides needed = num_coins - 1
        box_data.current_slide = 0
        box_data.sliding_coin_y = box_data.slot_y[num_coins]  -- start at bottom
        box_data.merged_scale = 1.0
    end
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

    elseif state == STATE.MERGING then
        merge_time = merge_time + dt

        -- Update screen shake
        if screen_shake_time > 0 then
            screen_shake_time = screen_shake_time - dt
            if screen_shake_time < 0 then screen_shake_time = 0 end
        end

        local all_done = true

        for i, box_data in ipairs(merge_boxes) do
            if box_data.phase ~= "done" then
                all_done = false

                local num_coins = box_data.num_coins
                local total_slides = num_coins - 1

                -- Check if this box should start
                if box_data.phase == "waiting" and merge_time >= box_data.start_time then
                    box_data.phase = "slide"
                    box_data.phase_time = 0
                    box_data.current_slide = 1
                    box_data.sliding_coin_y = box_data.slot_y[num_coins]  -- start at bottom
                end

                -- Update phase time
                if box_data.phase ~= "waiting" then
                    box_data.phase_time = box_data.phase_time + dt
                end

                -- Slide phase: coin slides up into the one above
                if box_data.phase == "slide" then
                    local slide = box_data.current_slide
                    local from_slot = num_coins - slide + 1  -- e.g., slide 1: from bottom (slot N)
                    local to_slot = from_slot - 1             -- to the slot above

                    local t = math.min(box_data.phase_time / MERGE_SLIDE_DURATION, 1)
                    local eased = 1 - (1 - t) * (1 - t)  -- ease-out
                    box_data.sliding_coin_y = box_data.slot_y[from_slot] +
                        (box_data.slot_y[to_slot] - box_data.slot_y[from_slot]) * eased

                    if t >= 1 then
                        box_data.phase = "impact"
                        box_data.phase_time = 0

                        -- Hide the coins that just merged
                        box_data.coins_visible[from_slot] = false
                        box_data.coins_visible[to_slot] = false
                        box_data.sliding_coin_y = box_data.slot_y[to_slot]

                        -- Particles and shake! (intensity increases with each merge)
                        local is_final = (slide == total_slides)
                        local shake_mult = is_final and 1.0 or (0.4 + 0.3 * (slide / total_slides))

                        if particles_module then
                            particles_module.spawnMergeExplosion(
                                box_data.center_x, box_data.slot_y[to_slot], box_data.color
                            )
                        end
                        screen_shake_time = SHAKE_DURATION
                        screen_shake_intensity = SHAKE_INTENSITY * shake_mult

                        -- If final slide, execute merge callback
                        if is_final and on_box_merge then
                            on_box_merge(box_data)
                        end
                    end

                -- Impact phase: brief pause, then next slide or pop
                elseif box_data.phase == "impact" then
                    if box_data.phase_time >= MERGE_IMPACT_PAUSE then
                        if box_data.current_slide >= total_slides then
                            -- All slides done, go to pop
                            box_data.phase = "pop"
                            box_data.phase_time = 0
                            -- Final explosion with new color!
                            if particles_module then
                                particles_module.spawnMergeExplosion(
                                    box_data.center_x, box_data.slot_y[1], box_data.new_color
                                )
                            end
                        else
                            -- More slides to go
                            box_data.current_slide = box_data.current_slide + 1
                            box_data.phase = "slide"
                            box_data.phase_time = 0
                        end
                    end

                -- Pop phase: new coin appears with bounce
                elseif box_data.phase == "pop" then
                    local t = box_data.phase_time / MERGE_POP_DURATION
                    -- Elastic overshoot
                    box_data.merged_scale = 1 + (MERGE_POP_OVERSHOOT - 1) * math.sin(t * math.pi) * (1 - t * 0.5)

                    if box_data.phase_time >= MERGE_POP_DURATION then
                        box_data.phase = "done"
                        box_data.merged_scale = 1.0
                    end
                end
            end
        end

        -- Check if all boxes are done
        if all_done then
            state = STATE.IDLE
            screen_shake_time = 0
            if on_merge_complete then
                on_merge_complete()
                on_merge_complete = nil
            end
            on_box_merge = nil
            merge_boxes = {}
            particles_module = nil
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

-- Draw merge animation (coins sliding up one by one)
function animation.drawMerge(ballImage, font)
    if state ~= STATE.MERGING then return end

    local imgW, imgH = ballImage:getDimensions()
    local base_scale = (layout.COIN_R * 2) / imgW

    for _, box_data in ipairs(merge_boxes) do
        local phase = box_data.phase

        -- Skip waiting and done phases
        if phase == "waiting" or phase == "done" then
            goto continue
        end

        -- Draw stationary coins that are still visible
        for slot = 1, box_data.num_coins do
            if box_data.coins_visible[slot] then
                love.graphics.setColor(box_data.color)
                love.graphics.draw(ballImage, box_data.center_x, box_data.slot_y[slot],
                    0, base_scale, base_scale, imgW / 2, imgH / 2)

                if font then
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.setFont(font)
                    local num_str = tostring(box_data.old_number)
                    local text_width = font:getWidth(num_str)
                    local text_height = font:getHeight()
                    love.graphics.print(num_str,
                        box_data.center_x - text_width / 2,
                        box_data.slot_y[slot] - text_height / 2)
                end
            end
        end

        -- Draw sliding coin (during slide and impact phases)
        if phase == "slide" or phase == "impact" then
            love.graphics.setColor(box_data.color)
            love.graphics.draw(ballImage, box_data.center_x, box_data.sliding_coin_y,
                0, base_scale, base_scale, imgW / 2, imgH / 2)

            if font then
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(font)
                local num_str = tostring(box_data.old_number)
                local text_width = font:getWidth(num_str)
                local text_height = font:getHeight()
                love.graphics.print(num_str,
                    box_data.center_x - text_width / 2,
                    box_data.sliding_coin_y - text_height / 2)
            end
        end

        -- Draw merged coin (during pop phase)
        if phase == "pop" then
            local scale = box_data.merged_scale

            love.graphics.setColor(box_data.new_color)
            love.graphics.draw(ballImage, box_data.center_x, box_data.slot_y[1],
                0, base_scale * scale, base_scale * scale, imgW / 2, imgH / 2)

            if font then
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(font)
                local num_str = tostring(box_data.new_number)
                local text_width = font:getWidth(num_str)
                local text_height = font:getHeight()
                love.graphics.print(num_str,
                    box_data.center_x - text_width / 2,
                    box_data.slot_y[1] - text_height / 2)
            end
        end

        ::continue::
    end

    love.graphics.setColor(1, 1, 1)
end

-- Get screen shake offset (call this to apply shake to drawing)
function animation.getScreenShake()
    if screen_shake_time > 0 then
        local decay = screen_shake_time / SHAKE_DURATION
        local shake_x = (math.random() * 2 - 1) * screen_shake_intensity * decay
        local shake_y = (math.random() * 2 - 1) * screen_shake_intensity * decay
        return shake_x, shake_y
    end
    return 0, 0
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

function animation.isMerging()
    return state == STATE.MERGING
end

-- Get list of box indices currently being animated (for hiding static coins)
function animation.getMergingBoxIndices()
    if state ~= STATE.MERGING then return {} end

    local indices = {}
    for _, box_data in ipairs(merge_boxes) do
        -- Hide box coins during all active animation phases
        local phase = box_data.phase
        if phase ~= "waiting" and phase ~= "done" then
            indices[box_data.box_idx] = true
        end
    end
    return indices
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
