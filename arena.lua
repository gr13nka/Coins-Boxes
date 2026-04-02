-- arena.lua
-- Merge Arena game state and logic. Pure data module (no drawing).
-- 7x8 grid with boxes, sealed items, generators. Dispenser queue + 8-slot stash.

local progression = require("progression")
local arena_chains = require("arena_chains")
local resources = require("resources")
local arena_orders = require("arena_orders")
local bags = require("bags")
local drops = require("drops")

local arena = {}

-- Constants
local GRID_COLS = 7
local GRID_ROWS = 8
local GRID_SIZE = GRID_COLS * GRID_ROWS  -- 56
local STASH_SIZE = 8

-- State
local grid = {}            -- 56 cells (see cell states below)
local stash = {}           -- 8 slots, each nil or {chain_id, level}
local dispenser_queue = {} -- FIFO array of {chain_id, level}
local xp = 0
local tutorial_step = 1    -- 1-18 or "done"
local initialized = false

-- Hardcoded tutorial generator drops (used instead of random during tutorial)
local TUTORIAL_GEN_DROPS = {
  {chain_id = "Da", level = 1},  -- first gen tap (step 8/9): Egg
  {chain_id = "Me", level = 1},  -- second gen tap (step 16/17): Smoked Meat
}
local tutorial_gen_index = 0

-- Shuffle bag: contains items needed for current level's orders, given in random order
local shuffle_bag = {}  -- array of {chain_id, level}, consumed from front

function arena.isGeneratorUnlocked(chain_id)
  local st = require("skill_tree")
  return st.isGeneratorUnlocked(chain_id)
end

function arena.getGeneratorUnlockNode(chain_id)
  local st = require("skill_tree")
  return st.getGeneratorUnlockNode(chain_id)
end

-- Generator charge system: generators have limited charges, recharge over time
local GEN_CHARGE_TABLE = {
  [0] = 10,  -- at generator threshold (e.g., Ch4, Ki7)
  [1] = 11,
  [2] = 12,
  [3] = 13,
  [4] = 13,
  [5] = 14,
  [6] = 14,
}
local GEN_RECHARGE_TIME = 600  -- 10 minutes for full recharge (all charges at once)

local function getMaxCharges(chain_id, level)
  local threshold = arena_chains.getGeneratorThreshold(chain_id)
  if not threshold then return 0 end
  local offset = level - threshold
  if offset < 0 then return 0 end
  local base = GEN_CHARGE_TABLE[offset] or GEN_CHARGE_TABLE[6]
  local st = require("skill_tree")
  return base + st.getGenChargeBonus()
end

-- Cell states:
--   nil                                     = empty
--   {state="box", chain_id=X, level=Y}      = closed box (contents hidden)
--   {state="sealed", chain_id=X, level=Y}   = visible but immovable
--   {chain_id=X, level=Y}                   = normal item (generator if above threshold)

-- Initial board: what each cell contains (all as boxes unless overridden)
local INITIAL_CONTENTS = {
  -- row 1
  "He3", "Ch3", "Bl5", "Ch3", "Cu2", "Bl2", "Cu3",
  -- row 2
  "Ki2", "He3", "Ki2", "Cu1", "Ch3", "Bl1", "Ch2",
  -- row 3
  "Ch5", "Ki1", "Ta2", "Ch1", "Cu2", "Bl3", "Cu4",
  -- row 4
  "He2", "Cu3", "Cu1", "Da1", "Bl2", "He3", "Ch5",
  -- row 5
  "Ta3", "He2", "Ta1", ".", ".", "He4", "Ki2",
  -- row 6
  "He2", "Ch2", "Da2", "Me3", "Ch3", "Ta2", "He4",
  -- row 7
  "He3", "Ki2", "Bl2", "Da2", "Me1", "He4", "Ch4",
  -- row 8
  "Ch3", "Ki2", "Ch4", "Cu2", "Da1", "He3", "Ki3",
}

-- Cells that start as sealed (visible but locked) instead of boxes
local INITIAL_SEALED = {
  [24] = true, [25] = true, [26] = true,  -- row4: Cu1, Da1, Bl2
  [30] = true, [31] = true, [34] = true,  -- row5: He2, Ta1, He4
  [38] = true, [39] = true, [40] = true,  -- row6: Da2, Me3, Ch3
}

-- Cells that are genuinely empty (not boxes)
local INITIAL_EMPTY = {
  [32] = true, [33] = true,  -- row5 cols 4,5
}

