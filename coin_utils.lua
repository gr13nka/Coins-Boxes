-- coin_utils.lua
-- Utility functions for coin colors and operations in 2048 mode
-- Uses 5 cycling shard colors: red, green, purple, blue, pink

local coin_utils = {}

-- 5 shard colors that cycle with coin number (forest cave palette)
local SHARD_RGB = {
  {0.35, 0.65, 0.25},  -- moss   (1, 6, 11...)
  {0.55, 0.60, 0.50},  -- stone  (2, 7, 12...)
  {0.60, 0.40, 0.22},  -- bark   (3, 8, 13...)
  {0.25, 0.50, 0.40},  -- fern   (4, 9, 14...)
  {0.72, 0.78, 0.55},  -- lichen (5, 10, 15...)
}
local SHARD_NAMES = {"red", "green", "purple", "blue", "pink"}

-- Map a number (1-50) to RGB color via 5-color cycling
function coin_utils.numberToColor(number, max_number)
  return SHARD_RGB[((number - 1) % 5) + 1]
end

-- Map a number to its shard color name
function coin_utils.numberToShardColor(number)
  return SHARD_NAMES[((number - 1) % 5) + 1]
end

-- Get RGB for a shard color name
function coin_utils.getShardRGB(color_name)
  for i, name in ipairs(SHARD_NAMES) do
    if name == color_name then
      return SHARD_RGB[i]
    end
  end
  return {1, 1, 1}
end

-- Get the ordered list of shard color names
function coin_utils.getShardNames()
  return SHARD_NAMES
end

-- Check if a value is a coin object (table with number property)
function coin_utils.isCoin(value)
    return type(value) == "table" and value.number ~= nil
end

-- Get number from a coin object
function coin_utils.getCoinNumber(coin)
    if coin_utils.isCoin(coin) then
        return coin.number
    end
    return nil
end

-- Map a coin number to its cycle tier (0 = coins 1-5, 1 = coins 6-10, etc.)
function coin_utils.numberToCycle(number)
  return math.floor((number - 1) / 5)
end

-- Create a new coin object
function coin_utils.createCoin(number)
    return {number = number}
end

return coin_utils
