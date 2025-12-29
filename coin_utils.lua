-- coin_utils.lua
-- Utility functions for coin colors and operations in 2048 mode

local coin_utils = {}

-- Convert HSL to RGB (all values 0-1)
-- h: hue (0-1), s: saturation (0-1), l: lightness (0-1)
function coin_utils.hslToRgb(h, s, l)
    if s == 0 then
        return l, l, l
    end

    local function hueToRgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1/6 then return p + (q - p) * 6 * t end
        if t < 1/2 then return q end
        if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
        return p
    end

    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q

    local r = hueToRgb(p, q, h + 1/3)
    local g = hueToRgb(p, q, h)
    local b = hueToRgb(p, q, h - 1/3)

    return r, g, b
end

-- Map a number (1-50) to a unique color
-- Uses golden angle (137.5 degrees) for maximum distinction between adjacent numbers
function coin_utils.numberToColor(number, max_number)
    max_number = max_number or 50

    -- Golden angle in turns (137.5 degrees / 360 = 0.381966...)
    local golden_angle = 0.381966

    -- Each number gets a hue offset by golden angle from the previous
    -- This ensures adjacent numbers have very different colors
    local hue = ((number - 1) * golden_angle) % 1.0

    -- Vary saturation and lightness slightly based on number for even more distinction
    local saturation = 0.7 + (number % 3) * 0.1  -- 0.7, 0.8, or 0.9
    local lightness = 0.5 + (number % 2) * 0.1   -- 0.5 or 0.6

    local r, g, b = coin_utils.hslToRgb(hue, saturation, lightness)
    return {r, g, b}
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

-- Create a new coin object
function coin_utils.createCoin(number)
    return {number = number}
end

return coin_utils
