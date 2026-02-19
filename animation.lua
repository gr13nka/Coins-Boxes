-- animation.lua
-- Handles coin hover (bobbing) and flight (arc) animations
-- Dual-track system: pick/place and background (merge/deal) run independently

local layout = require("layout")
local coin_utils = require("coin_utils")
local graphics = require("graphics")

local animation = {}

-- Animation states
local STATE = {
    IDLE = "idle",
    HOVERING = "hovering",
    FLYING = "flying",
    MERGING = "merging",
    DEALING = "dealing"
}

-- Dual-track state: pick/place and background can run independently
local pick_state = STATE.IDLE   -- "idle", "hovering", "flying"
local bg_state = STATE.IDLE     -- "idle", "merging", "dealing"

-- Global animation speed multiplier (1.5 = 50% faster animations)
local SPEED_MULT = 1.5

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

-- Dealing animation configuration (poker dealer style)
local DEALING_DROP_DELAY = 0.12       -- delay between coins being dealt (fast rhythmic)
local DEALING_FLIGHT_DURATION = 0.3   -- flight time per coin
local DEALING_ARC_HEIGHT = 120        -- arc height for card-like trajectory
local DEALING_LAND_SHAKE = 6          -- shake intensity per landing
local DEALING_LAND_SHAKE_DURATION = 0.08
local DEALING_BOUNCE_OVERSHOOT = 1.2  -- elastic bounce scale
local DEALING_BOUNCE_DURATION = 0.12  -- bounce animation time
local DEALING_SPIN_SPEED = 8          -- rotation speed during flight

-- Dealing animation state
local dealing_coins = {}              -- array of coin data with destinations
local dealing_time = 0                -- total elapsed time
local dealing_mode = "classic"        -- "classic" or "2048"
local on_dealing_complete = nil       -- final callback
local on_coin_dealt = nil             -- per-coin land callback
local dealing_particles = nil         -- reference to particles module
local dealer_x, dealer_y = 0, 0       -- dealer hand position

