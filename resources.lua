-- resources.lua
-- Fuel + Stars resource system. Pure data module (no drawing).
-- Fuel powers arena generators. Stars are a shared progression currency
-- that triggers milestone unlocks (replaces old Metal/Components).

local progression = require("progression")

local resources = {}

-- Runtime state
local fuel = 0
local stars = 0

-- Merge reward table: keyed by resulting coin level after merge
-- fuel = guaranteed Fuel gained, stars = guaranteed Stars gained
local MERGE_REWARDS = {
  [2] = { fuel = 1, stars = 0 },
  -- L3 intentionally empty (stabilizer)
  [4] = { fuel = 1, stars = 1 },
  [5] = { fuel = 2, stars = 2 },
  [6] = { fuel = 3, stars = 3 },
  [7] = { fuel = 4, stars = 5 },
}

function resources.init()
  local d = progression.getResourcesData()
  fuel = d.fuel or 50
  stars = d.stars or 0
  -- Migrate old saves: convert metal+components to stars
  if d.metal and d.metal > 0 then
    stars = stars + d.metal
  end
  if d.components and d.components > 0 then
    stars = stars + d.components
  end
  -- Ensure new players start with fuel
  if fuel == 0 and stars == 0 then
    fuel = 50
  end
end

function resources.save()
  progression.setResourcesData({
    fuel = fuel,
    stars = stars,
  })
  progression.save()
end

-- Merge bonus fuel delegated to skill tree
local function getMergeBonusFuel(new_number)
  local st = require("skill_tree")
  local bonus = st.getMergeBonusFuel(new_number)
  -- L3 fuel bonus from Early Fuel node
  if new_number == 3 then
    bonus = bonus + st.getL3FuelBonus()
  end
  return bonus
end

-- Dynamic fuel cap from skill tree
local function getFuelCap()
  local st = require("skill_tree")
  return st.getFuelCap()
end

-- Called from coin_sort when coins merge. new_number = level of resulting coin.
-- Returns table of resources gained (for UI feedback).
function resources.onCoinMerge(new_number)
  local r = MERGE_REWARDS[new_number]
  local gained = { fuel = 0, stars = 0 }

  local base_fuel = r and r.fuel or 0
  local base_stars = r and r.stars or 0
  local bonus_fuel = getMergeBonusFuel(new_number)
  local total_fuel = base_fuel + bonus_fuel

  if total_fuel > 0 then
    local cap = getFuelCap()
    local added = math.min(total_fuel, cap - fuel)
    fuel = fuel + added
    gained.fuel = added
  end

  if base_stars > 0 then
    local st = require("skill_tree")
    local multiplied = math.ceil(base_stars * st.getStarMultiplier())
    stars = stars + multiplied
    gained.stars = multiplied
  end

  resources.save()
  return gained
end

-- Getters
function resources.getFuel() return fuel end
function resources.getStars() return stars end
function resources.getFuelCap() return getFuelCap() end

-- Add resources (from arena rewards, commissions, etc.)
function resources.addFuel(n)
  fuel = math.min(fuel + n, getFuelCap())
  resources.save()
end

function resources.addStars(n)
  local st = require("skill_tree")
  local multiplied = math.ceil(n * st.getStarMultiplier())
  stars = stars + multiplied
  resources.save()
end

-- Spend stars (for skill tree purchases)
function resources.spendStars(n)
  if stars >= n then
    stars = stars - n
    resources.save()
    return true
  end
  return false
end

-- Spend resources (returns true if affordable)
function resources.spendFuel(n)
  if fuel >= n then
    fuel = fuel - n
    resources.save()
    return true
  end
  return false
end

-- No-save variants (caller handles save via resources.sync + progression.save)
function resources.addStarsNoSave(n)
  local st = require("skill_tree")
  local multiplied = math.ceil(n * st.getStarMultiplier())
  stars = stars + multiplied
end

function resources.spendStarsNoSave(n)
  if stars >= n then
    stars = stars - n
    return true
  end
  return false
end

function resources.spendFuelNoSave(n)
  if fuel >= n then
    fuel = fuel - n
    return true
  end
  return false
end

function resources.addFuelNoSave(n)
  fuel = math.min(fuel + n, getFuelCap())
end

-- Push resources state to progression without writing to disk
function resources.sync()
  progression.setResourcesData({ fuel = fuel, stars = stars })
end

return resources
