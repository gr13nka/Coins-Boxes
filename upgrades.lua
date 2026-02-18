-- upgrades.lua
-- Permanent upgrades: houses (passive crystal production), row/column purchases.
-- Pure data module (no drawing).

local progression = require("progression")
local currency = require("currency")

local upgrades = {}

-- House config
local MAX_HOUSES = 6
local HOUSE_COSTS = {5, 10, 15, 20, 25, 30}       -- crystal cost per slot
local HOUSE_RATE = 0.25                              -- crystals per minute per house

-- Row/column upgrade costs (escalating)
local ROW_COSTS = {10, 20, 35, 50}
local COLUMN_COSTS = {15, 30, 50, 75}
local MAX_EXTRA_ROWS = #ROW_COSTS
local MAX_EXTRA_COLUMNS = #COLUMN_COSTS

-- Runtime state (loaded from progression)
local extra_rows = 0
local extra_columns = 0
local houses = {}

local function defaultHouses()
  local h = {}
  for i = 1, MAX_HOUSES do
    h[i] = {built = false, color = "red", progress = 0}
  end
  return h
end

function upgrades.init()
  local d = progression.getUpgradesData()
  extra_rows = d.extra_rows or 0
  extra_columns = d.extra_columns or 0
  houses = d.houses or defaultHouses()
  -- Ensure we always have MAX_HOUSES entries
  for i = #houses + 1, MAX_HOUSES do
    houses[i] = {built = false, color = "red", progress = 0}
  end
end

function upgrades.save()
  progression.setUpgradesData({
    extra_rows = extra_rows,
    extra_columns = extra_columns,
    houses = houses,
  })
  progression.save()
end

-- Grid size helpers
function upgrades.getBaseRows()
  return 4 + extra_rows
end

function upgrades.getBaseColumns()
  return 4 + extra_columns
end

-- Row upgrade
function upgrades.getRowCost()
  if extra_rows >= MAX_EXTRA_ROWS then return nil end
  return ROW_COSTS[extra_rows + 1]
end

function upgrades.buyRow(color)
  local cost = upgrades.getRowCost()
  if not cost then return false end
  if currency.spendCrystals(color, cost) then
    extra_rows = extra_rows + 1
    upgrades.save()
    return true
  end
  return false
end

function upgrades.canBuyRow()
  return extra_rows < MAX_EXTRA_ROWS
end

-- Column upgrade
function upgrades.getColumnCost()
  if extra_columns >= MAX_EXTRA_COLUMNS then return nil end
  return COLUMN_COSTS[extra_columns + 1]
end

function upgrades.buyColumn(color)
  local cost = upgrades.getColumnCost()
  if not cost then return false end
  if currency.spendCrystals(color, cost) then
    extra_columns = extra_columns + 1
    upgrades.save()
    return true
  end
  return false
end

function upgrades.canBuyColumn()
  return extra_columns < MAX_EXTRA_COLUMNS
end

-- House management
function upgrades.getHouses()
  return houses
end

function upgrades.getHouseCost(slot)
  if slot < 1 or slot > MAX_HOUSES then return nil end
  return HOUSE_COSTS[slot]
end

function upgrades.buildHouse(slot, color)
  if slot < 1 or slot > MAX_HOUSES then return false end
  if houses[slot].built then return false end
  local cost = HOUSE_COSTS[slot]
  if currency.spendCrystals(color, cost) then
    houses[slot].built = true
    houses[slot].color = color
    houses[slot].progress = 0
    upgrades.save()
    return true
  end
  return false
end

function upgrades.setHouseColor(slot, color)
  if slot < 1 or slot > MAX_HOUSES then return end
  if not houses[slot].built then return end
  houses[slot].color = color
  upgrades.save()
end

-- Tick house production (call from game update loop)
function upgrades.updateProduction(dt)
  local produced = false
  for _, house in ipairs(houses) do
    if house.built then
      -- progress accumulates toward 1.0 (= 1 crystal)
      house.progress = house.progress + (HOUSE_RATE / 60) * dt
      if house.progress >= 1.0 then
        house.progress = house.progress - 1.0
        currency.addCrystal(house.color, 1)
        produced = true
      end
    end
  end
  if produced then
    currency.save()
  end
end

function upgrades.getMaxHouses()
  return MAX_HOUSES
end

function upgrades.getExtraRows()
  return extra_rows
end

function upgrades.getExtraColumns()
  return extra_columns
end

return upgrades