-- Positions
local source_box = 0
local hover_center_x, hover_center_y = 0, 0
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
    pick_state = STATE.HOVERING
    hover_time = 0
    hovering_coins = {}
    source_box = source_box_index

    -- Calculate hover position: centered on screen, above grid
    hover_center_x = layout.VW / 2
    hover_center_y = layout.GRID_TOP_Y - layout.ROW_STEP

    -- Spread coins horizontally with staggered bob phases
    local hover_spread = layout.COIN_R * 1.5
    local total_width = (#coins - 1) * hover_spread
    local start_offset = -total_width / 2

    for i, coin_data in ipairs(coins) do
        hovering_coins[i] = {
            coin = coin_data,  -- store full coin (string for classic, table for 2048)
            offset_x = start_offset + (i - 1) * hover_spread,
            phase = (i - 1) * 0.3  -- stagger bobbing
        }
    end
end

-- Start flight animation to destination box
-- callback: called when ALL coins have landed
-- coinLandCallback: called when EACH coin lands (receives coin data)
-- opts: optional table with {dest_x, top_y} for custom destination positions
function animation.startFlight(dest_box_idx, dest_slot, callback, coinLandCallback, opts)
    opts = opts or {}
    pick_state = STATE.FLYING
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
        local coin_slot = dest_slot + (i - 1)
        -- Pre-compute per-coin destination (accounts for 2-layer offsets)
        local coin_dest_x, coin_dest_y
        if opts.dest_x then
            coin_dest_x = opts.dest_x
            local base_top_y = opts.top_y or layout.GRID_TOP_Y
            coin_dest_y = base_top_y + layout.ROW_STEP * coin_slot
        else
            coin_dest_x, coin_dest_y = layout.slotPosition(dest_box_idx, coin_slot)
        end
        flight_start_coins[i] = {
            x = hover_center_x + hcoin.offset_x,
            y = hover_center_y + bob_offset,
            coin = hcoin.coin,  -- store full coin data
            offset_x = hcoin.offset_x,
            start_delay = (i - 1) * DROP_DELAY,  -- stagger start times
            landed = false,
            dest_slot = coin_slot,
            dest_x = coin_dest_x,
            dest_y = coin_dest_y,
        }
    end
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

    bg_state = STATE.MERGING
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

        -- Calculate box center X (use custom if provided, otherwise default grid)
        if not box_data.center_x then
            box_data.center_x = (layout.columnPosition(box_data.box_idx))
        end

        -- Get number of coins in this box
        local num_coins = #box_data.coins
        box_data.num_coins = num_coins

        -- Slot positions for all coins (using layout.slotPosition for 2-layer support)
        box_data.slot_x = {}
        box_data.slot_y = {}
        if box_data.top_y then
            -- Custom positions (e.g. dev mode) - no 2-layer
            for slot = 1, num_coins do
                box_data.slot_x[slot] = box_data.center_x
                box_data.slot_y[slot] = box_data.top_y + layout.ROW_STEP * slot
            end
        else
            for slot = 1, num_coins do
                local sx, sy = layout.slotPosition(box_data.box_idx, slot)
                box_data.slot_x[slot] = sx
                box_data.slot_y[slot] = sy
            end
        end

        -- Track which coins are still visible (bottom coin starts sliding first)
        box_data.coins_visible = {}
        for slot = 1, num_coins do
            box_data.coins_visible[slot] = true
        end

        -- Current slide step (1 = bottom slides to second-from-bottom, etc.)
        -- Total slides needed = num_coins - 1
        box_data.current_slide = 0
        box_data.sliding_coin_x = box_data.slot_x[num_coins]  -- start at bottom
        box_data.sliding_coin_y = box_data.slot_y[num_coins]
        box_data.merged_scale = 1.0
    end
end

-- Start dealing animation for newly added coins (poker dealer style)
-- coins_to_deal: array of {coin, dest_box_idx, dest_slot}
-- mode: "classic" or "2048"
-- callback: called when ALL coins have landed
-- coinLandCallback: called when EACH coin lands (receives coin, box_idx, slot)
-- particlesRef: reference to particles module
function animation.startDealing(coins_to_deal, mode, callback, coinLandCallback, particlesRef)
    if #coins_to_deal == 0 then
        if callback then callback() end
        return
    end

    bg_state = STATE.DEALING
    dealing_coins = {}
    dealing_time = 0
    dealing_mode = mode or "classic"
    on_dealing_complete = callback
    on_coin_dealt = coinLandCallback
    dealing_particles = particlesRef
    screen_shake_time = 0

    -- Dealer hand position: bottom center, above button area
    dealer_x = layout.VW / 2
    dealer_y = layout.BUTTON_AREA_Y - 100

    -- Initialize each coin with dealer-style flight parameters
    for i, coin_data in ipairs(coins_to_deal) do
        -- Calculate destination position (use custom if provided, otherwise slotPosition for 2-layer)
        local dest_x, dest_y
        if coin_data.dest_x then
            dest_x = coin_data.dest_x
            dest_y = coin_data.dest_y or (layout.GRID_TOP_Y + layout.ROW_STEP * coin_data.dest_slot)
        else
            dest_x, dest_y = layout.slotPosition(coin_data.dest_box_idx, coin_data.dest_slot)
        end

        dealing_coins[i] = {
            coin = coin_data.coin,
            dest_box_idx = coin_data.dest_box_idx,
            dest_slot = coin_data.dest_slot,
            dest_x = dest_x,
            dest_y = dest_y,
            -- Flight timing (staggered like cards being dealt)
            flight_start_time = (i - 1) * DEALING_DROP_DELAY,
            -- State tracking
            started = false,
            landed = false,
            done = false,
            bounce_time = 0,
            scale = 1.0,
            rotation = 0,
            -- Add slight random offset to start position for natural feel
            start_offset_x = (math.random() - 0.5) * 20,
            start_offset_y = (math.random() - 0.5) * 10
        }
    end
end

-- Get position of a coin during animation
local function getCoinPosition(index)
    if pick_state == STATE.HOVERING then
        local coin = hovering_coins[index]
        -- Bobbing: sine wave motion
        local bob_offset = math.sin((hover_time + coin.phase) * HOVER_BOB_SPEED * math.pi * 2) * HOVER_BOB_AMPLITUDE
        return hover_center_x + coin.offset_x, hover_center_y + bob_offset

    elseif pick_state == STATE.FLYING then
        local coin = flight_start_coins[index]

        -- If coin has landed, return its final position
        if coin.landed then
            return coin.dest_x, coin.dest_y
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

        -- Per-coin destination (pre-computed with 2-layer support)
        local coin_dest_x = coin.dest_x
        local coin_dest_y = coin.dest_y

        -- Control point for arc (midpoint, elevated)
        local mid_x = (start_x + coin_dest_x) / 2
        local mid_y = math.min(start_y, coin_dest_y) - FLIGHT_ARC_HEIGHT

        -- Quadratic bezier: B(t) = (1-t)^2*P0 + 2(1-t)t*P1 + t^2*P2
        local x = (1 - t_eased) * (1 - t_eased) * start_x + 2 * (1 - t_eased) * t_eased * mid_x + t_eased * t_eased * coin_dest_x
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
    dt = dt * SPEED_MULT

    -- Always decay screen shake (shared by merge and dealing)
    if screen_shake_time > 0 then
        screen_shake_time = screen_shake_time - dt
        if screen_shake_time < 0 then screen_shake_time = 0 end
    end

    -- === Pick/place track ===
    if pick_state == STATE.HOVERING then
        hover_time = hover_time + dt

    elseif pick_state == STATE.FLYING then
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
            pick_state = STATE.IDLE

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

    -- === Background track ===
    if bg_state == STATE.MERGING then
        merge_time = merge_time + dt

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
                    box_data.sliding_coin_x = box_data.slot_x[num_coins]
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
                    box_data.sliding_coin_x = box_data.slot_x[from_slot] +
                        (box_data.slot_x[to_slot] - box_data.slot_x[from_slot]) * eased
                    box_data.sliding_coin_y = box_data.slot_y[from_slot] +
                        (box_data.slot_y[to_slot] - box_data.slot_y[from_slot]) * eased

                    if t >= 1 then
                        box_data.phase = "impact"
                        box_data.phase_time = 0

                        -- Hide the coins that just merged
                        box_data.coins_visible[from_slot] = false
                        box_data.coins_visible[to_slot] = false
                        box_data.sliding_coin_x = box_data.slot_x[to_slot]
                        box_data.sliding_coin_y = box_data.slot_y[to_slot]

                        -- Particles and shake! (intensity increases with each merge)
                        local is_final = (slide == total_slides)
                        local shake_mult = is_final and 1.0 or (0.4 + 0.3 * (slide / total_slides))

                        -- Use progressive color for particles if enabled
                        local particle_color = box_data.color
                        if box_data.progressive_merge then
                            local current_number = box_data.old_number + slide
                            particle_color = coin_utils.numberToColor(current_number, box_data.max_number or 50)
                        end

                        if particles_module then
                            particles_module.spawnMergeExplosion(
                                box_data.slot_x[to_slot], box_data.slot_y[to_slot], particle_color
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
                                    box_data.slot_x[1], box_data.slot_y[1], box_data.new_color
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
            bg_state = STATE.IDLE
            screen_shake_time = 0
            if on_merge_complete then
                on_merge_complete()
                on_merge_complete = nil
            end
            on_box_merge = nil
            merge_boxes = {}
            particles_module = nil
        end

    elseif bg_state == STATE.DEALING then
        dealing_time = dealing_time + dt

        local all_done = true

        for i, coin_data in ipairs(dealing_coins) do
            if not coin_data.done then
                all_done = false

                local coin_elapsed = dealing_time - coin_data.flight_start_time

                if coin_elapsed < 0 then
                    -- Coin hasn't been dealt yet - stays at dealer position (invisible)
                    coin_data.started = false
                    coin_data.current_x = dealer_x + coin_data.start_offset_x
                    coin_data.current_y = dealer_y + coin_data.start_offset_y
                    coin_data.scale = 0.8
                    coin_data.rotation = 0

                elseif not coin_data.landed then
                    -- Coin is flying from dealer to destination
                    coin_data.started = true
                    local t = math.min(coin_elapsed / DEALING_FLIGHT_DURATION, 1.0)

                    -- Ease-out cubic for snappy card-like motion
                    local t_eased = 1 - (1 - t) * (1 - t) * (1 - t)

                    -- Start position (dealer hand)
                    local start_x = dealer_x + coin_data.start_offset_x
                    local start_y = dealer_y + coin_data.start_offset_y

                    -- Control point for arc (above the path, card-like trajectory)
                    local mid_x = start_x + (coin_data.dest_x - start_x) * 0.4
                    local mid_y = start_y - DEALING_ARC_HEIGHT

                    -- Quadratic bezier for card-like arc
                    coin_data.current_x = (1 - t_eased) * (1 - t_eased) * start_x +
                                          2 * (1 - t_eased) * t_eased * mid_x +
                                          t_eased * t_eased * coin_data.dest_x
                    coin_data.current_y = (1 - t_eased) * (1 - t_eased) * start_y +
                                          2 * (1 - t_eased) * t_eased * mid_y +
                                          t_eased * t_eased * coin_data.dest_y

                    -- Card spin during flight (slows down as it lands)
                    coin_data.rotation = t * DEALING_SPIN_SPEED * (1 - t * 0.5)

                    -- Scale: starts small, grows slightly, then normal
                    coin_data.scale = 0.8 + 0.3 * math.sin(t * math.pi)

                    -- Check if landed
                    if t >= 1.0 then
                        coin_data.landed = true
                        coin_data.bounce_time = 0
                        coin_data.current_x = coin_data.dest_x
                        coin_data.current_y = coin_data.dest_y
                        coin_data.rotation = 0

                        -- Trigger effects
                        screen_shake_time = DEALING_LAND_SHAKE_DURATION
                        screen_shake_intensity = DEALING_LAND_SHAKE

                        -- Call land callback
                        if on_coin_dealt then
                            on_coin_dealt(coin_data.coin, coin_data.dest_box_idx, coin_data.dest_slot)
                        end
                    end
                end

                -- Bounce phase (after landing)
                if coin_data.landed then
                    coin_data.bounce_time = coin_data.bounce_time + dt
                    local t = coin_data.bounce_time / DEALING_BOUNCE_DURATION

                    if t >= 1 then
                        coin_data.done = true
                        coin_data.scale = 1.0
                        coin_data.rotation = 0
                    else
                        -- Elastic overshoot
                        coin_data.scale = 1 + (DEALING_BOUNCE_OVERSHOOT - 1) * math.sin(t * math.pi) * (1 - t * 0.5)
                        coin_data.rotation = 0
                    end
                end
            end
        end

        -- Check if all coins are done
        if all_done then
            bg_state = STATE.IDLE
            screen_shake_time = 0
            if on_dealing_complete then
                on_dealing_complete()
                on_dealing_complete = nil
            end
            on_coin_dealt = nil
            dealing_coins = {}
            dealing_particles = nil
        end
    end
end

-- Draw animated coins
-- COLORS: color lookup table for classic mode (string->RGB)
-- mode: "classic" or "2048" (optional, default "classic")
-- font: font for drawing numbers in 2048 mode (optional)
function animation.draw(ballImage, COLORS, mode, font)
    if pick_state == STATE.IDLE then
        return
    end

    mode = mode or "classic"
    local imgW, imgH = ballImage:getDimensions()
    local spriteScale = (layout.COIN_R * 2) / imgW

    local coins_to_draw = (pick_state == STATE.HOVERING) and hovering_coins or flight_start_coins

    for i, anim_coin in ipairs(coins_to_draw) do
        -- Skip coins that have already landed (they're now in boxes array)
        if not anim_coin.landed then
            local x, y = getCoinPosition(i)
            local coin_data = anim_coin.coin

            if mode == "2048" and coin_utils.isCoin(coin_data) then
                -- 2048 mode: draw per-color fruit image
                graphics.drawCoin2048(font, x, y, coin_data.number, 50)
            else
                -- Classic mode: tinted ball sprite
                local col = COLORS[coin_data] or {1, 1, 1}
                love.graphics.setColor(col)
                love.graphics.draw(ballImage, x, y, 0, spriteScale, spriteScale, imgW / 2, imgH / 2)
            end
        end
    end
end

-- Draw merge animation (coins sliding up one by one)
function animation.drawMerge(ballImage, font)
    if bg_state ~= STATE.MERGING then return end

    local imgW, imgH = ballImage:getDimensions()
    local base_scale = (layout.COIN_R * 2) / imgW

    for _, box_data in ipairs(merge_boxes) do
        local phase = box_data.phase

        -- Only draw active phases (not waiting or done)
        if phase ~= "waiting" and phase ~= "done" then
            -- Check if this is a 2048-mode merge (has old_number)
            local is_2048 = box_data.old_number ~= nil

            -- For progressive merge, calculate current number based on completed slides
            local current_number = box_data.old_number
            if box_data.progressive_merge and box_data.current_slide > 0 then
                current_number = box_data.old_number + box_data.current_slide
            end

            -- Draw stationary coins that are still visible
            for slot = 1, box_data.num_coins do
                if box_data.coins_visible[slot] then
                    if is_2048 and font then
                        graphics.drawCoin2048(font, box_data.slot_x[slot], box_data.slot_y[slot],
                            box_data.old_number, box_data.max_number or 50)
                    else
                        love.graphics.setColor(box_data.color)
                        love.graphics.draw(ballImage, box_data.slot_x[slot], box_data.slot_y[slot],
                            0, base_scale, base_scale, imgW / 2, imgH / 2)
                    end
                end
            end

            -- Draw sliding coin (during slide and impact phases)
            if phase == "slide" or phase == "impact" then
                if is_2048 and font then
                    graphics.drawCoin2048(font, box_data.sliding_coin_x, box_data.sliding_coin_y,
                        current_number, box_data.max_number or 50)
                else
                    local current_color = box_data.color
                    if box_data.progressive_merge and box_data.current_slide > 0 then
                        current_color = coin_utils.numberToColor(current_number, box_data.max_number or 50)
                    end
                    love.graphics.setColor(current_color)
                    love.graphics.draw(ballImage, box_data.sliding_coin_x, box_data.sliding_coin_y,
                        0, base_scale, base_scale, imgW / 2, imgH / 2)
                end
            end

            -- Draw merged coin (during pop phase)
            if phase == "pop" then
                if is_2048 and font then
                    graphics.drawCoin2048(font, box_data.slot_x[1], box_data.slot_y[1],
                        box_data.new_number, box_data.max_number or 50, box_data.merged_scale)
                else
                    local scale = box_data.merged_scale
                    love.graphics.setColor(box_data.new_color)
                    love.graphics.draw(ballImage, box_data.slot_x[1], box_data.slot_y[1],
                        0, base_scale * scale, base_scale * scale, imgW / 2, imgH / 2)
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1)
end

-- Draw dealing animation (poker dealer style - coins flying from bottom)
-- COLORS: color lookup table for classic mode
-- font: font for drawing numbers in 2048 mode
function animation.drawDealing(ballImage, COLORS, font)
    if bg_state ~= STATE.DEALING then return end

    local imgW, imgH = ballImage:getDimensions()
    local base_scale = (layout.COIN_R * 2) / imgW

    for i, coin_data in ipairs(dealing_coins) do
        -- Only draw coins that have started and aren't done
        if coin_data.started and not coin_data.done then
            local x = coin_data.current_x or dealer_x
            local y = coin_data.current_y or dealer_y
            local coinScale = coin_data.scale or 1.0
            local rotation = coin_data.rotation or 0

            if dealing_mode == "2048" and coin_utils.isCoin(coin_data.coin) then
                -- 2048 mode: fruit image or tinted ball depending on config
                local num = coin_data.coin.number
                local coinImage, cImgW, cImgH, cScale
                if layout.USE_FRUIT_IMAGES then
                    coinImage = coin_utils.numberToImage(num)
                    cImgW, cImgH = coinImage:getDimensions()
                    cScale = (layout.COIN_R * 2) / cImgW * coinScale
                    love.graphics.setColor(1, 1, 1)
                else
                    coinImage = ballImage
                    cImgW, cImgH = coinImage:getDimensions()
                    cScale = (layout.COIN_R * 2) / cImgW * coinScale
                    love.graphics.setColor(coin_utils.numberToColor(num, 50))
                end
                love.graphics.draw(coinImage, x, y, rotation, cScale, cScale, cImgW / 2, cImgH / 2)

                -- Draw number rotated with coin
                if font then
                    love.graphics.push()
                    love.graphics.translate(x, y)
                    love.graphics.rotate(rotation)
                    if layout.USE_FRUIT_IMAGES then
                        love.graphics.setColor(0, 0, 0)
                    else
                        love.graphics.setColor(1, 1, 1)
                    end
                    love.graphics.setFont(font)
                    local num_str = tostring(num)
                    local text_width = font:getWidth(num_str)
                    local text_height = font:getHeight()
                    love.graphics.print(num_str, -text_width / 2, -text_height / 2)
                    love.graphics.pop()
                end
            else
                -- Classic mode: tinted ball sprite
                local col = COLORS[coin_data.coin] or {1, 1, 1}
                local scale = coinScale * base_scale
                love.graphics.setColor(col)
                love.graphics.draw(ballImage, x, y, rotation, scale, scale, imgW / 2, imgH / 2)
            end
        end
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
    return pick_state ~= STATE.IDLE or bg_state ~= STATE.IDLE
end

function animation.isHovering()
    return pick_state == STATE.HOVERING
end

function animation.isFlying()
    return pick_state == STATE.FLYING
end

function animation.isMerging()
    return bg_state == STATE.MERGING
end

function animation.isDealing()
    return bg_state == STATE.DEALING
end

-- Get table of {box_idx = slot} for coins currently being dealt (for hiding duplicates)
function animation.getDealingSlots()
    if bg_state ~= STATE.DEALING then return {} end

    local slots = {}
    for _, coin_data in ipairs(dealing_coins) do
        -- Only track coins that have landed but aren't done bouncing yet
        if coin_data.landed and not coin_data.done then
            if not slots[coin_data.dest_box_idx] then
                slots[coin_data.dest_box_idx] = {}
            end
            slots[coin_data.dest_box_idx][coin_data.dest_slot] = true
        end
    end
    return slots
end

-- Get list of box indices currently being animated (for hiding static coins during draw)
function animation.getMergingBoxIndices()
    if bg_state ~= STATE.MERGING then return {} end

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

-- Get list of box indices locked by merge (includes waiting — for input blocking)
-- Boxes whose merge hasn't completed yet should not be interacted with
function animation.getMergeLockedBoxes()
    if bg_state ~= STATE.MERGING then return {} end

    local locked = {}
    for _, box_data in ipairs(merge_boxes) do
        if box_data.phase ~= "done" then
            locked[box_data.box_idx] = true
        end
    end
    return locked
end

-- Get coin data of hovering coins (returns array of coin data - strings or tables)
function animation.getHoveringCoins()
    local coins = {}
    for i, hcoin in ipairs(hovering_coins) do
        coins[i] = hcoin.coin
    end
    return coins
end

-- Cancel pick/place animation and reset to idle
function animation.cancel()
    pick_state = STATE.IDLE
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
    if pick_state ~= STATE.HOVERING then
        return {}
    end

    local removed_coins = {}

    -- Remove coins beyond keep_count
    while #hovering_coins > keep_count do
        local removed = table.remove(hovering_coins)
        table.insert(removed_coins, removed.coin)
    end

    -- Recalculate horizontal spread for remaining coins
    local hover_spread = layout.COIN_R * 1.5
    local total_width = (#hovering_coins - 1) * hover_spread
    local start_offset = -total_width / 2
    for i, hcoin in ipairs(hovering_coins) do
        hcoin.offset_x = start_offset + (i - 1) * hover_spread
    end

    return removed_coins
end

return animation
