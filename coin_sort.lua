-- coin_sort.lua
-- Coin Sort game mode where coins have numbers and merge (n+n = n+1)

local coin_sort = {}

local coin_utils = require("coin_utils")
local resources = require("resources")
local bags = require("bags")
local commissions = require("commissions")
local drops = require("drops")

-- Timers
local merge_timer = 0
local error_timer = 0
local error_message = ""

-- GamePlay state
local boxes = {}
local points = 0
local points_per_merge = 10

-- Fixed grid: 15 boxes with 10 slots each
local NUM_BOXES = 15
local BOX_ROWS = 10
local total_merges = 0
local merge_requirement = 2  -- how many coins needed to merge
local max_spawn_number = 1   -- increases with progression
local MAX_NUMBER = 50        -- maximum possible number
local max_coin_reached = 0   -- track highest coin ever created
local game_active = false     -- persists state between tab switches

-- Progression: boxes unlock one-by-one as new coin nominals are reached.
-- Grid positions in unlock order (bottom-left first, then right, then up):
local UNLOCK_ORDER = {11, 12, 13, 14, 15, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1}
local active_box_count = 0   -- how many boxes are currently unlocked
local on_box_unlocked = nil  -- callback(grid_idx) fired when a new box unlocks

-- Balance constants
local MERGE_OUTPUT = 2  -- coins produced per merge (BOX_ROWS coins -> 2 of next type)

-- Weighted type distribution tables (hand-tuned for small type counts)
local WEIGHT_TABLES = {
    [2] = {0.55, 0.45},
    [3] = {0.36, 0.38, 0.26},
    [4] = {0.30, 0.28, 0.22, 0.20},
    [5] = {0.25, 0.23, 0.20, 0.17, 0.15},
}

-- Deal sizing: coins dealt = BOX_ROWS * uniform(DEAL_MIN_FRACTION, DEAL_MAX_FRACTION)
local DEAL_MIN_FRACTION = 0.5
local DEAL_MAX_FRACTION = 0.9

-- Sparse board bonus: when fill% < threshold, lerp deal size toward 2*BOX_ROWS
local SPARSE_THRESHOLD = 0.30  -- below 30% fill, bonus kicks in
local SPARSE_MAX_DEAL_MULT = 2  -- at 0% fill, deal up to 2*BOX_ROWS (same as initial)

-- Probability of skipping a type entirely in a given deal
local SKIP_TYPE_CHANCE = 0.36

-- Default buffer: fraction of columns kept free of new types
local DEFAULT_BUFFER_MIN = 0.30

-- Generate geometric-decay weights for type counts > 5
local function generateWeights(n)
    local decay = 0.82
    local weights = {}
    local total = 0
    for i = 1, n do
        weights[i] = decay ^ (i - 1)
        total = total + weights[i]
    end
    for i = 1, n do
        weights[i] = weights[i] / total
    end
    return weights
end

-- Look up or generate weight table for n types
local function getWeights(n)
    if WEIGHT_TABLES[n] then
        return WEIGHT_TABLES[n]
    end
    local w = generateWeights(n)
    WEIGHT_TABLES[n] = w
    return w
end

-- CDF-based weighted random selection: returns index 1..#weights
local function weightedRandom(weights)
    local r = math.random()
    local cumulative = 0
    for i = 1, #weights do
        cumulative = cumulative + weights[i]
        if r <= cumulative then
            return i
        end
    end
    return #weights
end

-- Returns the grid positions of all currently active boxes, in unlock order.
local function getActiveBoxIndices()
    local result = {}
    for i = 1, active_box_count do
        result[i] = UNLOCK_ORDER[i]
    end
    return result
end

