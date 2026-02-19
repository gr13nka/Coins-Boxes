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
end

--- Get the ball image (for animation module)
function graphics.getBallImage()
  return ballImage
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
  local imgW, imgH = ballImage:getDimensions()
  local spriteScale = (COIN_R * 2) / imgW
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
        love.graphics.draw(ballImage, x, y, 0, spriteScale, spriteScale, imgW/2, imgH/2)
      end
    end
  end

  return x, y
end

-- Draw a single 2048 coin at (x, y)
-- Uses fruit images or tinted ball depending on layout.USE_FRUIT_IMAGES
-- Also used by animation.lua for consistent rendering
-- hideNumber: optional, if true skip drawing the number text
function graphics.drawCoin2048(font, x, y, num, MAX_NUMBER, scaleOverride, hideNumber)
  local imgW, imgH, img, scale
  if layout.USE_FRUIT_IMAGES then
    img = coin_utils.numberToImage(num)
    imgW, imgH = img:getDimensions()
    scale = (COIN_R * 2) / imgW
    if scaleOverride then scale = scale * scaleOverride end
    love.graphics.setColor(1, 1, 1)
  else
    img = ballImage
    imgW, imgH = img:getDimensions()
    scale = (COIN_R * 2) / imgW
    if scaleOverride then scale = scale * scaleOverride end
    local col = coin_utils.numberToColor(num, MAX_NUMBER)
    love.graphics.setColor(col)
  end
  love.graphics.draw(img, x, y, 0, scale, scale, imgW / 2, imgH / 2)
  -- Number text (skip if hideNumber)
  if not hideNumber then
    if layout.USE_FRUIT_IMAGES then
      love.graphics.setColor(0, 0, 0)
    else
      love.graphics.setColor(1, 1, 1)
    end
    love.graphics.setFont(font)
    local num_str = tostring(num)
    local text_width = font:getWidth(num_str)
    local text_height = font:getHeight()
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

  if layout.TWO_LAYER then
    -- Two-pass rendering: back layer first, then front layer (proper z-order)
    for layer = 0, 1 do
      for column, box in ipairs(boxes) do
        if not skipBoxes[column] then
          local bottom_slot = #box
          for slot, coin in ipairs(box) do
            local slot_layer = (slot - 1) % 2
            if slot_layer == layer then
              local num = coin_utils.getCoinNumber(coin)
              x, y = layout.slotPosition(column, slot)
              graphics.drawCoin2048(font, x, y, num, MAX_NUMBER, nil, slot ~= bottom_slot)
            end
          end
        end
      end
    end
  else
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

--- Draw coin tray for a single column
-- Thin-line rectangle with uniform horizontal groove lines
local function drawTray(x, col_top_y, BOX_ROWS, is_shaking)
  local tray_w = COIN_R * 2 + 4

  -- Tray edges align with coin image edges (center ± COIN_R)
  local tray_top = col_top_y + ROW_STEP * 0.5
  local tray_h   = ROW_STEP * BOX_ROWS

  -- Body fill
  if is_shaking then
    love.graphics.setColor(0.35, 0.12, 0.12, 0.45)
  else
    love.graphics.setColor(0.22, 0.24, 0.30, 0.35)
  end
  love.graphics.rectangle("fill", x - tray_w / 2, tray_top, tray_w, tray_h)

  -- Horizontal divider lines between cells (uniform thickness)
  if is_shaking then
    love.graphics.setColor(0.6, 0.2, 0.2, 0.4)
  else
    love.graphics.setColor(0.38, 0.40, 0.48, 0.3)
  end
  love.graphics.setLineWidth(1)
  for row = 1, BOX_ROWS - 1 do
    local gy = col_top_y + ROW_STEP * (row + 0.5)
    love.graphics.line(x - tray_w / 2, gy, x + tray_w / 2, gy)
  end

  -- Border outline (same thin line as dividers)
  if is_shaking then
    love.graphics.setColor(0.8, 0.25, 0.25, 0.5)
  else
    love.graphics.setColor(0.38, 0.40, 0.48, 0.4)
  end
  love.graphics.rectangle("line", x - tray_w / 2, tray_top, tray_w, tray_h)
end

--- Draw box grid for 2048 mode (coin-tube trays with shake effect)
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

    local col_x, col_top_y = layout.columnPosition(column)
    x = col_x + shake_offset
    y = col_top_y + ROW_STEP * BOX_ROWS

    local is_shaking = shakeState.active and shakeState.box_index == column
    drawTray(x, col_top_y, BOX_ROWS, is_shaking)
  end

  return x, y
end

return graphics
