-- graphics.lua
-- Game rendering: coins, boxes, background (NOT UI buttons)

local layout = require("layout")
local coin_utils = require("coin_utils")

local graphics = {}

-- Layout constants
local VW, VH = layout.VW, layout.VH
local TOP_Y = layout.GRID_TOP_Y
local COIN_R = layout.COIN_R
local ROW_STEP = layout.ROW_STEP
local COLUMN_STEP = layout.COLUMN_STEP
local GRID_X_OFFSET = layout.GRID_LEFT_OFFSET

-- Module state
local ballImage
local ballImgW, ballImgH  -- cached ball image dimensions

-- Dimension cache for fruit images (lazy-fill, keyed by image userdata)
local dimCache = {}

-- Font metric caches
local fontHeightCache = {}                -- fontHeightCache[font] = height
local fontWidthCache = {}                 -- fontWidthCache[font][num_str] = width

--- Refresh cached layout values (call after layout.applyMetrics)
function graphics.updateMetrics()
  TOP_Y = layout.GRID_TOP_Y
  COIN_R = layout.COIN_R
  ROW_STEP = layout.ROW_STEP
  COLUMN_STEP = layout.COLUMN_STEP
  GRID_X_OFFSET = layout.GRID_LEFT_OFFSET
end

--- Initialize the graphics module
-- @param ball_img The ball/coin sprite image
function graphics.init(ball_img)
  ballImage = ball_img
  ballImgW, ballImgH = ball_img:getDimensions()
end

--- Get the ball image (for animation module)
function graphics.getBallImage()
  return ballImage
end

-- Get cached dimensions for an image (lazy-fill)
local function getCachedDims(img)
  local d = dimCache[img]
  if d then return d[1], d[2] end
  local w, h = img:getDimensions()
  dimCache[img] = {w, h}
  return w, h
end

-- Get cached font height
local function getCachedFontHeight(font)
  local h = fontHeightCache[font]
  if h then return h end
  h = font:getHeight()
  fontHeightCache[font] = h
  return h
end

-- Get cached font width for a number string
local function getCachedFontWidth(font, num_str)
  local fc = fontWidthCache[font]
  if not fc then
    fc = {}
    fontWidthCache[font] = fc
  end
  local w = fc[num_str]
  if w then return w end
  w = font:getWidth(num_str)
  fc[num_str] = w
  return w
end

--- Draw a solid color background
function graphics.drawBackground()
  love.graphics.clear(0.12, 0.12, 0.18)
end

--- Draw all coins for classic mode
-- @param boxes Array of box arrays containing color strings
-- @param COLORS Table mapping color names to RGB values
-- @param skipBoxes Optional table of box indices to skip (for merge animation)
-- @return top_x, top_y The coordinates of the last drawn cell (for hit testing bounds)
function graphics.drawCoins(boxes, COLORS, skipBoxes)
  local spriteScale = (COIN_R * 2) / ballImgW
  local x, y
  skipBoxes = skipBoxes or {}

  for i, box in ipairs(boxes) do
    -- Skip boxes that are being animated
    if not skipBoxes[i] then
      for j, color in ipairs(box) do
        local col = COLORS[color] or {1, 1, 1}
        love.graphics.setColor(col)

        x = GRID_X_OFFSET + COLUMN_STEP * i
        y = TOP_Y + ROW_STEP * j
        love.graphics.draw(ballImage, x, y, 0, spriteScale, spriteScale, ballImgW/2, ballImgH/2)
      end
    end
  end

  return x, y
end

-- Draw a single 2048 coin at (x, y)
-- Uses fruit images or tinted ball depending on layout.USE_FRUIT_IMAGES
-- Also used by animation.lua for consistent rendering
-- hideNumber: optional, if true skip drawing the number text
local RING_COLORS = {
  {0.85, 0.85, 0.9},   -- cycle 1: silver
  {1.0, 0.85, 0.25},   -- cycle 2: gold
  {0.3, 0.9, 1.0},     -- cycle 3: cyan/diamond
  {0.9, 0.3, 0.9},     -- cycle 4: magenta
}

