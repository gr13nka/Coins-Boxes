-- game_dev_screen.lua
-- Dev test mode screen: single long box filled with "1" coins

local game_dev = require("game_dev")
local animation = require("animation")
local particles = require("particles")
local graphics = require("graphics")
local input = require("input")
local sound = require("sound")
local layout = require("layout")
local screens = require("screens")
local coin_utils = require("coin_utils")

local game_dev_screen = {}

-- Layout constants
local VW, VH = layout.VW, layout.VH
local COIN_R = layout.COIN_R
local ROW_STEP = layout.ROW_STEP

-- Screen-local state
local selection = nil

-- Background scroll speeds
local bgScrollSpeedX = 10
local bgScrollSpeedY = 5

-- Shake animation for invalid placement
local shakeState = {
  active = false,
  box_index = 0,
  time = 0,
  duration = 0.3
}

-- Button images and layout
local addButtonImage, addButtonPressedImage
local mergeButtonImage, mergeButtonPressedImage
local BUTTON_SCALE = 10
local BUTTON_SPACING = 40
local ADD_BUTTON_X, ADD_BUTTON_Y
local MERGE_BUTTON_X, MERGE_BUTTON_Y
local BUTTON_WIDTH, BUTTON_HEIGHT

-- Button animation state
local buttonState = {
  add = { pressed = false, scale = 1.0, targetScale = 1.0 },
  merge = { pressed = false, scale = 1.0, targetScale = 1.0 }
}
local BUTTON_PRESS_SCALE = 0.85
local BUTTON_ANIM_SPEED = 12

-- Fonts
local font
local coinNumberFont

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function game_dev_screen.init(assets)
  addButtonImage = assets.addButtonImage
  addButtonPressedImage = assets.addButtonPressedImage
  mergeButtonImage = assets.mergeButtonImage
  mergeButtonPressedImage = assets.mergeButtonPressedImage
  font = assets.font
  coinNumberFont = assets.coinNumberFont

  local btnW, btnH = addButtonImage:getDimensions()
  BUTTON_WIDTH = btnW * BUTTON_SCALE
  BUTTON_HEIGHT = btnH * BUTTON_SCALE
  local totalWidth = BUTTON_WIDTH * 2 + BUTTON_SPACING
  local startX = (VW - totalWidth) / 2
  ADD_BUTTON_X = startX
  ADD_BUTTON_Y = layout.BUTTON_AREA_Y
  MERGE_BUTTON_X = startX + BUTTON_WIDTH + BUTTON_SPACING
  MERGE_BUTTON_Y = layout.BUTTON_AREA_Y
end

--------------------------------------------------------------------------------
-- Drawing helpers
--------------------------------------------------------------------------------

local function draw_dev_info()
  local state = game_dev.getState()
  love.graphics.setColor(1, 1, 0)
  love.graphics.setFont(font)
  love.graphics.printf("DEV TEST MODE", 0, 50, VW, "center")
  love.graphics.setColor(1, 1, 1)
  local total_coins = 0
  local max_coins = state.BOX_ROWS * state.NUM_BOXES
  for _, box in ipairs(state.boxes) do
    total_coins = total_coins + #box
  end
  love.graphics.printf("Coins: " .. total_coins .. "/" .. max_coins,
    0, 100, VW, "center")
end

local function draw_points()
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(font)
  love.graphics.printf("Points: " .. game_dev.getState().points, 0, 150, VW, "center")
end

local function draw_merge_button()
  love.graphics.setColor(1, 1, 1)
  local state = buttonState.merge
  local img = state.pressed and mergeButtonPressedImage or mergeButtonImage
  local s = BUTTON_SCALE * state.scale
  local imgW, imgH = mergeButtonImage:getDimensions()
  local centerX = MERGE_BUTTON_X + (BUTTON_WIDTH / 2)
  local centerY = MERGE_BUTTON_Y + (BUTTON_HEIGHT / 2)
  love.graphics.draw(img, centerX, centerY, 0, s, s, imgW/2, imgH/2)
end

local function draw_add_coins_button()
  love.graphics.setColor(1, 1, 1)
  local state = buttonState.add
  local img = state.pressed and addButtonPressedImage or addButtonImage
  local s = BUTTON_SCALE * state.scale
  local imgW, imgH = addButtonImage:getDimensions()
  local centerX = ADD_BUTTON_X + (BUTTON_WIDTH / 2)
  local centerY = ADD_BUTTON_Y + (BUTTON_HEIGHT / 2)
  love.graphics.draw(img, centerX, centerY, 0, s, s, imgW/2, imgH/2)
end

local function updateButtonAnimations(dt)
  for _, state in pairs(buttonState) do
    if state.scale ~= state.targetScale then
      local diff = state.targetScale - state.scale
      state.scale = state.scale + diff * BUTTON_ANIM_SPEED * dt
      if math.abs(diff) < 0.01 then
        state.scale = state.targetScale
      end
    end
  end
