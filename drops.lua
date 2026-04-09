-- drops.lua
-- Variable drop system for cross-mode rewards.
-- Coin Sort merges can drop: Chest (arena item), Fuel Surge, Star Burst, Generator Token.
-- Arena orders can drop: Hammer, AutoSort, Bag Bundle, Double Merge, Star Burst.
-- Pure data module (no drawing).

local resources = require("resources")
local bags = require("bags")
local powerups = require("powerups")
local progression = require("progression")

local drops = {}

-- === CS MERGE DROP TABLES ===
-- chance by resulting coin level (1-indexed: level 1 has no drops)
local CS_CHEST_CHANCE = {
  [1] = 0, [2] = 0, [3] = 0.15, [4] = 0.20, [5] = 0.30, [6] = 0.40, [7] = 0.50,
}
local CS_FUEL_SURGE_CHANCE = 0.08   -- any merge
local CS_STAR_BURST_CHANCE = 0.05   -- L4+ only
local CS_GEN_TOKEN_CHANCE = 0.025   -- L5+ only

-- === ARENA ORDER DROP TABLES ===
-- chance by order difficulty: easy, medium, hard
local ARENA_HAMMER_CHANCE = {easy = 0.05, medium = 0.10, hard = 0.15}
local ARENA_AUTOSORT_CHANCE = {easy = 0.05, medium = 0.08, hard = 0.12}
local ARENA_BAG_BUNDLE_CHANCE = {easy = 0.08, medium = 0.10, hard = 0.15}
local ARENA_DOUBLE_MERGE_CHANCE = {easy = 0, medium = 0, hard = 0.025}
local ARENA_STAR_BURST_CHANCE = 0.05  -- any order

-- === PENDING DROPS STATE ===
-- Shelf: arena items earned during CS, transferred to arena dispenser on mode switch
local shelf = {}  -- array of {chain_id, level}
-- Generator tokens: free taps stored
local gen_tokens = 0
-- Whether the first chest has been given (hardcoded Cu chest)
local first_chest_given = false
-- CS powerup drops: pending for next CS session
local pending_cs_drops = {
  hammer = 0,
  auto_sort = 0,
  bag_bundle = 0,
  double_merge = 0,
}

-- === INIT / SAVE ===

function drops.init()
  local d = progression.getDropsData()
  shelf = d.shelf or {}
  gen_tokens = d.gen_tokens or 0
  first_chest_given = d.first_chest_given or false
  pending_cs_drops = d.pending_cs_drops or {
    hammer = 0, auto_sort = 0, bag_bundle = 0, double_merge = 0,
  }
end

function drops.sync()
  progression.setDropsData({
    shelf = shelf,
    gen_tokens = gen_tokens,
    first_chest_given = first_chest_given,
    pending_cs_drops = pending_cs_drops,
  })
end

function drops.save()
  drops.sync()
  progression.save()
end

-- Roll chest charges based on merge level. Higher merge = more taps.
-- L3→2, L4→3, L5→4, L6→5, L7→6
local function rollChestCharges(new_number)
  return math.max(2, new_number - 1)
end

