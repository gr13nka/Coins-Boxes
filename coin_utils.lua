-- coin_utils.lua
-- Utility functions for coin colors and operations in 2048 mode
-- Uses 5 cycling shard colors: red, green, purple, blue, pink

local coin_utils = {}

-- 5 shard colors that cycle with coin number
local SHARD_RGB = {
  {0.9, 0.2, 0.2},   -- red    (1, 6, 11...)
  {0.2, 0.8, 0.3},   -- green  (2, 7, 12...)
  {0.6, 0.2, 0.8},   -- purple (3, 8, 13...)
  {0.2, 0.4, 0.9},   -- blue   (4, 9, 14...)
  {0.9, 0.4, 0.7},   -- pink   (5, 10, 15...)
}
local SHARD_NAMES = {"red", "green", "purple", "blue", "pink"}

-- Per-color fruit images (loaded by coin_utils.loadImages)
local SHARD_IMAGES = {}

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

-- Load per-color fruit images (call once during love.load)
function coin_utils.loadImages()
  SHARD_IMAGES = {
    love.graphics.newImage("assets/Red.png"),     -- red    (1, 6, 11...)
    love.graphics.newImage("assets/Green.png"),    -- green  (2, 7, 12...)
    love.graphics.newImage("assets/Purple.png"),   -- purple (3, 8, 13...)
    love.graphics.newImage("assets/Blue.png"),     -- blue   (4, 9, 14...)
    love.graphics.newImage("assets/Pink.png"),     -- pink   (5, 10, 15...)
  }
end

-- Map a coin number to its fruit image via 5-color cycle
function coin_utils.numberToImage(number)
  return SHARD_IMAGES[((number - 1) % 5) + 1]
end

-- Map a shard color name to its fruit image
function coin_utils.colorNameToImage(color_name)
  for i, name in ipairs(SHARD_NAMES) do
    if name == color_name then return SHARD_IMAGES[i] end
  end
  return SHARD_IMAGES[1]
end

-- Get the loaded images array
function coin_utils.getImages()
  return SHARD_IMAGES
end

return coin_utils
