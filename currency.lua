-- currency.lua
-- Shard/crystal currency system. Pure data module (no drawing).
-- Shards are earned from merging, auto-convert to crystals at 25:1.

local coin_utils = require("coin_utils")
local progression = require("progression")

local currency = {}

local SHARDS_PER_COIN = 5
local SHARDS_PER_CRYSTAL = 25

-- Runtime state (loaded from progression)
local shards = {red = 0, green = 0, purple = 0, blue = 0, pink = 0}
local crystals = {red = 0, green = 0, purple = 0, blue = 0, pink = 0}

-- Per-run tracking (reset each game start)
local run_shards = {red = 0, green = 0, purple = 0, blue = 0, pink = 0}

-- Auto-convert shards to crystals for a given color
local function autoConvert(color)
  while shards[color] >= SHARDS_PER_CRYSTAL do
    shards[color] = shards[color] - SHARDS_PER_CRYSTAL
    crystals[color] = crystals[color] + 1
  end
end

function currency.init()
  local d = progression.getCurrencyData()
  for _, name in ipairs(coin_utils.getShardNames()) do
    shards[name] = (d.shards and d.shards[name]) or 0
    crystals[name] = (d.crystals and d.crystals[name]) or 0
  end
end

function currency.save()
  progression.setCurrencyData({
    shards = shards,
    crystals = crystals,
  })
  progression.save()
end

function currency.startRun()
  for _, name in ipairs(coin_utils.getShardNames()) do
    run_shards[name] = 0
  end
end

-- Award shards for a merge. coin_count = number of coins consumed, coin_number = their number.
function currency.onMerge(coin_count, coin_number)
  local color = coin_utils.numberToShardColor(coin_number)
  local amount = coin_count * SHARDS_PER_COIN
  shards[color] = shards[color] + amount
  run_shards[color] = run_shards[color] + amount
  autoConvert(color)
  currency.save()
end

function currency.getShards()
  return shards
end

function currency.getCrystals()
  return crystals
end

function currency.getRunShards()
  return run_shards
end

-- Spend crystals of a color. Returns true if affordable.
function currency.spendCrystals(color, amount)
  if crystals[color] and crystals[color] >= amount then
    crystals[color] = crystals[color] - amount
    currency.save()
    return true
  end
  return false
end

-- Add crystals (e.g. from house production)
function currency.addCrystal(color, amount)
  amount = amount or 1
  if crystals[color] then
    crystals[color] = crystals[color] + amount
  end
end

function currency.getShardsPerCrystal()
  return SHARDS_PER_CRYSTAL
end

return currency
