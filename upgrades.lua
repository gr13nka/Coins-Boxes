-- upgrades.lua
-- Permanent upgrades: houses (passive crystal production), row/column purchases, difficulty.
-- Pure data module (no drawing).
-- All upgrades cost 1 red + 1 green crystal (flat).

local progression = require("progression")
local currency = require("currency")

local upgrades = {}

-- Flat cost for all upgrades: 1 red + 1 green crystal
local UPGRADE_COST = {red = 1, green = 1}

-- House config
local MAX_HOUSES = 6
local HOUSE_RATE = 0.25  -- crystals per minute per house

-- Row/column limits
local MAX_EXTRA_ROWS = 6      -- max 10 rows (4 base + 6)
local MAX_EXTRA_COLUMNS = 11  -- max 15 columns (4 base + 11)

-- Buffer ratio used as reference for shard bonus calculation
local DEFAULT_BUFFER_MIN = 0.30

-- Rainbow cost to unlock houses (1 of each crystal color)
local RAINBOW_COST = {red = 1, green = 1, purple = 1, blue = 1, pink = 1}

-- Runtime state (loaded from progression)
local extra_rows = 0
local extra_columns = 0
local houses = {}
local houses_unlocked = false
local free_house_available = false  -- player gets 1 free house on unlock
local difficulty_extra_types = 0  -- 0 = normal, +1 = hard, +2 = extreme, etc.
local max_coin_reached = 0  -- highest coin number ever created across all runs

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
  difficulty_extra_types = d.difficulty_extra_types or 0
  max_coin_reached = d.max_coin_reached or 0
  houses = d.houses or defaultHouses()
  for i = #houses + 1, MAX_HOUSES do
    houses[i] = {built = false, color = "red", progress = 0}
  end
  -- Load houses_unlocked with migration: auto-unlock if any house already built
  houses_unlocked = d.houses_unlocked or false
  free_house_available = d.free_house_available or false
  if not houses_unlocked then
    for _, h in ipairs(houses) do
      if h.built then
        houses_unlocked = true
        break
      end
    end
  end
end

function upgrades.save()
  progression.setUpgradesData({
    extra_rows = extra_rows,
    extra_columns = extra_columns,
    houses_unlocked = houses_unlocked,
    free_house_available = free_house_available,
    difficulty_extra_types = difficulty_extra_types,
    max_coin_reached = max_coin_reached,
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

-- Get the flat upgrade cost table
function upgrades.getUpgradeCost()
  return UPGRADE_COST
end

-- Row upgrade
function upgrades.canBuyRow()
  return extra_rows < MAX_EXTRA_ROWS
end

function upgrades.buyRow()
  if extra_rows >= MAX_EXTRA_ROWS then return false end
  if currency.spendMulti(UPGRADE_COST) then
    extra_rows = extra_rows + 1
    upgrades.save()
    return true
  end
  return false
end

-- Column upgrade
function upgrades.canBuyColumn()
  return extra_columns < MAX_EXTRA_COLUMNS
end

function upgrades.buyColumn()
  if extra_columns >= MAX_EXTRA_COLUMNS then return false end
  if currency.spendMulti(UPGRADE_COST) then
    extra_columns = extra_columns + 1
    upgrades.save()
    return true
  end
  return false
end

-- Difficulty setting
function upgrades.getDifficultyExtraTypes()
  return difficulty_extra_types
end

function upgrades.setDifficultyExtraTypes(n)
  difficulty_extra_types = math.max(0, math.floor(n))
  upgrades.save()
end

-- Maximum extra types allowed for current column count.
-- At least 1 buffer column must remain.
function upgrades.getMaxDifficultyExtraTypes()
  local cols = 4 + extra_columns
  local default_max_types = math.floor(cols * (1 - DEFAULT_BUFFER_MIN))
  local max_extra = (cols - 1) - default_max_types
  if max_extra < 0 then max_extra = 0 end
  return max_extra
end

-- Shard bonus multiplier from difficulty setting.
-- More types = smaller buffer = higher shard bonus.
-- +10% bonus per 5% buffer decrease (measured in steps).
function upgrades.getShardBonusMultiplier()
  if difficulty_extra_types <= 0 then
    return 1.0
  end
  local cols = 4 + extra_columns
  local default_max_types = math.floor(cols * (1 - DEFAULT_BUFFER_MIN))
  local actual_types = default_max_types + difficulty_extra_types
  if actual_types >= cols then
    actual_types = cols - 1
  end
  local reference_buffer = (cols - default_max_types) / cols
  local actual_buffer = (cols - actual_types) / cols
  local decrease = reference_buffer - actual_buffer
  local bonus = math.floor(decrease / 0.05) * 0.10
  return 1.0 + bonus
end

-- House management
function upgrades.getHouses()
  return houses
end

function upgrades.getMaxHouses()
  return MAX_HOUSES
end

function upgrades.buildHouse(slot, production_color)
  if slot < 1 or slot > MAX_HOUSES then return false end
  if houses[slot].built then return false end
  -- Use free house token if available, otherwise spend crystals
  if free_house_available then
    free_house_available = false
  elseif not currency.spendMulti(UPGRADE_COST) then
    return false
  end
  houses[slot].built = true
  houses[slot].color = production_color
  houses[slot].progress = 0
  upgrades.save()
  return true
end

function upgrades.setHouseColor(slot, color)
  if slot < 1 or slot > MAX_HOUSES then return end
  if not houses[slot].built then return end
  houses[slot].color = color
  upgrades.save()
end

-- Tick house production (call from any screen's update loop)
-- Returns array of {slot=i, color=name} for each house that produced a crystal
function upgrades.updateProduction(dt)
  local events = {}
  for i, house in ipairs(houses) do
    if house.built then
      house.progress = house.progress + (HOUSE_RATE / 60) * dt
      if house.progress >= 1.0 then
        house.progress = house.progress - 1.0
        currency.addCrystal(house.color, 1)
        events[#events + 1] = {slot = i, color = house.color}
      end
    end
  end
  if #events > 0 then
    currency.save()
  end
  return events
end

function upgrades.getHouseRate()
  return HOUSE_RATE
end

function upgrades.getExtraRows()
  return extra_rows
end

function upgrades.getExtraColumns()
  return extra_columns
end

-- Max coin level ever reached (across all runs)
function upgrades.getMaxCoinReached()
  return max_coin_reached
end

function upgrades.setMaxCoinReached(n)
  if n > max_coin_reached then
    max_coin_reached = n
    upgrades.save()
  end
end

-- House unlock system
function upgrades.isHousesUnlocked()
  return houses_unlocked
end

function upgrades.getRainbowCost()
  return RAINBOW_COST
end

-- Count how many crystal colors have >= 1 crystal (0-5)
function upgrades.getUniqueColorCount()
  local cr = currency.getCrystals()
  local count = 0
  for color, _ in pairs(RAINBOW_COST) do
    if (cr[color] or 0) >= 1 then
      count = count + 1
    end
  end
  return count
end

-- Spend rainbow cost, set unlocked, give 1 free house token
function upgrades.unlockHouses()
  if houses_unlocked then return false end
  if not currency.spendMulti(RAINBOW_COST) then return false end
  houses_unlocked = true
  free_house_available = true
  upgrades.save()
  return true
end

function upgrades.hasFreeHouse()
  return free_house_available
end

return upgrades