function graphics.drawCoin2048(font, x, y, num, MAX_NUMBER, scaleOverride, hideNumber)
  local imgW, imgH, img, scale
  if layout.USE_FRUIT_IMAGES then
    img = coin_utils.numberToImage(num)
    imgW, imgH = getCachedDims(img)
    scale = (COIN_R * 2) / imgW
    if scaleOverride then scale = scale * scaleOverride end
    love.graphics.setColor(1, 1, 1)
  else
    img = ballImage
    imgW, imgH = ballImgW, ballImgH
    scale = (COIN_R * 2) / imgW
    if scaleOverride then scale = scale * scaleOverride end
    local col = coin_utils.numberToColor(num, MAX_NUMBER)
    love.graphics.setColor(col)
  end
  love.graphics.draw(img, x, y, 0, scale, scale, imgW / 2, imgH / 2)
  -- Cycle tier ring border
  local cycle = coin_utils.numberToCycle(num)
  if cycle > 0 then
    local rc = RING_COLORS[cycle] or {1.0, 1.0, 1.0}
    local ring_lw = 2 + math.min(cycle - 1, 3) * 0.5
    local ring_r = COIN_R * (scaleOverride or 1)
    love.graphics.setColor(rc)
    love.graphics.setLineWidth(ring_lw)
    love.graphics.circle("line", x, y, ring_r)
    love.graphics.setLineWidth(1)
  end
  -- Number text (skip if hideNumber)
  if not hideNumber then
    if layout.USE_FRUIT_IMAGES then
      love.graphics.setColor(0, 0, 0)
    else
      love.graphics.setColor(1, 1, 1)
    end
    love.graphics.setFont(font)
    local num_str = tostring(num)
    local text_width = getCachedFontWidth(font, num_str)
    local text_height = getCachedFontHeight(font)
    love.graphics.print(num_str, x - text_width / 2, y - text_height / 2)
  end
end

--- Draw all coins for 2048 mode (with numbers)
-- @param boxes Array of box arrays containing {number=N} coin objects
-- @param MAX_NUMBER Maximum possible coin number (for color mapping)
-- @param font Font for drawing numbers
-- @param skipBoxes Optional table of box indices to skip (for merge animation)
-- @return top_x, top_y The coordinates of the last drawn cell
function graphics.drawCoins2048(boxes, MAX_NUMBER, font, skipBoxes)
  local x, y
  skipBoxes = skipBoxes or {}

  for column, box in ipairs(boxes) do
    if not skipBoxes[column] then
      local bottom_slot = #box
      for row, coin in ipairs(box) do
        local num = coin_utils.getCoinNumber(coin)
        x, y = layout.slotPosition(column, row)
        graphics.drawCoin2048(font, x, y, num, MAX_NUMBER, nil, row ~= bottom_slot)
      end
    end
  end

  return x, y
end

--- Draw box grid for classic mode
-- @param boxes Array of boxes (for column count)
-- @param BOX_ROWS Number of rows per box
-- @return top_x, top_y The coordinates of the last drawn cell
function graphics.drawBoxes(boxes, BOX_ROWS)
  love.graphics.setColor(1, 1, 1)
  local x, y

  for column = 1, #boxes do
    for row = 1, BOX_ROWS do
      x = GRID_X_OFFSET + COLUMN_STEP * column
      y = TOP_Y + ROW_STEP * row
      love.graphics.rectangle("line", x-COIN_R-2, y-COIN_R-2, COIN_R*2+4, COIN_R*2+4, 2, 2, 8)
    end
  end

  return x, y
end

--- Draw a single box tray at (bx, by) with given dimensions
local function drawTray(bx, by, box_w, box_h, BOX_ROWS, is_shaking)
  -- Body fill
  if is_shaking then
    love.graphics.setColor(0.35, 0.12, 0.12, 0.45)
  else
    love.graphics.setColor(0.22, 0.24, 0.30, 0.35)
  end
  love.graphics.rectangle("fill", bx, by, box_w, box_h, 4, 4)

  -- Horizontal divider lines between slots
  if is_shaking then
    love.graphics.setColor(0.6, 0.2, 0.2, 0.4)
  else
    love.graphics.setColor(0.38, 0.40, 0.48, 0.3)
  end
  love.graphics.setLineWidth(1)
  for row = 1, BOX_ROWS - 1 do
    local gy = by + ROW_STEP * row + ROW_STEP * 0.5
    love.graphics.line(bx, gy, bx + box_w, gy)
  end

  -- Border outline
  if is_shaking then
    love.graphics.setColor(0.8, 0.25, 0.25, 0.5)
  else
    love.graphics.setColor(0.38, 0.40, 0.48, 0.4)
  end
  love.graphics.rectangle("line", bx, by, box_w, box_h, 4, 4)
end

--- Draw box grid for 2048 mode (3×5 grid of box trays)
-- @param boxes Array of boxes (for column count)
-- @param BOX_ROWS Number of rows per box
-- @param shakeState Table with {active, box_index, time, duration} for shake animation
-- @return top_x, top_y The coordinates of the last drawn cell
function graphics.drawBoxes2048(boxes, BOX_ROWS, shakeState)
  local x, y

  for column = 1, #boxes do
    local shake_offset = 0
    if shakeState.active and shakeState.box_index == column then
      shake_offset = math.sin(shakeState.time * 50) * 8 * (1 - shakeState.time / shakeState.duration)
    end

    local bx, by = layout.boxPosition(column)
    bx = bx + shake_offset
    x = bx + layout.BOX_W
    y = by + layout.BOX_H

    local is_shaking = shakeState.active and shakeState.box_index == column
    drawTray(bx, by, layout.BOX_W, layout.BOX_H, BOX_ROWS, is_shaking)
  end

  return x, y
end

return graphics