end

-- Draw all boxes spanning the screen
local function drawDevBox()
  local state = game_dev.getState()

  for box_idx = 1, state.NUM_BOXES do
    -- Apply shake offset for this box if shaking
    local shake_offset = 0
    if shakeState.active and shakeState.box_index == box_idx then
      shake_offset = math.sin(shakeState.time * 50) * 8 * (1 - shakeState.time / shakeState.duration)
    end

    local box_center_x = state.getBoxCenterX(box_idx)

    -- Draw box slots
    for row = 1, state.BOX_ROWS do
      local x = box_center_x + shake_offset
      local y = state.TOP_Y + ROW_STEP * row

      if shakeState.active and shakeState.box_index == box_idx then
        love.graphics.setColor(1, 0.3, 0.3)
      else
        love.graphics.setColor(1, 1, 1)
      end

      love.graphics.rectangle("line", x-COIN_R-2, y-COIN_R-2, COIN_R*2+4, COIN_R*2+4, 2, 2, 8)
    end
  end
end

-- Draw coins in all boxes
local function drawDevCoins(skipBoxes)
  local state = game_dev.getState()
  local ballImage = graphics.getBallImage()
  local imgW, imgH = ballImage:getDimensions()
  local spriteScale = (COIN_R * 2) / imgW
  skipBoxes = skipBoxes or {}

  for box_idx, box in ipairs(state.boxes) do
    if not skipBoxes[box_idx] then
      local box_center_x = state.getBoxCenterX(box_idx)

      for row, coin in ipairs(box) do
        local num = coin_utils.getCoinNumber(coin)
        local col = coin_utils.numberToColor(num, state.MAX_NUMBER)

        local x = box_center_x
        local y = state.TOP_Y + ROW_STEP * row

        -- Draw coin sprite
        love.graphics.setColor(col)
        love.graphics.draw(ballImage, x, y, 0, spriteScale, spriteScale, imgW/2, imgH/2)

        -- Draw number on coin
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(coinNumberFont)
        local num_str = tostring(num)
        local text_width = coinNumberFont:getWidth(num_str)
        local text_height = coinNumberFont:getHeight()
        love.graphics.print(num_str, x - text_width / 2, y - text_height / 2)
      end
    end
  end
end

-- Check which box was clicked (returns box index or nil)
local function getClickedBox(x, y)
  local state = game_dev.getState()
  local box_top = state.TOP_Y + ROW_STEP - COIN_R - 10
  local box_bottom = state.TOP_Y + ROW_STEP * state.BOX_ROWS + COIN_R + 10

  -- Check Y bounds first
  if y < box_top or y > box_bottom then
    return nil
  end

  -- Check which column was clicked
  for box_idx = 1, state.NUM_BOXES do
    local box_center_x = state.getBoxCenterX(box_idx)
    local box_left = box_center_x - COIN_R - 10
    local box_right = box_center_x + COIN_R + 10

    if x >= box_left and x <= box_right then
      return box_idx
    end
  end

  return nil
end

--------------------------------------------------------------------------------
-- Screen lifecycle
--------------------------------------------------------------------------------

function game_dev_screen.enter()
  game_dev.init()
  selection = nil
  shakeState.active = false
end

function game_dev_screen.exit()
  -- Cleanup
end

function game_dev_screen.update(dt)
  game_dev.update(dt)
  animation.update(dt)
  particles.update(dt)
  updateButtonAnimations(dt)

  if shakeState.active then
    shakeState.time = shakeState.time + dt
    if shakeState.time >= shakeState.duration then
      shakeState.active = false
    end
  end

  graphics.updateBackgroundScroll(dt, bgScrollSpeedX, bgScrollSpeedY)
end

function game_dev_screen.draw()
  local state = game_dev.getState()

  -- Apply screen shake
  local shake_x, shake_y = animation.getScreenShake()
  if shake_x ~= 0 or shake_y ~= 0 then
    love.graphics.push()
    love.graphics.translate(shake_x, shake_y)
  end

  graphics.drawBackground()
  draw_dev_info()
  draw_points()

  -- Show merge message
  if state.merge_timer > 0 then
    love.graphics.setColor(0, 1, 0)
    love.graphics.setFont(font)
    love.graphics.printf("Merged!", 0, layout.MERGED_MSG_Y - 100, VW, "center")
  end

  drawDevBox()

  local skipBoxes = animation.getMergingBoxIndices()
  drawDevCoins(skipBoxes)

  -- Draw animations
  animation.draw(graphics.getBallImage(), nil, "2048", coinNumberFont)
  animation.drawMerge(graphics.getBallImage(), coinNumberFont)
  animation.drawDealing(graphics.getBallImage(), nil, coinNumberFont)

  particles.draw()

  draw_merge_button()
  draw_add_coins_button()

  if shake_x ~= 0 or shake_y ~= 0 then
    love.graphics.pop()
  end
