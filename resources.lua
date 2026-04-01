-- resources.lua
-- Fuel/Metal/Components resource system. Pure data module (no drawing).
-- Fuel powers arena generators, Metal builds them, Components unlock arena elements.

local progression = require("progression")

local resources = {}

local FUEL_CAP = 100

-- Runtime state
local fuel = 0
local metal = 0
local components = 0

-- Merge reward table: keyed by resulting coin level after merge
local MERGE_REWARDS = {
  [2] = { fuel = 1, components = 0, metal_chance = 0 },
  -- L3 intentionally empty (stabilizer)
  [4] = { fuel = 1, components = 1, metal_chance = 0 },
  [5] = { fuel = 2, components = 1, metal_chance = 0.05 },
  [6] = { fuel = 3, components = 2, metal_chance = 0.25 },
  [7] = { fuel = 4, components = 3, metal_chance = 0.50 },
}

function resources.init()
  local d = progression.getResourcesData()
  fuel = d.fuel or 100
  metal = d.metal or 0
  components = d.components or 0
  -- Ensure new players start with fuel (old saves may have fuel=0)
  if fuel == 0 and metal == 0 and components == 0 then
    fuel = 100
  end
end

function resources.save()
  progression.setResourcesData({
    fuel = fuel,
    metal = metal,
    components = components,
  })
  progression.save()
end

-- Called from game_2048 when coins merge. new_number = level of resulting coin.
-- Returns table of resources gained (for UI feedback).
function resources.onCoinMerge(new_number)
  local r = MERGE_REWARDS[new_number]
  if not r then return { fuel = 0, metal = 0, components = 0 } end

  local gained = { fuel = 0, metal = 0, components = 0 }

  if r.fuel > 0 then
    local added = math.min(r.fuel, FUEL_CAP - fuel)
    fuel = fuel + added
    gained.fuel = added
  end

  if r.components > 0 then
    components = components + r.components
    gained.components = r.components
  end

  if r.metal_chance > 0 and math.random() < r.metal_chance then
    metal = metal + 1
    gained.metal = 1
  end

  resources.save()
  return gained
end

-- Getters
function resources.getFuel() return fuel end
function resources.getMetal() return metal end
function resources.getComponents() return components end
function resources.getFuelCap() return FUEL_CAP end

-- Add resources (from arena rewards, etc.)
function resources.addFuel(n)
  fuel = math.min(fuel + n, FUEL_CAP)
  resources.save()
end

function resources.addMetal(n)
  metal = metal + n
  resources.save()
end

function resources.addComponents(n)
  components = components + n
  resources.save()
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

function resources.spendMetal(n)
  if metal >= n then
    metal = metal - n
    resources.save()
    return true
  end
  return false
end

function resources.spendComponents(n)
  if components >= n then
    components = components - n
    resources.save()
    return true
  end
  return false
end

return resources