-- Shared deal computation used by init, add_coins, and calculateCoinsToAdd.
-- Returns array of {coin, dest_box_idx, dest_slot}.
-- When is_initial=true: deals 2*BOX_ROWS coins, uniform across 1..max_spawn_number.
-- When is_initial=false: base deal = BOX_ROWS * uniform(0.5, 0.9) with weighted types,
--   boosted toward 2*BOX_ROWS when board fill < SPARSE_THRESHOLD (30%).
-- temp_box_counts is mutated in-place to track slot usage.
local function computeDeal(is_initial, temp_box_counts)
    local active = getActiveBoxIndices()
    local num_active = #active
    local result = {}

    if is_initial then
        -- Initial deal: 2 * active_box_count coins scaled to current grid size
        local total_coins = 2 * active_box_count
        for _ = 1, total_coins do
            -- Find an active box with space
            local box_idx
            local attempts = 0
            repeat
                box_idx = active[math.random(num_active)]
                attempts = attempts + 1
            until (temp_box_counts[box_idx] or 0) < BOX_ROWS or attempts > 100

            if attempts > 100 then
                local all_full = true
                for _, j in ipairs(active) do
                    if (temp_box_counts[j] or 0) < BOX_ROWS then
                        all_full = false
                        break
                    end
                end
                if all_full then break end
            end

            local dest_slot = (temp_box_counts[box_idx] or 0) + 1
            local number = math.random(1, max_spawn_number)
            temp_box_counts[box_idx] = dest_slot

            result[#result + 1] = {
                coin = coin_utils.createCoin(number),
                dest_box_idx = box_idx,
                dest_slot = dest_slot,
            }
        end
    else
        -- Regular deal: variable size with weighted type distribution
        local frac = DEAL_MIN_FRACTION + math.random() * (DEAL_MAX_FRACTION - DEAL_MIN_FRACTION)
        local will_add = math.max(1, math.floor(BOX_ROWS * frac + 0.5))

        -- Sparse board bonus: deal more coins when the board is nearly empty
        local total_coins = 0
        for _, idx in ipairs(active) do
            total_coins = total_coins + (temp_box_counts[idx] or 0)
        end
        local capacity = num_active * BOX_ROWS
        local fill_pct = total_coins / capacity
        if fill_pct < SPARSE_THRESHOLD then
            local sparsity = 1 - (fill_pct / SPARSE_THRESHOLD)  -- 1.0 at empty, 0.0 at threshold
            local max_deal = SPARSE_MAX_DEAL_MULT * BOX_ROWS
            local boosted = math.floor(will_add + (max_deal - will_add) * sparsity + 0.5)
            local available = capacity - total_coins
            will_add = math.min(boosted, available)
        end

        -- Build active weights (skip some types with SKIP_TYPE_CHANCE)
        local active_types = {}
        local active_weights = {}
        local raw_weights = getWeights(max_spawn_number)
        for i = 1, max_spawn_number do
            if max_spawn_number == 1 or math.random() >= SKIP_TYPE_CHANCE then
                active_types[#active_types + 1] = i
                active_weights[#active_weights + 1] = raw_weights[i]
            end
        end
        -- Guarantee at least one type
        if #active_types == 0 then
            active_types[1] = 1
            active_weights[1] = 1.0
        end
        -- Renormalize
        local total_w = 0
        for i = 1, #active_weights do
            total_w = total_w + active_weights[i]
        end
        for i = 1, #active_weights do
            active_weights[i] = active_weights[i] / total_w
        end

        for _ = 1, will_add do
            local box_idx
            local attempts = 0
            repeat
                box_idx = active[math.random(num_active)]
                attempts = attempts + 1
            until (temp_box_counts[box_idx] or 0) < BOX_ROWS or attempts > 100

            if attempts > 100 then
                local all_full = true
                for _, j in ipairs(active) do
                    if (temp_box_counts[j] or 0) < BOX_ROWS then
                        all_full = false
                        break
                    end
                end
                if all_full then break end
            end

            local dest_slot = (temp_box_counts[box_idx] or 0) + 1
            local type_idx = weightedRandom(active_weights)
            local number = active_types[type_idx]
            temp_box_counts[box_idx] = dest_slot

            result[#result + 1] = {
                coin = coin_utils.createCoin(number),
                dest_box_idx = box_idx,
                dest_slot = dest_slot,
            }
        end
    end

    return result
end

function coin_sort.getState()
    return {
        boxes = boxes,
        BOX_ROWS = BOX_ROWS,
        NUM_BOXES = active_box_count,
        points = points,
        merge_timer = merge_timer,
        error_timer = error_timer,
        error_message = error_message,
        total_merges = total_merges,
        merge_requirement = merge_requirement,
        max_spawn_number = max_spawn_number,
        MAX_NUMBER = MAX_NUMBER,
        max_coin_reached = max_coin_reached,
        commissions = commissions.getActive(),
    }
end

function coin_sort.getNumColumns()
    return NUM_BOXES
end

function coin_sort.isActive()
    return game_active
end

function coin_sort.deactivate()
    game_active = false
end

-- Persist highest coin ever created and unlock new boxes as nominals are reached.
local function setMaxCoinReached(n)
    if n > max_coin_reached then
        max_coin_reached = n
        local prog = require("progression")
        local d = prog.getUpgradesData()
        d.max_coin_reached = n
        prog.setUpgradesData(d)
        prog.save()

        -- Unlock boxes: each new coin level unlocks one more box (up to 15).
        -- May unlock multiple boxes at once if coin levels are skipped.
        local new_count = math.min(NUM_BOXES, 4 + math.max(0, n - 1))
        if new_count > active_box_count then
            for i = active_box_count + 1, new_count do
                local grid_idx = UNLOCK_ORDER[i]
                boxes[grid_idx] = {}
                if on_box_unlocked then
                    on_box_unlocked(grid_idx)
                end
            end
            active_box_count = new_count
        end
    end
end

-- Update progression based on total merges.
-- Buffer cap limits max_spawn_number so at least DEFAULT_BUFFER_MIN columns are free.
local function updateProgression()
    local cols = active_box_count
    -- Default cap: keep at least DEFAULT_BUFFER_MIN fraction of columns as buffer
    local default_cap = math.floor(cols * (1 - DEFAULT_BUFFER_MIN))
    local type_cap = default_cap
    -- Hard cap: types must be < cols (at least 1 buffer column)
    if type_cap >= cols then
        type_cap = cols - 1
    end
    -- Progression cap: starts at 3, +1 per 10 merges, max 10
    local progression_cap = math.min(10, 3 + math.floor(total_merges / 10))
    max_spawn_number = math.min(progression_cap, type_cap)
    if max_spawn_number < 1 then
        max_spawn_number = 1
    end
end

function coin_sort.init()
    -- Load historical max coin
    local prog = require("progression")
    local d = prog.getUpgradesData()
    max_coin_reached = d.max_coin_reached or 0

    -- Try to restore saved game
    local saved = prog.getCoinSortData()
    if saved.game_active and saved.boxes then
        boxes = saved.boxes
        points = saved.points or 0
        total_merges = saved.total_merges or 0
        max_spawn_number = saved.max_spawn_number or 1
        active_box_count = saved.active_box_count or 4
        game_active = true
        merge_timer = 0
        error_timer = 0
        error_message = ""
        commissions.generate(max_coin_reached)
        return
    end

    -- Determine how many boxes to unlock based on progression
    -- Start at 4, unlock 1 per new coin nominal (coin 2 → 5 boxes, etc.)
    active_box_count = math.min(NUM_BOXES, 4 + math.max(0, max_coin_reached - 1))

    -- Sparse boxes table: only active grid positions have entries
    boxes = {}
    for i = 1, active_box_count do
        boxes[UNLOCK_ORDER[i]] = {}
    end

    points = 0
    merge_timer = 0
    error_timer = 0
    error_message = ""
    total_merges = 0
    max_spawn_number = 2  -- Initial deal uses types 1-2

    if max_coin_reached > 2 then
        max_spawn_number = math.max(max_spawn_number, max_coin_reached - 2)
    end

    -- Use computeDeal for initial fill (temp_counts starts empty; nils treated as 0)
    local temp_counts = {}
    local deal = computeDeal(true, temp_counts)
    for _, entry in ipairs(deal) do
        table.insert(boxes[entry.dest_box_idx], entry.coin)
    end

    game_active = true

    -- Generate commissions for this CS session
    commissions.generate(max_coin_reached)
end

-- Pick coins of the same number from the top of a box
function coin_sort.pick_coin_from_box(box_index, opts)
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
function coin_sort.can_place(dest_box_index, coins)
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
function coin_sort.place_coin(dest_box_index, coin)
    local dest_box = boxes[dest_box_index]
    if dest_box then
        table.insert(dest_box, coin)
    end
end

-- Set error state for invalid placement feedback
function coin_sort.setError(message)
    error_timer = 1.0  -- 1 second error display
    error_message = message or "Invalid!"
end

-- Add new coins to boxes (uses computeDeal internally)
function coin_sort.add_coins()
    local temp_counts = {}
    for _, idx in ipairs(getActiveBoxIndices()) do
        temp_counts[idx] = #boxes[idx]
    end
    local deal = computeDeal(false, temp_counts)
    for _, entry in ipairs(deal) do
        table.insert(boxes[entry.dest_box_idx], entry.coin)
    end
end

-- Calculate what coins would be added (for dealing animation)
-- Returns: array of {coin={number=N}, dest_box_idx=N, dest_slot=N}
function coin_sort.calculateCoinsToAdd()
    local temp_counts = {}
    for _, idx in ipairs(getActiveBoxIndices()) do
        temp_counts[idx] = #boxes[idx]
    end
    return computeDeal(false, temp_counts)
end

-- Deal coins from a bag. Consumes one bag and returns deal data for animation.
-- Returns nil if no bags available.
function coin_sort.dealFromBag()
    local coin_count = bags.useBag()
    if not coin_count then return nil end

    local temp_counts = {}
    for _, idx in ipairs(getActiveBoxIndices()) do
        temp_counts[idx] = #boxes[idx]
    end
    -- Use computeDeal but we already consumed the bag
    return computeDeal(false, temp_counts)
end

-- Check if player has bags available for dealing
function coin_sort.hasBags()
    return bags.getTotalAvailable() > 0
end

function coin_sort.update(dt)
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
function coin_sort.getMergeableBoxes()
    local mergeable = {}

    for _, box_index in ipairs(getActiveBoxIndices()) do
        local box = boxes[box_index]
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
function coin_sort.executeMergeOnBox(box_idx)
    local box = boxes[box_idx]
    if not box or #box ~= BOX_ROWS then return false end

    local first_number = coin_utils.getCoinNumber(box[1])

    -- Remove all coins
    local coin_count = #box
    for _ = 1, coin_count do
        table.remove(box)
    end

    -- Add MERGE_OUTPUT coins of the next number
    local new_number = first_number + 1
    if new_number > MAX_NUMBER then
        new_number = MAX_NUMBER
    end
    for _ = 1, MERGE_OUTPUT do
        table.insert(box, coin_utils.createCoin(new_number))
    end

    -- Track highest coin ever created
    setMaxCoinReached(new_number)

    -- Award points
    points = points + points_per_merge * new_number * coin_count

    -- Award resources (Fuel/Stars)
    local gained = resources.onCoinMerge(new_number)

    -- Track commission progress
    commissions.onMerge(new_number, gained)

    -- Refresh commissions if all completed
    local commissions_refreshed = false
    if commissions.allCompleted() then
      commissions.collectRewards()
      commissions.generate(max_coin_reached)
      commissions_refreshed = true
    end

    -- Roll variable drops
    local drop_results = drops.rollMergeDrops(new_number)

    -- Update progression
    total_merges = total_merges + 1
    updateProgression()

    -- Show "Merged!" message
    merge_timer = 2

    return true, gained, drop_results, commissions_refreshed
end

-- 2048-style merge: All coins in a full box become MERGE_OUTPUT coins of (number+1)
-- Only merges when box is full (BOX_ROWS coins) and all coins have same number
function coin_sort.merge()
    local merged = false

    for _, box_index in ipairs(getActiveBoxIndices()) do
        local box = boxes[box_index]
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
                local new_number = first_number + 1
                if new_number > MAX_NUMBER then
                    new_number = MAX_NUMBER
                end

                -- Remove all coins from the box
                local coin_count = #box
                for _ = 1, coin_count do
                    table.remove(box)
                end

                -- Add MERGE_OUTPUT coins of the next number
                for _ = 1, MERGE_OUTPUT do
                    table.insert(box, coin_utils.createCoin(new_number))
                end

                -- Track highest coin ever created
                setMaxCoinReached(new_number)

                -- Award points based on the new number and how many coins merged
                points = points + points_per_merge * new_number * coin_count

                -- Award resources
                local gained = resources.onCoinMerge(new_number)

                -- Track commission progress
                commissions.onMerge(new_number, gained)

                -- Refresh commissions if all completed
                if commissions.allCompleted() then
                  commissions.collectRewards()
                  commissions.generate(max_coin_reached)
                end

                -- Roll variable drops
                drops.rollMergeDrops(new_number)

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

-- Auto Sort: group coins by number, each column gets only one number type.
-- Higher numbers get dedicated columns first. No coins are ever lost.
-- If columns run out, remaining coins fill leftover space.
-- Clears all boxes, returns coins_to_deal array: {coin, dest_box_idx, dest_slot}
function coin_sort.autoSort()
    local active = getActiveBoxIndices()
    local num_active = #active

    -- Group coins by number (from active boxes only)
    local groups = {}  -- number -> list of coins
    local numbers = {} -- ordered list of unique numbers
    for _, grid_idx in ipairs(active) do
        for _, coin in ipairs(boxes[grid_idx]) do
            local num = coin_utils.getCoinNumber(coin)
            if not groups[num] then
                groups[num] = {}
                numbers[#numbers + 1] = num
            end
            groups[num][#groups[num] + 1] = coin
        end
    end

    -- Sort by number descending (higher numbers get priority for clean columns)
    table.sort(numbers, function(a, b) return a > b end)

    -- Clear all active boxes
    for _, grid_idx in ipairs(active) do
        boxes[grid_idx] = {}
    end

    -- Track how many slots each grid position has used
    local col_counts = {}

    -- Pass 1: assign each number group to dedicated columns (by active order)
    local result = {}
    local leftover = {} -- coins that didn't fit in dedicated columns
    local col_pos = 1   -- position in active array
    for _, num in ipairs(numbers) do
        local coins = groups[num]
        if col_pos > num_active then
            -- No more dedicated columns; save all for leftover pass
            for _, coin in ipairs(coins) do
                leftover[#leftover + 1] = coin
            end
        else
            for _, coin in ipairs(coins) do
                if col_pos > num_active then
                    leftover[#leftover + 1] = coin
                else
                    local grid_idx = active[col_pos]
                    if (col_counts[grid_idx] or 0) >= BOX_ROWS then
                        col_pos = col_pos + 1
                        if col_pos > num_active then
                            leftover[#leftover + 1] = coin
                        else
                            grid_idx = active[col_pos]
                            col_counts[grid_idx] = (col_counts[grid_idx] or 0) + 1
                            result[#result + 1] = {
                                coin = coin,
                                dest_box_idx = grid_idx,
                                dest_slot = col_counts[grid_idx],
                            }
                        end
                    else
                        col_counts[grid_idx] = (col_counts[grid_idx] or 0) + 1
                        result[#result + 1] = {
                            coin = coin,
                            dest_box_idx = grid_idx,
                            dest_slot = col_counts[grid_idx],
                        }
                    end
                end
            end
            -- Next number starts a new column
            col_pos = col_pos + 1
        end
    end

    -- Pass 2: stuff leftover coins into any remaining space
    if #leftover > 0 then
        local li = 1
        for _, grid_idx in ipairs(active) do
            while (col_counts[grid_idx] or 0) < BOX_ROWS and li <= #leftover do
                col_counts[grid_idx] = (col_counts[grid_idx] or 0) + 1
                result[#result + 1] = {
                    coin = leftover[li],
                    dest_box_idx = grid_idx,
                    dest_slot = col_counts[grid_idx],
                }
                li = li + 1
            end
            if li > #leftover then break end
        end
    end

    return result
end

-- Clear Column: remove all coins from a column.
-- Returns array of removed coins (for particle effects).
function coin_sort.clearColumn(col_idx)
    local box = boxes[col_idx]
    if not box then return {} end
    local removed = {}
    for i = 1, #box do
        removed[i] = box[i]
    end
    boxes[col_idx] = {}
    return removed
end

-- Check if the game is over: all active boxes full AND no merges possible.
-- Player can always press "Add Coins" when empty slots remain, so only
-- a completely full board with no mergeable boxes is a true loss.
function coin_sort.isGameOver()
    -- If any active box has empty space, player can still add coins
    for _, idx in ipairs(getActiveBoxIndices()) do
        if #boxes[idx] < BOX_ROWS then
            return false
        end
    end

    -- All active boxes are full — check if any merge is available
    if #coin_sort.getMergeableBoxes() > 0 then return false end

    -- All full, no merges — game over
    return true
end

-- Register a callback fired when a new box unlocks mid-session.
-- fn(grid_idx) where grid_idx is the grid position (1-15) of the new box.
function coin_sort.setBoxUnlockedCallback(fn)
    on_box_unlocked = fn
end

-- Returns how many boxes are currently active.
function coin_sort.getActiveBoxCount()
    return active_box_count
end

function coin_sort.save()
    local prog = require("progression")
    prog.setCoinSortData({
        boxes = boxes,
        points = points,
        total_merges = total_merges,
        max_spawn_number = max_spawn_number,
        max_coin_reached = max_coin_reached,
        game_active = game_active,
        active_box_count = active_box_count,
    })
    bags.sync()
    resources.sync()
    drops.sync()
    prog.save()
end

function coin_sort.clearSave()
    local prog = require("progression")
    prog.setCoinSortData({})
end

return coin_sort
