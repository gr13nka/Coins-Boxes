-- game_dev.lua
-- Dev/test mode: single long box filled with "1" coins for testing merges

local game_dev = {}

local coin_utils = require("coin_utils")

-- Timers
local merge_timer = 0
local error_timer = 0
local error_message = ""

-- GamePlay state
local boxes = {}
local points = 0
local points_per_merge = 10

-- Dev mode specific: 1 box, many rows
local BOX_ROWS = 12  -- Tall box that spans most of screen
local MAX_NUMBER = 50

function game_dev.getState()
    return {
        boxes = boxes,
        BOX_ROWS = BOX_ROWS,
        points = points,
        merge_timer = merge_timer,
        error_timer = error_timer,
        error_message = error_message,
        MAX_NUMBER = MAX_NUMBER,
    }
end

function game_dev.init()
    -- Single box filled with "1" coins
    boxes = { {} }
    points = 0
    merge_timer = 0
    error_timer = 0
    error_message = ""

    -- Fill the box with "1" coins
    for i = 1, BOX_ROWS do
        table.insert(boxes[1], coin_utils.createCoin(1))
    end
end

-- Pick coins of the same number from the top of a box
function game_dev.pick_coin_from_box(box_index, opts)
    opts = opts or {}
    local remove = opts.remove == true

    local box = boxes[box_index]
    if not box or #box == 0 then
        return nil
    end

    local top_idx = #box
    local top_coin = box[top_idx]
    if not top_coin then
        return nil
    end

    local top_number = coin_utils.getCoinNumber(top_coin)
    if not top_number then
        return nil
    end

    -- Count consecutive coins with the same number from top
    local amount = 0
    for i = #box, 1, -1 do
        local coin = box[i]
        local num = coin_utils.getCoinNumber(coin)
        if num == top_number then
            amount = amount + 1
        else
            break
        end
    end

    if amount == 0 then
        return nil
    end

    -- Collect the coins
    local selected_coins = {}
    for i = top_idx, top_idx - amount + 1, -1 do
        table.insert(selected_coins, box[i])
        if remove then
            table.remove(box, i)
        end
    end

    return selected_coins
end

-- Check if coins can be placed in a destination box
function game_dev.can_place(dest_box_index, coins)
    if not coins or #coins == 0 then
        return false, "No coins to place", 0
    end

    local dest_box = boxes[dest_box_index]
    if not dest_box then
        return false, "Invalid box", 0
    end

    local available_slots = BOX_ROWS - #dest_box

    if available_slots <= 0 then
        return false, "Box is full", 0
    end

    if #dest_box == 0 then
        return true, nil, available_slots
    end

    local top_coin = dest_box[#dest_box]
    local top_number = coin_utils.getCoinNumber(top_coin)
    local placing_number = coin_utils.getCoinNumber(coins[1])

    if top_number ~= placing_number then
        return false, "Wrong number!", 0
    end

    return true, nil, available_slots
end

function game_dev.place_coin(dest_box_index, coin)
    local dest_box = boxes[dest_box_index]
    if dest_box then
        table.insert(dest_box, coin)
    end
end

function game_dev.setError(message)
    error_timer = 1.0
    error_message = message or "Invalid!"
end

-- Add coins (refill with "1"s)
function game_dev.add_coins()
    local box = boxes[1]
    local available = BOX_ROWS - #box
    for i = 1, available do
        table.insert(box, coin_utils.createCoin(1))
    end
end

-- Calculate coins to add (for dealing animation)
function game_dev.calculateCoinsToAdd()
    local box = boxes[1]
    local available = BOX_ROWS - #box
    local result = {}

    for i = 1, available do
        local dest_slot = #box + i
        table.insert(result, {
            coin = coin_utils.createCoin(1),
            dest_box_idx = 1,
            dest_slot = dest_slot,
            -- Custom positions for dev mode (centered box)
            dest_x = DEV_BOX_CENTER_X,
            dest_y = DEV_TOP_Y + layout.ROW_STEP * dest_slot
        })
    end

    return result
end

function game_dev.update(dt)
    if merge_timer > 0 then
        merge_timer = merge_timer - dt
    end
    if error_timer > 0 then
        error_timer = error_timer - dt
    end
    return merge_timer
end

-- Layout for dev mode (centered box)
local layout = require("layout")
local DEV_TOP_Y = 200
local DEV_BOX_CENTER_X = layout.VW / 2

-- Get mergeable boxes (2+ same number coins at top)
function game_dev.getMergeableBoxes()
    local mergeable = {}

    for box_index, box in ipairs(boxes) do
        if #box >= 2 then
            -- Check if top coins have the same number
            local top_number = coin_utils.getCoinNumber(box[#box])
            local count = 0

            for i = #box, 1, -1 do
                local num = coin_utils.getCoinNumber(box[i])
                if num == top_number then
                    count = count + 1
                else
                    break
                end
            end

            if count >= 2 then
                local coins_copy = {}
                for i = #box - count + 1, #box do
                    table.insert(coins_copy, box[i])
                end

                -- Progressive merge: each merge adds 1, so final = start + (count - 1)
                local new_number = top_number + (count - 1)
                if new_number > MAX_NUMBER then
                    new_number = MAX_NUMBER
                end

                table.insert(mergeable, {
                    box_idx = box_index,
                    coins = coins_copy,
                    old_number = top_number,
                    new_number = new_number,
                    color = coin_utils.numberToColor(top_number, MAX_NUMBER),
                    new_color = coin_utils.numberToColor(new_number, MAX_NUMBER),
                    -- Custom position for dev mode (centered box)
                    center_x = DEV_BOX_CENTER_X,
                    top_y = DEV_TOP_Y,
                    -- Progressive merge: number increases with each merge step
                    progressive_merge = true,
                    max_number = MAX_NUMBER
                })
            end
        end
    end

    return mergeable
end

-- Execute merge on a single box
function game_dev.executeMergeOnBox(box_idx)
    local box = boxes[box_idx]
    if not box or #box < 2 then return false end

    local top_number = coin_utils.getCoinNumber(box[#box])

    -- Count matching coins from top
    local count = 0
    for i = #box, 1, -1 do
        local num = coin_utils.getCoinNumber(box[i])
        if num == top_number then
            count = count + 1
        else
            break
        end
    end

    if count < 2 then return false end

    -- Remove matching coins
    for _ = 1, count do
        table.remove(box)
    end

    -- Add merged coin (progressive: each merge adds 1)
    local new_number = top_number + (count - 1)
    if new_number > MAX_NUMBER then
        new_number = MAX_NUMBER
    end
    table.insert(box, coin_utils.createCoin(new_number))

    points = points + points_per_merge * new_number * count
    merge_timer = 2

    return true
end

-- Instant merge (for testing without animation)
function game_dev.merge()
    local merged = false

    for box_index, box in ipairs(boxes) do
        if #box >= 2 then
            local top_number = coin_utils.getCoinNumber(box[#box])
            local count = 0

            for i = #box, 1, -1 do
                local num = coin_utils.getCoinNumber(box[i])
                if num == top_number then
                    count = count + 1
                else
                    break
                end
            end

            if count >= 2 then
                for _ = 1, count do
                    table.remove(box)
                end

                -- Progressive: each merge adds 1
                local new_number = top_number + (count - 1)
                if new_number > MAX_NUMBER then
                    new_number = MAX_NUMBER
                end
                table.insert(box, coin_utils.createCoin(new_number))

                points = points + points_per_merge * new_number * count
                merged = true
            end
        end
    end

    if merged then
        merge_timer = 2
    end

    return merged
end

return game_dev
