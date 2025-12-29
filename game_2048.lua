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
-- Returns: success (bool), error_message (string or nil)
function game_2048.can_place(dest_box_index, coins)
    if not coins or #coins == 0 then
        return false, "No coins to place"
    end

    local dest_box = boxes[dest_box_index]
    if not dest_box then
        return false, "Invalid box"
    end

    -- Check capacity
    if #dest_box + #coins > BOX_ROWS then
        return false, "Box is full"
    end

    -- If box is empty, can always place
    if #dest_box == 0 then
        return true, nil
    end

    -- Check if top coin has the same number
    local top_coin = dest_box[#dest_box]
    local top_number = coin_utils.getCoinNumber(top_coin)
    local placing_number = coin_utils.getCoinNumber(coins[1])

    if top_number ~= placing_number then
        return false, "Wrong number!"
    end

    return true, nil
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

function game_2048.update(dt)
    if merge_timer > 0 then
        merge_timer = merge_timer - dt
    end
    if error_timer > 0 then
        error_timer = error_timer - dt
    end
    return merge_timer
end

-- 2048-style merge: N coins of same number become 1 coin of (number+1)
function game_2048.merge()
    local merged = false

    for box_index, box in ipairs(boxes) do
        -- Keep checking until no more merges in this box
        local keep_checking = true
        while keep_checking do
            keep_checking = false

            if #box >= merge_requirement then
                -- Check from bottom for consecutive same-number coins
                local count = 1
                local current_number = nil

                for i = 1, #box do
                    local coin = box[i]
                    local num = coin_utils.getCoinNumber(coin)

                    if current_number == nil then
                        current_number = num
                        count = 1
                    elseif num == current_number then
                        count = count + 1
                    else
                        -- Reset counter for new number
                        current_number = num
                        count = 1
                    end

                    -- Check if we have enough to merge
                    if count >= merge_requirement then
                        -- Found a merge! Remove the coins and add one with number+1
                        local new_number = current_number + 1
                        if new_number > MAX_NUMBER then
                            new_number = MAX_NUMBER  -- cap at max
                        end

                        -- Remove merge_requirement coins starting from position (i - merge_requirement + 1)
                        local start_pos = i - merge_requirement + 1
                        for _ = 1, merge_requirement do
                            table.remove(box, start_pos)
                        end

                        -- Insert the new merged coin at start_pos
                        table.insert(box, start_pos, coin_utils.createCoin(new_number))

                        -- Award points based on the new number
                        points = points + points_per_merge * new_number * merge_requirement

                        -- Update progression
                        total_merges = total_merges + 1
                        updateProgression()

                        merged = true
                        keep_checking = true  -- Check again for chain merges
                        break  -- Restart the scan for this box
                    end
                end
            end
        end
    end

    if merged then
        merge_timer = 2
    end

    return merged
end

return game_2048