-- === COORDINATE HELPERS ===

function arena.toIndex(col, row)
  if col < 1 or col > GRID_COLS or row < 1 or row > GRID_ROWS then return nil end
  return (row - 1) * GRID_COLS + col
end

function arena.toColRow(index)
  if index < 1 or index > GRID_SIZE then return nil, nil end
  local col = ((index - 1) % GRID_COLS) + 1
  local row = math.floor((index - 1) / GRID_COLS) + 1
  return col, row
end

function arena.getAdjacent(index)
  local col, row = arena.toColRow(index)
  if not col then return {} end
  local adj = {}
  if row > 1 then adj[#adj + 1] = arena.toIndex(col, row - 1) end
  if row < GRID_ROWS then adj[#adj + 1] = arena.toIndex(col, row + 1) end
  if col > 1 then adj[#adj + 1] = arena.toIndex(col - 1, row) end
  if col < GRID_COLS then adj[#adj + 1] = arena.toIndex(col + 1, row) end
  return adj
end

-- === CELL QUERIES ===

function arena.getCell(index)
  return grid[index]
end

function arena.isEmpty(index)
  return index >= 1 and index <= GRID_SIZE and grid[index] == nil
end

function arena.isBox(index)
  local cell = grid[index]
  return cell ~= nil and cell.state == "box"
end

function arena.isSealed(index)
  local cell = grid[index]
  return cell ~= nil and cell.state == "sealed"
end

function arena.isItem(index)
  local cell = grid[index]
  return cell ~= nil and cell.chain_id ~= nil and cell.state == nil
end

function arena.isGeneratorCell(index)
  local cell = grid[index]
  if not cell or cell.state then return false end
  return arena_chains.isGenerator(cell.chain_id, cell.level)
end

function arena.getGeneratorCharges(index)
  local cell = grid[index]
  if not cell or cell.state then return nil, nil end
  if not arena_chains.isGenerator(cell.chain_id, cell.level) then return nil, nil end
  local max_ch = getMaxCharges(cell.chain_id, cell.level)
  local ch = cell.charges
  if ch == nil then ch = max_ch end
  return ch, max_ch
end

function arena.isGeneratorDepleted(index)
  local ch = arena.getGeneratorCharges(index)
  return ch ~= nil and ch <= 0
end

function arena.getRechargeProgress(index)
  local cell = grid[index]
  if not cell or not cell.recharge_timer then return nil, nil end
  local st = require("skill_tree")
  return cell.recharge_timer, st.getGenRechargeTime()
end

-- Find nearest empty cell via BFS from a starting index
function arena.findNearestEmpty(from_index)
  local visited = {[from_index] = true}
  local queue = {from_index}
  local head = 1
  while head <= #queue do
    local current = queue[head]
    head = head + 1
    for _, adj in ipairs(arena.getAdjacent(current)) do
      if not visited[adj] then
        visited[adj] = true
        if not grid[adj] then
          return adj
        end
        queue[#queue + 1] = adj
      end
    end
  end
  -- Fallback: any empty cell
  for i = 1, GRID_SIZE do
    if not grid[i] then return i end
  end
  return nil
end

function arena.countEmpty()
  local count = 0
  for i = 1, GRID_SIZE do
    if not grid[i] then count = count + 1 end
  end
  return count
end

-- === GRID MUTATION ===

function arena.placeItem(index, chain_id, level)
  if index < 1 or index > GRID_SIZE then return false end
  if grid[index] then return false end
  grid[index] = {chain_id = chain_id, level = level}
  return true
end

function arena.removeItem(index)
  local cell = grid[index]
  if not cell or cell.state then return nil end
  grid[index] = nil
  return cell
end

function arena.moveItem(from_index, to_index)
  local cell = grid[from_index]
  if not cell or cell.state then return false end
  if to_index < 1 or to_index > GRID_SIZE then return false end
  if grid[to_index] then return false end
  grid[to_index] = cell
  grid[from_index] = nil
  arena.save()
  return true
end

-- === MERGE LOGIC ===

function arena.canMerge(from_index, to_index)
  local source = grid[from_index]
  local target = grid[to_index]
  if not source or source.state then return false end
  if not target then return false end
  if target.state and target.state ~= "sealed" then return false end
  if source.chain_id ~= target.chain_id then return false end
  if source.level ~= target.level then return false end
  local max_lvl = arena_chains.getMaxLevel(source.chain_id)
  if source.level >= max_lvl then return false end
  return true
end

function arena.executeMerge(from_index, to_index)
  if not arena.canMerge(from_index, to_index) then return nil end

  local source = grid[from_index]
  local target = grid[to_index]
  local was_sealed = target.state == "sealed"
  local new_level = source.level + 1
  local chain_id = source.chain_id

  grid[from_index] = nil
  local new_cell = {chain_id = chain_id, level = new_level}
  local is_gen = arena_chains.isGenerator(chain_id, new_level)
  if is_gen then
    new_cell.charges = getMaxCharges(chain_id, new_level)
  end
  grid[to_index] = new_cell

  local revealed = arena.revealAdjacentBoxes(to_index)
  arena.save()

  local is_locked = is_gen and not arena.isGeneratorUnlocked(chain_id)
  return {
    index = to_index,
    chain_id = chain_id,
    level = new_level,
    was_sealed = was_sealed,
    is_generator = is_gen,
    is_locked = is_locked,
    charges = new_cell.charges,
    max_charges = new_cell.charges,
    revealed = revealed,
  }
end

function arena.revealAdjacentBoxes(index)
  local revealed = {}
  for _, adj in ipairs(arena.getAdjacent(index)) do
    local cell = grid[adj]
    if cell and cell.state == "box" then
      grid[adj] = {state = "sealed", chain_id = cell.chain_id, level = cell.level}
      revealed[#revealed + 1] = adj
    end
  end
  return revealed
end

-- === GENERATOR MECHANICS ===

function arena.isGeneratorLocked(index)
  local cell = grid[index]
  if not cell or cell.state then return false end
  if not arena_chains.isGenerator(cell.chain_id, cell.level) then return false end
  return not arena.isGeneratorUnlocked(cell.chain_id)
end

function arena.canTapGenerator(index)
  if not arena.isGeneratorCell(index) then return false end
  if arena.isGeneratorLocked(index) then return false end
  local has_fuel = resources.getFuel() >= 1
  local has_token = drops.getGenTokens() > 0
  if not has_fuel and not has_token then return false end
  if arena.countEmpty() == 0 then return false end
  if arena.isGeneratorDepleted(index) then return false end
  return true
end

function arena.tapGenerator(index)
  if not arena.canTapGenerator(index) then return nil end

  local cell = grid[index]
  -- Use gen token first, then check free tap chance, otherwise spend fuel
  local used_token = false
  local free_tap = false
  if drops.getGenTokens() > 0 then
    drops.useGenToken()
    used_token = true
  else
    local st = require("skill_tree")
    local free_chance = st.getFreeFuelTapChance()
    if free_chance > 0 and math.random() < free_chance then
      free_tap = true
    else
      resources.spendFuelNoSave(1)
    end
  end

  -- Decrement generator charges
  local max_ch = getMaxCharges(cell.chain_id, cell.level)
  if cell.charges == nil then
    cell.charges = max_ch
  end
  cell.charges = cell.charges - 1
  if cell.charges <= 0 and not cell.recharge_timer then
    cell.recharge_timer = 0
  end

  -- Pick drop: hardcoded during tutorial, shuffle bag after
  local drop
  if not arena.isTutorialDone() and tutorial_gen_index < #TUTORIAL_GEN_DROPS then
    tutorial_gen_index = tutorial_gen_index + 1
    drop = TUTORIAL_GEN_DROPS[tutorial_gen_index]
  else
    drop = arena.pullFromShuffleBag(cell.chain_id, cell.level)
  end
  if not drop then return nil end

  local empty = arena.findNearestEmpty(index)
  if not empty then return nil end

  grid[empty] = {chain_id = drop.chain_id, level = drop.level}
  arena.save()

  return {
    drop_index = empty,
    drop_chain_id = drop.chain_id,
    drop_level = drop.level,
    charges = cell.charges,
    max_charges = max_ch,
    used_token = used_token,
    free_tap = free_tap,
  }
end

-- === CHEST MECHANICS ===

function arena.isChestCell(index)
  local cell = grid[index]
  return cell ~= nil and cell.state == "chest"
end

function arena.getChestCharges(index)
  local cell = grid[index]
  if not cell or cell.state ~= "chest" then return nil end
  return cell.charges or 0
end

function arena.canTapChest(index)
  if not arena.isChestCell(index) then return false end
  if arena.countEmpty() == 0 then return false end
  return true
end

-- Roll a chest drop based on the chest's generator chain type.
-- 70% own chain items (L1-2), 30% food items produced by that chain (L1-2).
-- Food sub-chains: Ch→Me/Da, He→Ba, Bl→De, Ki→So, Ta→Be, Cu→(none).
local CHEST_FOOD_MAP = {
  Ch = {"Me", "Da"},
  He = {"Ba"},
  Bl = {"De"},
  Ki = {"So"},
  Ta = {"Be"},
  Cu = {},  -- Cupboard has no food sub-chains
}

local function rollChestDrop(chest_chain_id)
  local food_chains = CHEST_FOOD_MAP[chest_chain_id] or {}

  local chain_id
  if math.random() < 0.70 or #food_chains == 0 then
    chain_id = chest_chain_id
  else
    chain_id = food_chains[math.random(#food_chains)]
  end

  local level = math.random(1, 2)
  return {chain_id = chain_id, level = level}
end

function arena.tapChest(index)
  if not arena.canTapChest(index) then return nil end

  local cell = grid[index]
  local drop = rollChestDrop(cell.chain_id)

  local empty = arena.findNearestEmpty(index)
  if not empty then return nil end

  grid[empty] = {chain_id = drop.chain_id, level = drop.level}

  cell.charges = cell.charges - 1
  local remaining = cell.charges
  if remaining <= 0 then
    grid[index] = nil  -- chest disappears
  end

  arena.save()

  return {
    drop_index = empty,
    drop_chain_id = drop.chain_id,
    drop_level = drop.level,
    charges_remaining = remaining,
  }
end

-- Shuffle bag: refill from remaining uncompleted order requirements
function arena.refillShuffleBag()
  local reqs = arena_orders.getAllRemainingRequirements()
  shuffle_bag = {}
  for _, item in ipairs(reqs) do
    shuffle_bag[#shuffle_bag + 1] = {chain_id = item.chain_id, level = item.level}
  end
  -- Fisher-Yates shuffle
  for i = #shuffle_bag, 2, -1 do
    local j = math.random(1, i)
    shuffle_bag[i], shuffle_bag[j] = shuffle_bag[j], shuffle_bag[i]
  end
end

-- Pull next item from shuffle bag that this generator's chain can produce.
-- Refills if empty, falls back to chain's own drop table if no match found.
function arena.pullFromShuffleBag(gen_chain_id, gen_level)
  if #shuffle_bag == 0 then
    arena.refillShuffleBag()
  end
  -- Build a set of valid chain_id + level combos this generator can produce
  local produces = arena_chains.getProduces(gen_chain_id)
  if produces and #shuffle_bag > 0 then
    local valid = {}
    for _, p in ipairs(produces) do
      for lv = 1, p.max_level do
        valid[p.chain_id .. ":" .. lv] = true
      end
    end
    for i, item in ipairs(shuffle_bag) do
      if valid[item.chain_id .. ":" .. item.level] then
        return table.remove(shuffle_bag, i)
      end
    end
  end
  -- Fallback: bag empty or no matching item — use chain's own drop table
  return arena_chains.rollDrop(gen_chain_id, gen_level)
end

-- === DISPENSER ===

function arena.getDispenserItem()
  return dispenser_queue[1]
end

function arena.popDispenser()
  if #dispenser_queue == 0 then return nil end
  return table.remove(dispenser_queue, 1)
end

function arena.pushDispenser(chain_id, level)
  dispenser_queue[#dispenser_queue + 1] = {chain_id = chain_id, level = level}
end

function arena.pushDispenserMultiple(items)
  for _, item in ipairs(items) do
    if item.state == "chest" then
      -- Chest items go directly as chest cells (with chain type)
      dispenser_queue[#dispenser_queue + 1] = {state = "chest", charges = item.charges or 3, chain_id = item.chain_id or "Ch"}
    else
      dispenser_queue[#dispenser_queue + 1] = {chain_id = item.chain_id, level = item.level}
    end
  end
end

function arena.getDispenserSize()
  return #dispenser_queue
end

function arena.placeFromDispenser(target_index)
  if target_index < 1 or target_index > GRID_SIZE then return nil end
  if grid[target_index] then return nil end
  if #dispenser_queue == 0 then return nil end
  local item = table.remove(dispenser_queue, 1)
  grid[target_index] = {chain_id = item.chain_id, level = item.level}
  arena.save()
  return item
end

-- Pop dispenser item to nearest empty grid cell (tap-to-pop behavior)
function arena.popDispenserToGrid()
  if #dispenser_queue == 0 then return nil end
  local center = 25  -- approximate grid center (row4 col4)
  local empty = arena.findNearestEmpty(center)
  if not empty then return nil end
  local item = table.remove(dispenser_queue, 1)
  if item.state == "chest" then
    grid[empty] = {state = "chest", charges = item.charges or 3, chain_id = item.chain_id or "Ch"}
    arena.save()
    return {index = empty, is_chest = true, chest_chain_id = item.chain_id}
  end
  grid[empty] = {chain_id = item.chain_id, level = item.level}
  arena.save()
  return {index = empty, chain_id = item.chain_id, level = item.level}
end

-- === STASH ===

function arena.getStash()
  return stash
end

function arena.getStashSlot(slot)
  local sz = arena.getStashSize()
  if slot < 1 or slot > sz then return nil end
  return stash[slot]
end

function arena.moveToStash(grid_index, stash_slot)
  local cell = grid[grid_index]
  if not cell or cell.state then return false end
  local sz = arena.getStashSize()
  if stash_slot < 1 or stash_slot > sz then return false end
  if stash[stash_slot] then return false end
  stash[stash_slot] = {chain_id = cell.chain_id, level = cell.level}
  grid[grid_index] = nil
  arena.save()
  return true
end

function arena.moveFromStash(stash_slot, grid_index)
  local sz = arena.getStashSize()
  if stash_slot < 1 or stash_slot > sz then return false end
  local item = stash[stash_slot]
  if not item then return false end
  if grid_index < 1 or grid_index > GRID_SIZE then return false end
  if grid[grid_index] then return false end
  grid[grid_index] = {chain_id = item.chain_id, level = item.level}
  stash[stash_slot] = nil
  arena.save()
  return true
end

function arena.moveStashToStash(from_slot, to_slot)
  local sz = arena.getStashSize()
  if from_slot < 1 or from_slot > sz then return false end
  if to_slot < 1 or to_slot > sz then return false end
  if not stash[from_slot] then return false end
  if stash[to_slot] then return false end
  stash[to_slot] = stash[from_slot]
  stash[from_slot] = nil
  arena.save()
  return true
end

-- === ORDER INTEGRATION ===

function arena.canCompleteOrder(order_id)
  local order = arena_orders.getOrderById(order_id)
  if not order then return false end

  for _, req in ipairs(order.requirements) do
    local found = 0
    for i = 1, GRID_SIZE do
      local cell = grid[i]
      if cell and not cell.state and cell.chain_id == req.chain_id and cell.level == req.level then
        found = found + 1
      end
    end
    if found < req.count then return false end
  end
  return true
end

function arena.completeOrder(order_id)
  if not arena.canCompleteOrder(order_id) then return nil end

  local order = arena_orders.getOrderById(order_id)

  -- Remove required items from grid (first matching)
  for _, req in ipairs(order.requirements) do
    local to_remove = req.count
    for i = 1, GRID_SIZE do
      if to_remove <= 0 then break end
      local cell = grid[i]
      if cell and not cell.state and cell.chain_id == req.chain_id and cell.level == req.level then
        grid[i] = nil
        to_remove = to_remove - 1
      end
    end
  end

  local reward = arena_orders.completeOrder(order_id)
  if reward and reward.item_rewards then
    arena.pushDispenserMultiple(reward.item_rewards)
  end
  if reward and reward.xp_reward then
    xp = xp + reward.xp_reward
  end
  if reward and reward.bag_reward then
    bags.addBagsNoSave(reward.bag_reward)
  end
  if reward and reward.star_reward then
    resources.addStarsNoSave(reward.star_reward)
  end

  -- Roll variable drops based on order difficulty
  local order_drops = nil
  if reward and reward.difficulty then
    order_drops = drops.rollOrderDrops(reward.difficulty)
  end

  arena.save()
  if reward then
    reward.drops = order_drops
  end
  return reward
end

function arena.checkLevelComplete()
  if not arena_orders.isLevelComplete() then return nil end

  local result = arena_orders.advanceLevel()
  if not result then return nil end

  if result.items then
    arena.pushDispenserMultiple(result.items)
  end
  if result.xp then
    xp = xp + result.xp
  end
  if result.bag_reward then
    bags.addBagsNoSave(result.bag_reward)
  end
  if result.star_reward then
    resources.addStarsNoSave(result.star_reward)
  end

  -- Level completion always drops 1 random powerup
  local level_drop = drops.rollLevelCompletionDrop()

  -- Clear shuffle bag so it refills for the new level
  shuffle_bag = {}

  arena.save()
  return {
    new_level = arena_orders.getCurrentLevel(),
    reward_items = result.items,
    reward_xp = result.xp,
    level_drop = level_drop,
  }
end

-- === XP ===

function arena.getXP() return xp end
function arena.addXP(amount) xp = xp + amount; arena.save() end

-- === TUTORIAL ===

function arena.getTutorialStep() return tutorial_step end
function arena.setTutorialStep(step) tutorial_step = step; arena.save() end
function arena.isTutorialDone() return tutorial_step == "done" end

-- === GRID ACCESS ===

function arena.getGrid() return grid end
function arena.getGridSize() return GRID_SIZE end
function arena.getGridDimensions() return GRID_COLS, GRID_ROWS end
function arena.getStashSize()
  local st = require("skill_tree")
  return st.getStashSize()
end

-- === INITIAL BOARD SETUP ===

function arena.setupInitialBoard()
  grid = {}
  stash = {}
  dispenser_queue = {}
  xp = 0
  tutorial_step = 1

  for i = 1, GRID_SIZE do
    local code = INITIAL_CONTENTS[i]
    if INITIAL_EMPTY[i] or code == "." then
      grid[i] = nil
    else
      local parsed = arena_chains.parseItemCode(code)
      if parsed then
        if INITIAL_SEALED[i] then
          grid[i] = {state = "sealed", chain_id = parsed.chain_id, level = parsed.level}
        else
          grid[i] = {state = "box", chain_id = parsed.chain_id, level = parsed.level}
        end
      end
    end
  end

  local sz = arena.getStashSize()
  for i = 1, sz do
    stash[i] = nil
  end

  arena.save()
end

-- === SAVE / LOAD ===

function arena.save()
  local grid_save = {}
  for i = 1, GRID_SIZE do
    if grid[i] then grid_save[i] = grid[i] end
  end

  local stash_save = {}
  local sz = arena.getStashSize()
  for i = 1, sz do
    if stash[i] then stash_save[i] = stash[i] end
  end

  local data = {
    grid = grid_save,
    stash = stash_save,
    dispenser_queue = dispenser_queue,
    order_level = arena_orders.getCurrentLevel(),
    completed_orders = arena_orders.getCompletedSet(),
    xp = xp,
    tutorial_step = tutorial_step,
    tutorial_gen_index = tutorial_gen_index,
    shuffle_bag = shuffle_bag,
  }

  progression.setArenaData(data)
  bags.sync()
  resources.sync()
  drops.sync()
  progression.save()
end

function arena.init()
  local data = progression.getArenaData()

  -- Detect new format (has 'grid' key with content)
  if data.grid then
    local has_content = false
    for _, v in pairs(data.grid) do
      if v then has_content = true end
      break
    end

    if has_content then
      grid = {}
      for i = 1, GRID_SIZE do
        grid[i] = data.grid[i] or nil
      end
      stash = {}
      local sz = arena.getStashSize()
      for i = 1, sz do
        stash[i] = (data.stash and data.stash[i]) or nil
      end
      dispenser_queue = data.dispenser_queue or {}
      xp = data.xp or 0
      tutorial_step = data.tutorial_step or 1
      tutorial_gen_index = data.tutorial_gen_index or 0
      shuffle_bag = data.shuffle_bag or {}

      arena_orders.init(data.order_level or 1, data.completed_orders or {})
      initialized = true
      return
    end
  end

  -- Fresh start (or old format migration)
  arena_orders.init(1, {})
  arena.setupInitialBoard()
  initialized = true
end

function arena.isInitialized()
  return initialized
end

function arena.update(dt)
  -- Generator recharge: fully depleted generators recharge all charges after recharge time
  local st = require("skill_tree")
  local recharge_time = st.getGenRechargeTime()
  local dirty = false
  for i = 1, GRID_SIZE do
    local cell = grid[i]
    if cell and not cell.state and cell.recharge_timer then
      local max_ch = getMaxCharges(cell.chain_id, cell.level)
      if cell.charges and cell.charges < max_ch then
        cell.recharge_timer = cell.recharge_timer + dt
        if cell.recharge_timer >= recharge_time then
          cell.charges = max_ch
          cell.recharge_timer = nil
          dirty = true
        end
      else
        cell.recharge_timer = nil
      end
    end
  end
  if dirty then arena.save() end
end

return arena
