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
local bgImage
local bgNumber = 60
local bgScrollX, bgScrollY = 0, 0
local BG_SCALE = 3

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

--- Load a background image by number
-- @param num Background number (1-91)
function graphics.loadBackground(num)
  bgNumber = num
  bgImage = love.graphics.newImage("assets/background/Color/Picture/color_background_" .. num .. ".png")
  bgImage:setWrap("repeat", "repeat")
end

--- Get current background number
function graphics.getBackgroundNumber()
  return bgNumber
end

--- Cycle to next background
function graphics.nextBackground()
  local newBg = bgNumber + 1
  if newBg > 91 then newBg = 1 end
  graphics.loadBackground(newBg)
end

--- Update background scroll position
-- @param dt Delta time
-- @param speedX Scroll speed X (pixels per second in texture space)
-- @param speedY Scroll speed Y (pixels per second in texture space)
function graphics.updateBackgroundScroll(dt, speedX, speedY)
  bgScrollX = bgScrollX + speedX * dt
  bgScrollY = bgScrollY + speedY * dt
end

--- Draw the scrolling background
function graphics.drawBackground()
  love.graphics.setColor(1, 1, 1)
  local imgW, imgH = bgImage:getDimensions()
  -- Sample less of the texture since we're scaling it up
  local bgQuad = love.graphics.newQuad(
    bgScrollX / BG_SCALE, bgScrollY / BG_SCALE,
    VW / BG_SCALE, VH / BG_SCALE,
    imgW, imgH
  )
  love.graphics.draw(bgImage, bgQuad, 0, 0, 0, BG_SCALE, BG_SCALE)
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

-- Helper: draw a single 2048 coin at (x, y)
local function drawCoin2048(imgW, imgH, spriteScale, font, x, y, num, MAX_NUMBER)
  local col = coin_utils.numberToColor(num, MAX_NUMBER)
  love.graphics.setColor(col)
  love.graphics.draw(ballImage, x, y, 0, spriteScale, spriteScale, imgW/2, imgH/2)
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(font)
  local num_str = tostring(num)
  local text_width = font:getWidth(num_str)
  local text_height = font:getHeight()
  love.graphics.print(num_str, x - text_width / 2, y - text_height / 2)
end

--- Draw all coins for 2048 mode (with numbers)
-- @param boxes Array of box arrays containing {number=N} coin objects
-- @param MAX_NUMBER Maximum possible coin number (for color mapping)
-- @param font Font for drawing numbers
-- @param skipBoxes Optional table of box indices to skip (for merge animation)
-- @return top_x, top_y The coordinates of the last drawn cell
function graphics.drawCoins2048(boxes, MAX_NUMBER, font, skipBoxes)
  local imgW, imgH = ballImage:getDimensions()
  local spriteScale = (COIN_R * 2) / imgW
  local x, y
  skipBoxes = skipBoxes or {}

  if layout.TWO_LAYER then
    -- Two-pass rendering: back layer first, then front layer (proper z-order)
    for layer = 0, 1 do
      for column, box in ipairs(boxes) do
        if not skipBoxes[column] then
          for slot, coin in ipairs(box) do
            local slot_layer = (slot - 1) % 2
            if slot_layer == layer then
              local num = coin_utils.getCoinNumber(coin)
              x, y = layout.slotPosition(column, slot)
              drawCoin2048(imgW, imgH, spriteScale, font, x, y, num, MAX_NUMBER)
            end
          end
        end
      end
    end
  else
    for column, box in ipairs(boxes) do
      if not skipBoxes[column] then
        for row, coin in ipairs(box) do
          local num = coin_utils.getCoinNumber(coin)
          x, y = layout.slotPosition(column, row)
          drawCoin2048(imgW, imgH, spriteScale, font, x, y, num, MAX_NUMBER)
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

--- Draw box grid for 2048 mode (with shake effect)
-- @param boxes Array of boxes (for column count)
-- @param BOX_ROWS Number of rows per box
-- @param shakeState Table with {active, box_index, time, duration} for shake animation
-- @return top_x, top_y The coordinates of the last drawn cell
function graphics.drawBoxes2048(boxes, BOX_ROWS, shakeState)
  local x, y
  local overlapping = ROW_STEP < COIN_R * 2
  local two_layer = layout.TWO_LAYER

  for column = 1, #boxes do
    -- Apply shake offset if this box is shaking
    local shake_offset = 0
    if shakeState.active and shakeState.box_index == column then
      shake_offset = math.sin(shakeState.time * 50) * 8 * (1 - shakeState.time / shakeState.duration)
    end

    -- Red color if shaking, white otherwise
    if shakeState.active and shakeState.box_index == column then
      love.graphics.setColor(1, 0.3, 0.3)
    else
      love.graphics.setColor(1, 1, 1)
    end

    x = GRID_X_OFFSET + COLUMN_STEP * column + shake_offset

    if two_layer then
      -- Two-layer mode: single wide container per column
      local visual_rows = math.ceil(BOX_ROWS / 2)
      local lx = layout.LAYER_OFFSET_X
      local ly = layout.LAYER_OFFSET_Y
      local top = TOP_Y + ROW_STEP - COIN_R - ly - 2
      local height = (visual_rows - 1) * ROW_STEP + COIN_R * 2 + ly * 2 + 4
      local width = COIN_R * 2 + lx * 2 + 4
      love.graphics.rectangle("line", x - COIN_R - lx - 2, top, width, height, 4, 4, 8)
      y = TOP_Y + ROW_STEP * visual_rows
    elseif overlapping then
      -- Stack mode: single tall column container
      local top = TOP_Y + ROW_STEP - COIN_R - 2
      local height = (BOX_ROWS - 1) * ROW_STEP + COIN_R * 2 + 4
      local width = COIN_R * 2 + 4
      love.graphics.rectangle("line", x - COIN_R - 2, top, width, height, 4, 4, 8)
      y = TOP_Y + ROW_STEP * BOX_ROWS
    else
      -- Normal mode: draw individual cell rectangles
      for row = 1, BOX_ROWS do
        y = TOP_Y + ROW_STEP * row
        love.graphics.rectangle("line", x-COIN_R-2, y-COIN_R-2, COIN_R*2+4, COIN_R*2+4, 2, 2, 8)
      end
    end
  end

  return x, y
end

return graphics
