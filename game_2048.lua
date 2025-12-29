-- game_2048.lua
-- 2048-style game mode where coins have numbers and merge (n+n = n+1)

local game_2048 = {}

local coin_utils = require("coin_utils")

-- Timers
local merge_timer = 0
local error_timer = 0
local error_message = ""

-- GamePlay state
local boxes = {}
local points = 0
local points_per_merge = 10

-- 2048-specific state
local BOX_ROWS = 3
local total_merges = 0
local merge_requirement = 2  -- how many coins needed to merge
local max_spawn_number = 1   -- increases with progression
local MAX_NUMBER = 50        -- maximum possible number

function game_2048.getState()
    return {
        boxes = boxes,
        BOX_ROWS = BOX_ROWS,
        points = points,
        merge_timer = merge_timer,
        error_timer = error_timer,
        error_message = error_message,
        total_merges = total_merges,
        merge_requirement = merge_requirement,
        max_spawn_number = max_spawn_number,
        MAX_NUMBER = MAX_NUMBER,
    }
end

-- Update progression based on total merges
local function updateProgression()
    -- Start at 3, then every 10 merges increase max spawn number (capped at 10)
    max_spawn_number = 3 + math.floor(total_merges / 10)
    if max_spawn_number > 10 then
        max_spawn_number = 10
    end
end