-- === CS MERGE DROPS ===
-- Called after each merge in Coin Sort. Returns array of drop descriptors for UI.
function drops.rollMergeDrops(new_number)
  local results = {}

  local st = require("skill_tree")

  -- Chest drop — chain weighted by current order needs.
  -- First chest is always Cu (Cupboard) to seed generator building.
  local chest_chance = (CS_CHEST_CHANCE[new_number] or 0) + st.getChestChanceBonus()
  if chest_chance > 0 and math.random() < chest_chance then
    local chest_chain
    if not first_chest_given then
      -- First chest: hardcoded Cu to help build Cupboard generator
      chest_chain = "Cu"
      first_chest_given = true
    else
      local CHAIN_TO_GEN = {
        Ch = "Ch", Cu = "Cu", He = "He", Bl = "Bl", Ki = "Ki", Ta = "Ta",
        Me = "Ch", Da = "Ch", Ba = "He", De = "Bl", So = "Ki", Be = "Ta",
      }
      local gen_chains = {"Ch", "Cu", "He", "Bl", "Ki", "Ta"}

      -- Base weight: every chain gets 1 entry for variety
      local arena_orders = require("arena_orders")
      local pool = {}
      for _, c in ipairs(gen_chains) do pool[#pool + 1] = c end
      -- Order weight: add extra entries for chains orders need
      local reqs = arena_orders.getAllRemainingRequirements()
      for _, r in ipairs(reqs) do
        local gen = CHAIN_TO_GEN[r.chain_id]
        if gen then pool[#pool + 1] = gen end
      end
      chest_chain = pool[math.random(#pool)]
    end
    local charges = rollChestCharges(new_number) + st.getChestChargeBonus()
    local chest = {state = "chest", charges = charges, chain_id = chest_chain}
    shelf[#shelf + 1] = chest
    results[#results + 1] = {type = "chest", charges = charges, chain_id = chest_chain}
  end

  -- Fuel Surge
  if math.random() < CS_FUEL_SURGE_CHANCE then
    local amount = math.random(3, 5) + st.getFuelSurgeBonus()
    resources.addFuelNoSave(amount)
    results[#results + 1] = {type = "fuel_surge", amount = amount}
  end

  -- Star Burst (L4+)
  if new_number >= 4 and math.random() < CS_STAR_BURST_CHANCE then
    local amount = math.random(2, 3)
    resources.addStarsNoSave(amount)
    results[#results + 1] = {type = "star_burst", amount = amount}
  end

  -- Generator Token (L5+, or L4+ with bonus)
  local gen_token_chance = CS_GEN_TOKEN_CHANCE + st.getGenTokenChanceBonus()
  if new_number >= 5 and math.random() < gen_token_chance then
    gen_tokens = gen_tokens + 1
    results[#results + 1] = {type = "gen_token"}
  end

  if #results > 0 then
    drops.sync()
  end

  return results
end

-- === ARENA ORDER DROPS ===
-- Called after completing an arena order. Returns array of drop descriptors for UI.
function drops.rollOrderDrops(order_difficulty)
  local diff = order_difficulty or "easy"
  local results = {}

  -- Hammer
  if (ARENA_HAMMER_CHANCE[diff] or 0) > 0 and math.random() < ARENA_HAMMER_CHANCE[diff] then
    pending_cs_drops.hammer = pending_cs_drops.hammer + 1
    results[#results + 1] = {type = "hammer"}
  end

  -- AutoSort
  if (ARENA_AUTOSORT_CHANCE[diff] or 0) > 0 and math.random() < ARENA_AUTOSORT_CHANCE[diff] then
    pending_cs_drops.auto_sort = pending_cs_drops.auto_sort + 1
    results[#results + 1] = {type = "auto_sort"}
  end

  -- Bag Bundle
  if (ARENA_BAG_BUNDLE_CHANCE[diff] or 0) > 0 and math.random() < ARENA_BAG_BUNDLE_CHANCE[diff] then
    local amount = math.random(1, 2)
    bags.addBagsNoSave(amount)
    results[#results + 1] = {type = "bag_bundle", amount = amount}
  end

  -- Double Merge (hard only)
  if (ARENA_DOUBLE_MERGE_CHANCE[diff] or 0) > 0 and math.random() < ARENA_DOUBLE_MERGE_CHANCE[diff] then
    pending_cs_drops.double_merge = pending_cs_drops.double_merge + 1
    results[#results + 1] = {type = "double_merge"}
  end

  -- Star Burst
  if math.random() < ARENA_STAR_BURST_CHANCE then
    local amount = math.random(2, 3)
    resources.addStarsNoSave(amount)
    results[#results + 1] = {type = "star_burst", amount = amount}
  end

  if #results > 0 then
    drops.sync()
  end

  return results
end

-- Level completion always drops 1 random powerup
function drops.rollLevelCompletionDrop()
  local roll = math.random(1, 3)
  if roll == 1 then
    pending_cs_drops.hammer = pending_cs_drops.hammer + 1
    drops.sync()
    return {type = "hammer"}
  elseif roll == 2 then
    pending_cs_drops.auto_sort = pending_cs_drops.auto_sort + 1
    drops.sync()
    return {type = "auto_sort"}
  else
    local amount = math.random(1, 2)
    bags.addBagsNoSave(amount)
    drops.sync()
    return {type = "bag_bundle", amount = amount}
  end
end

-- === SHELF (CS → Arena item transfer) ===

function drops.getShelf()
  return shelf
end

function drops.getShelfCount()
  return #shelf
end

-- Transfer shelf contents to arena dispenser, clear shelf. Returns items array.
function drops.transferShelf()
  local items = {}
  for i = 1, #shelf do
    items[i] = shelf[i]
  end
  shelf = {}
  drops.sync()
  return items
end

-- === GENERATOR TOKENS ===

function drops.getGenTokens()
  return gen_tokens
end

function drops.useGenToken()
  if gen_tokens <= 0 then return false end
  gen_tokens = gen_tokens - 1
  drops.sync()
  return true
end

-- === CS POWERUP DROPS (Arena → CS) ===

function drops.getPendingCSDrops()
  return pending_cs_drops
end

-- Apply pending CS drops (called on CS enter). Returns summary for notification.
function drops.applyPendingCSDrops()
  local applied = {}
  if pending_cs_drops.hammer > 0 then
    applied.hammer = pending_cs_drops.hammer
    -- Add to powerups (no save, caller handles)
    for _ = 1, pending_cs_drops.hammer do
      powerups.addHammerNoSave(1)
    end
    pending_cs_drops.hammer = 0
  end
  if pending_cs_drops.auto_sort > 0 then
    applied.auto_sort = pending_cs_drops.auto_sort
    for _ = 1, pending_cs_drops.auto_sort do
      powerups.addAutoSortNoSave(1)
    end
    pending_cs_drops.auto_sort = 0
  end
  if pending_cs_drops.double_merge > 0 then
    applied.double_merge = pending_cs_drops.double_merge
    -- Do NOT zero: charges consumed one-at-a-time by useDoubleMerge() during CS gameplay
  end
  -- bag_bundle already applied immediately via bags.addBagsNoSave

  if next(applied) then
    drops.sync()
  end
  return applied
end

-- Get double merge charges (consumed one at a time during CS)
function drops.getDoubleMergeCharges()
  return pending_cs_drops.double_merge
end

function drops.useDoubleMerge()
  if pending_cs_drops.double_merge <= 0 then return false end
  pending_cs_drops.double_merge = pending_cs_drops.double_merge - 1
  drops.sync()
  return true
end

-- === TOTAL PENDING COUNT (for tab bar badges) ===

function drops.getPendingArenaCount()
  return #shelf + gen_tokens
end

function drops.getPendingCSCount()
  return pending_cs_drops.hammer + pending_cs_drops.auto_sort
       + pending_cs_drops.bag_bundle + pending_cs_drops.double_merge
end

return drops