end

function game_dev_screen.keypressed(key, scancode, isrepeat)
  if key == "\\" then
    love.event.quit()
  end
  if key == "escape" then
    screens.switch("mode_select")
  end
  if key == "space" then
    graphics.nextBackground()
  end
end

function game_dev_screen.mousepressed(x, y, button)
  if button ~= 1 then return end

  -- Block input during animation (except hover)
  if animation.isAnimating() and not animation.isHovering() then
    return
  end

  local state = game_dev.getState()

  -- Check merge button
  if input.isInsideButton(x, y, MERGE_BUTTON_X, MERGE_BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT) then
    buttonState.merge.pressed = true
    buttonState.merge.targetScale = BUTTON_PRESS_SCALE
    return
  end

  -- Check add button
  if input.isInsideButton(x, y, ADD_BUTTON_X, ADD_BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT) then
    buttonState.add.pressed = true
    buttonState.add.targetScale = BUTTON_PRESS_SCALE
    return
  end

  local clicked_box = getClickedBox(x, y)
  if not clicked_box then return end

  if not animation.isHovering() then
    -- Pick up coins from clicked box
    local pack = game_dev.pick_coin_from_box(clicked_box, {remove = true})
    if pack == nil or #pack == 0 then
      return
    end
    selection = { box = clicked_box, pack = pack }
    animation.startHover(pack, clicked_box)
    sound.playPickup()
  else
    -- Try to place coins in clicked box
    local pack = animation.getHoveringCoins()
    local source_box_idx = animation.getSourceBox()

    -- If clicking source box, return coins
    if clicked_box == source_box_idx then
      for _, coin in ipairs(pack) do
        game_dev.place_coin(clicked_box, coin)
      end
      animation.cancel()
      selection = nil
      sound.playPickup()
      return
    end

    -- Try to place in destination box
    local can_place, err_msg = game_dev.can_place(clicked_box, pack)
    if can_place then
      -- Calculate destination for flight animation
      local dest_slot = #state.boxes[clicked_box] + 1

      animation.startFlight(clicked_box, dest_slot,
        function()
          -- All coins landed
          selection = nil
        end,
        function(coin, box_idx, slot)
          -- Each coin landing
          game_dev.place_coin(box_idx, coin)
          sound.playPickup()
          local px = state.getBoxCenterX(box_idx)
          local py = state.TOP_Y + ROW_STEP * slot
          local num = coin_utils.getCoinNumber(coin)
          local col = coin_utils.numberToColor(num, state.MAX_NUMBER)
          particles.spawn(px, py, col)
        end,
        {dest_x = state.getBoxCenterX(clicked_box), top_y = state.TOP_Y}
      )
    else
      -- Invalid placement - shake the box
      shakeState.active = true
      shakeState.box_index = clicked_box
      shakeState.time = 0
      game_dev.setError(err_msg)
    end
  end
end

function game_dev_screen.mousereleased(x, y, button)
  if button ~= 1 then return end

  local state = game_dev.getState()

  -- Release merge button
  if buttonState.merge.pressed then
    buttonState.merge.pressed = false
    buttonState.merge.targetScale = 1.0
    if input.isInsideButton(x, y, MERGE_BUTTON_X, MERGE_BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT) and not animation.isAnimating() then
      local mergeable = game_dev.getMergeableBoxes()
      if #mergeable > 0 then
        animation.startMerge(mergeable,
          function() end,
          function(box_data)
            game_dev.executeMergeOnBox(box_data.box_idx)
            sound.playMerge()
          end,
          particles
        )
      end
    end
  end

  -- Release add button
  if buttonState.add.pressed then
    buttonState.add.pressed = false
    buttonState.add.targetScale = 1.0
    if input.isInsideButton(x, y, ADD_BUTTON_X, ADD_BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT) and not animation.isAnimating() then
      local coins_to_deal = game_dev.calculateCoinsToAdd()

      if #coins_to_deal > 0 then
        animation.startDealing(coins_to_deal, "2048",
          function() end,
          function(coin_data, box_idx, slot)
            game_dev.place_coin(box_idx, coin_data)
            sound.playPickup()
            local px = state.getBoxCenterX(box_idx)
            local py = state.TOP_Y + ROW_STEP * slot
            local num = coin_utils.getCoinNumber(coin_data)
            local col = coin_utils.numberToColor(num, state.MAX_NUMBER)
            particles.spawn(px, py, col)
          end,
          particles
        )
        sound.playAdd()
      end
    end
  end
end

return game_dev_screen
