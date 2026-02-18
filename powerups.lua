-- powerups.lua
-- Consumable power-ups: Auto Sort, Hammer. Pure data module (no drawing).
-- Counts persist via progression. Purchasable on upgrades screen.

local progression = require("progression")
local currency = require("currency")

local powerups = {}

-- Costs
local SORT_COST = {red = 2, green = 2}
local HAMMER_COST = {red = 1}

-- Runtime state (loaded from progression)
local auto_sort_count = 100
local hammer_count = 100

function powerups.init()
  local d = progression.getPowerupsData()
  auto_sort_count = d.auto_sort or 100
  hammer_count = d.hammer or 100
end

function powerups.save()
  progression.setPowerupsData({
    auto_sort = auto_sort_count,
    hammer = hammer_count,
  })
  progression.save()
end

-- Getters
function powerups.getAutoSortCount()
  return auto_sort_count
end

function powerups.getHammerCount()
  return hammer_count
end

function powerups.getSortCost()
  return SORT_COST
end

function powerups.getHammerCost()
  return HAMMER_COST
end

-- Use (decrement). Returns true if had charges.
function powerups.useAutoSort()
  if auto_sort_count <= 0 then return false end
  auto_sort_count = auto_sort_count - 1
  powerups.save()
  return true
end

function powerups.useHammer()
  if hammer_count <= 0 then return false end
  hammer_count = hammer_count - 1
  powerups.save()
  return true
end

-- Buy (spend crystals + increment). Returns true on success.
function powerups.buyAutoSort()
  if currency.spendMulti(SORT_COST) then
    auto_sort_count = auto_sort_count + 1
    powerups.save()
    return true
  end
  return false
end

function powerups.buyHammer()
  if currency.spendMulti(HAMMER_COST) then
    hammer_count = hammer_count + 1
    powerups.save()
    return true
  end
  return false
end

return powerups