function game_2048.init()
    boxes = { {}, {}, {}, {}, {} }
    points = 0
    merge_timer = 0
    error_timer = 0
    error_message = ""
    total_merges = 0
    max_spawn_number = 3  -- Start with 1-3 to match initial coin variety

    -- Initialize with coins numbered 1-3
    local total_coins = #boxes * (BOX_ROWS - 1)

    for i = 1, total_coins do
        ::box::
        local box = math.random(#boxes)
        if #boxes[box] >= BOX_ROWS then
            goto box
        end

        -- Starting coins are 1, 2, or 3
        local number = math.random(1, 3)
        table.insert(boxes[box], coin_utils.createCoin(number))
    end
end

-- Pick coins of the same number from the top of a box
function game_2048.pick_coin_from_box(box_index, opts)
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
-- Returns: success (bool), error_message (string or nil), available_slots (number)
function game_2048.can_place(dest_box_index, coins)
    if not coins or #coins == 0 then
        return false, "No coins to place", 0
    end

    local dest_box = boxes[dest_box_index]
    if not dest_box then
        return false, "Invalid box", 0
    end

    -- Calculate available slots
    local available_slots = BOX_ROWS - #dest_box

    -- If box is full, can't place anything
    if available_slots <= 0 then
        return false, "Box is full", 0
    end

    -- If box is empty, can always place (up to available slots)
    if #dest_box == 0 then
        return true, nil, available_slots
    end

    -- Check if top coin has the same number
    local top_coin = dest_box[#dest_box]
    local top_number = coin_utils.getCoinNumber(top_coin)
    local placing_number = coin_utils.getCoinNumber(coins[1])

    if top_number ~= placing_number then
        return false, "Wrong number!", 0
    end

    return true, nil, available_slots
end

-- Place coins into a box (used during animation callbacks)
function game_2048.place_coin(dest_box_index, coin)
    local dest_box = boxes[dest_box_index]
    if dest_box then
        table.insert(dest_box, coin)
    end
end

-- Set error state for invalid placement feedback
function game_2048.setError(message)
    error_timer = 1.0  -- 1 second error display
    error_message = message or "Invalid!"
end

-- Add new coins to boxes
function game_2048.add_coins()
    -- Count current coins
    local total_coins = 0
    for _, box in ipairs(boxes) do
        total_coins = total_coins + #box
    end

    -- Calculate how many to add
    local max_possible = #boxes * BOX_ROWS
    local will_add = math.floor(((max_possible - total_coins) / 2) + 0.5)
    if will_add < 1 then will_add = 1 end

    for i = 1, will_add do
        ::box::
        local box_idx = math.random(#boxes)
        if #boxes[box_idx] >= BOX_ROWS then
            -- Check if all boxes are full
            local all_full = true
            for _, box in ipairs(boxes) do
                if #box < BOX_ROWS then
                    all_full = false
                    break
                end
            end
            if all_full then
                break
            end
            goto box
        end

        -- Spawn a number in range [1, max_spawn_number]
        local number = math.random(1, max_spawn_number)
        table.insert(boxes[box_idx], coin_utils.createCoin(number))
    end
end

-- Calculate what coins would be added (for dealing animation)
-- Returns: array of {coin={number=N}, dest_box_idx=N, dest_slot=N}
function game_2048.calculateCoinsToAdd()
    -- Count current coins
    local total_coins = 0
    for _, box in ipairs(boxes) do
        total_coins = total_coins + #box
    end

    -- Calculate how many to add
    local max_possible = #boxes * BOX_ROWS
    local will_add = math.floor(((max_possible - total_coins) / 2) + 0.5)
    if will_add < 1 then will_add = 1 end

    local result = {}
    -- Track temporary box counts
    local temp_box_counts = {}
    for i, box in ipairs(boxes) do
        temp_box_counts[i] = #box
    end

    for i = 1, will_add do
        -- Find valid box
        local box_idx
        local attempts = 0
        repeat
            box_idx = math.random(#boxes)
            attempts = attempts + 1
            if attempts > 100 then break end
        until temp_box_counts[box_idx] < BOX_ROWS

        -- Check if all boxes are full
        if attempts > 100 then
            local all_full = true
            for j = 1, #boxes do
                if temp_box_counts[j] < BOX_ROWS then
                    all_full = false
                    break
                end
            end
            if all_full then break end
        end

        -- Calculate slot (1-indexed from bottom)
        local dest_slot = temp_box_counts[box_idx] + 1

        -- Spawn a number in range [1, max_spawn_number]
        local number = math.random(1, max_spawn_number)

        -- Update tracking
        temp_box_counts[box_idx] = temp_box_counts[box_idx] + 1

        table.insert(result, {
            coin = coin_utils.createCoin(number),
            dest_box_idx = box_idx,
            dest_slot = dest_slot
        })
    end

    return result
end

function game_2048.update(dt)
    if merge_timer > 0 then
        merge_timer = merge_timer - dt
    end
    if error_timer > 0 then
        error_timer = error_timer - dt
    end
    return merge_timer
end

-- Get list of boxes that can be merged (for animation)
-- Returns: array of {box_idx, coins, old_number, new_number, color}
function game_2048.getMergeableBoxes()
    local mergeable = {}

    for box_index, box in ipairs(boxes) do
        -- Only check full boxes
        if #box == BOX_ROWS then
            local first_number = coin_utils.getCoinNumber(box[1])
            local all_same = true

            for i = 2, #box do
                local num = coin_utils.getCoinNumber(box[i])
                if num ~= first_number then
                    all_same = false
                    break
                end
            end

            if all_same then
                local new_number = first_number + 1
                if new_number > MAX_NUMBER then
                    new_number = MAX_NUMBER
                end
                table.insert(mergeable, {
                    box_idx = box_index,
                    coins = {unpack(box)},  -- copy of coins
                    old_number = first_number,
                    new_number = new_number,
                    color = coin_utils.numberToColor(first_number, MAX_NUMBER),
                    new_color = coin_utils.numberToColor(new_number, MAX_NUMBER)
                })
            end
        end
    end

    return mergeable
end

-- Execute merge on a single box (used by animation callback)
function game_2048.executeMergeOnBox(box_idx)
    local box = boxes[box_idx]
    if not box or #box ~= BOX_ROWS then return false end

    local first_number = coin_utils.getCoinNumber(box[1])

    -- Remove all coins
    local coin_count = #box
    for _ = 1, coin_count do
        table.remove(box)
    end

    -- Add merged coin
    local new_number = first_number + 1
    if new_number > MAX_NUMBER then
        new_number = MAX_NUMBER
    end
    table.insert(box, coin_utils.createCoin(new_number))

    -- Award points
    points = points + points_per_merge * new_number * coin_count

    -- Update progression
    total_merges = total_merges + 1
    updateProgression()

    -- Show "Merged!" message
    merge_timer = 2

    return true
end

-- 2048-style merge: All coins in a full box become 1 coin of (number+1)
-- Only merges when box is full (BOX_ROWS coins) and all coins have same number
function game_2048.merge()
    local merged = false

    for box_index, box in ipairs(boxes) do
        -- Only merge if box is full
        if #box == BOX_ROWS then
            -- Check if all coins have the same number
            local first_number = coin_utils.getCoinNumber(box[1])
            local all_same = true

            for i = 2, #box do
                local num = coin_utils.getCoinNumber(box[i])
                if num ~= first_number then
                    all_same = false
                    break
                end
            end

            if all_same then
                -- All coins have the same number - merge them all into one
                local new_number = first_number + 1
                if new_number > MAX_NUMBER then
                    new_number = MAX_NUMBER  -- cap at max
                end

                -- Remove all coins from the box
                local coin_count = #box
                for _ = 1, coin_count do
                    table.remove(box)
                end

                -- Add one merged coin
                table.insert(box, coin_utils.createCoin(new_number))

                -- Award points based on the new number and how many coins merged
                points = points + points_per_merge * new_number * coin_count

                -- Update progression
                total_merges = total_merges + 1
                updateProgression()

                merged = true
            end
        end
    end

    if merged then
        merge_timer = 2
    end

    return merged
end

return game_2048
