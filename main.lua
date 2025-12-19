local utils = require("utils")
local game = require("game")
local layout = require("layout")
local screens = require("screens")
local animation = require("animation")

utils.debug_stuff1()

local selection = nil            -- { box = int, pack = {coin1, ...} } while carrying

-- layout constants (from layout.lua)
local VW, VH = layout.VW, layout.VH
local TOP_Y = layout.GRID_TOP_Y
local COIN_R = layout.COIN_R
local ROW_STEP = layout.ROW_STEP
local COLUMN_STEP = layout.COLUMN_STEP
local GRID_X_OFFSET = layout.GRID_LEFT_OFFSET

-- Game Window
local canvas                     -- where we render the game
local scale, ox, oy = 1, 0, 0   -- scale and offsets (for letterboxing)

local function recalcScale(w, h)
  -- preserve aspect ratio by letterboxing
  local sx, sy = w / VW, h / VH
  scale = math.min(sx, sy)
  local drawW, drawH = math.floor(VW * scale + 0.5), math.floor(VH * scale + 0.5)
  ox = math.floor((w - drawW) / 2)
  oy = math.floor((h - drawH) / 2)
end


local function window_stuff()
  love.graphics.setDefaultFilter("nearest", "nearest")
  canvas = love.graphics.newCanvas(VW, VH)
  canvas:setFilter("nearest","nearest")

  -- Apply window scale from layout
  local windowW = math.floor(VW * layout.WINDOW_SCALE)
  local windowH = math.floor(VH * layout.WINDOW_SCALE)
  love.window.setMode(windowW, windowH, {resizable = true, minwidth = 270, minheight = 600})

  local w, h = love.graphics.getDimensions()
  recalcScale(w, h)
end

function loading_snds()
  bgnd_music = love.audio.newSource("bgnd_music/storm-clouds-purpple-cat(chosic.com).mp3", "stream")
  love.audio.play(bgnd_music)

  pick_up_snd = love.audio.newSource("sfx/chip-lay-2.ogg", "static")
  merge_snd = love.audio.newSource("sfx/chips-handle-1.ogg", "static")
  add_snd = love.audio.newSource("sfx/chips-collide-2.ogg", "static")
end

-- ========= Hit testing: which box did we click? =========
-- Your columns are centered at x = GRID_X_OFFSET + COLUMN_STEP * column (1-based).
-- We'll snap clicks to the nearest column and also gate by the vertical box area.
local function box_at(x, y)
  -- snap X to nearest column (accounting for grid offset)
  local col = math.floor(((x - GRID_X_OFFSET) / COLUMN_STEP) + 0.5)
  if col < 1 or col > #boxes then return nil end

  -- only accept clicks within the vertical bounds where boxes are drawn
  local y_min = TOP_Y - 10
  if y < y_min-10 or y > top_y+10 then return nil end

  return col
end

-- Button images (loaded in love.load)
local addButtonImage, addButtonPressedImage
local mergeButtonImage, mergeButtonPressedImage
local BUTTON_SCALE = 10  -- Scale up the small pixel art buttons
local BUTTON_SPACING = 40  -- Gap between buttons

-- Button positions (calculated after images load)
local ADD_BUTTON_X, ADD_BUTTON_Y
local MERGE_BUTTON_X, MERGE_BUTTON_Y
local BUTTON_WIDTH, BUTTON_HEIGHT

-- Button animation state
local buttonState = {
  add = { pressed = false, scale = 1.0, targetScale = 1.0 },
  merge = { pressed = false, scale = 1.0, targetScale = 1.0 }
}
local BUTTON_PRESS_SCALE = 0.85  -- Scale when pressed
local BUTTON_ANIM_SPEED = 12     -- Animation speed (higher = faster)

--------------------------------------------------------------------------------
-- Drawing functions (must be defined before game_screen uses them)
--------------------------------------------------------------------------------

local BG_SCALE = 3  -- Background image scale factor
local bgNumber = 60  -- Current background number (1-91)

local function loadBackground(num)
  bgNumber = num
  bgImage = love.graphics.newImage("assets/background/Color/Picture/color_background_" .. num .. ".png")
  bgImage:setWrap("repeat", "repeat")
end

local function draw_background()
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

local function draw_hint()
  love.graphics.setColor(1,1,1)
  love.graphics.printf("Points = Combo * amount of coins in stack!", 0, layout.HINT_Y, VW, "center")
end

local function draw_points()
  love.graphics.setColor(1,1,1)
  love.graphics.printf("Points: " .. game.getState().points, 0, layout.POINTS_Y, VW, "center")
end

local function draw_all_coins()
  local column = 1
  local row    = 1

  -- Get sprite dimensions for scaling
  local imgW, imgH = ballImage:getDimensions()
  local spriteScale = (COIN_R * 2) / imgW

  for i, c in ipairs(boxes) do
    for j, color in ipairs(c) do
      column = i
      row    = j
      local col = game.getState().COLORS[color] or {1,1,1}
      love.graphics.setColor(col)

      local x = GRID_X_OFFSET + COLUMN_STEP * column
      local y = TOP_Y + ROW_STEP * row
      -- Draw sprite centered at (x, y), tinted by current color
      love.graphics.draw(ballImage, x, y, 0, spriteScale, spriteScale, imgW/2, imgH/2)
    end
  end
end

local function draw_all_boxes()
  local color = {1,1,1}
  love.graphics.setColor(color)
  local x, y
  for column = 1, #boxes do
    for row = 1, game.getState().BOX_ROWS do
      x = GRID_X_OFFSET + COLUMN_STEP * column
      y = TOP_Y + ROW_STEP * row
      love.graphics.rectangle("line", x-COIN_R-2, y-COIN_R-2, COIN_R*2+4, COIN_R*2+4, 2, 2, 8)
    end
  end

  top_x = x
  top_y = y
end

local function draw_merge_button()
  love.graphics.setColor(1,1,1)
  local state = buttonState.merge
  local img = state.pressed and mergeButtonPressedImage or mergeButtonImage
  local s = BUTTON_SCALE * state.scale
  -- Draw centered (scale from center)
  local imgW, imgH = mergeButtonImage:getDimensions()
  local centerX = MERGE_BUTTON_X + (BUTTON_WIDTH / 2)
  local centerY = MERGE_BUTTON_Y + (BUTTON_HEIGHT / 2)
  love.graphics.draw(img, centerX, centerY, 0, s, s, imgW/2, imgH/2)
end

local function draw_add_coins_button()
  love.graphics.setColor(1,1,1)
  local state = buttonState.add
  local img = state.pressed and addButtonPressedImage or addButtonImage
  local s = BUTTON_SCALE * state.scale
  -- Draw centered (scale from center)
  local imgW, imgH = addButtonImage:getDimensions()
  local centerX = ADD_BUTTON_X + (BUTTON_WIDTH / 2)
  local centerY = ADD_BUTTON_Y + (BUTTON_HEIGHT / 2)
  love.graphics.draw(img, centerX, centerY, 0, s, s, imgW/2, imgH/2)
end

-- Update button animation scales
local function updateButtonAnimations(dt)
  for _, state in pairs(buttonState) do
    if state.scale ~= state.targetScale then
      local diff = state.targetScale - state.scale
      state.scale = state.scale + diff * BUTTON_ANIM_SPEED * dt
      -- Snap to target if close enough
      if math.abs(diff) < 0.01 then
        state.scale = state.targetScale
      end
    end
  end
end

--------------------------------------------------------------------------------
-- Game Screen (wrapped for screen system)
--------------------------------------------------------------------------------
game_screen = {}

function game_screen.enter()
  game.init()
  selection = nil
end

function game_screen.update(dt)
  merge_timer = game.update(dt)
  animation.update(dt)
  updateButtonAnimations(dt)
  -- Update background scroll
  bgScrollX = bgScrollX + bgScrollSpeedX * dt
  bgScrollY = bgScrollY + bgScrollSpeedY * dt
end

function game_screen.draw()
  draw_background()
  draw_hint()
  draw_points()

  if merge_timer > 0 then
    love.graphics.setColor(0, 1, 0)
    love.graphics.printf("Merged!", 0, layout.MERGED_MSG_Y, VW, "center")
  end

  draw_all_boxes()
  draw_all_coins()
  -- Draw animated coins on top
  animation.draw(ballImage, game.getState().COLORS)
  draw_merge_button()
  draw_add_coins_button()
end

function game_screen.keypressed(key, scancode, isrepeat)
  if key == "\\" then
    love.event.quit()
  end
  if key == "a" then
    BOX_ROWS = BOX_ROWS + 1
  end
  if key == "b" then
    name, color = next(Non_Active_Colors)
    if not name then return end
    COLORS[name] = color
    colors_str[#colors_str + 1] = name
    Non_Active_Colors[name] = nil
    table.insert(boxes, {})
  end
  if key == "space" then
    local newBg = bgNumber + 1
    if newBg > 91 then newBg = 1 end
    loadBackground(newBg)
  end
end

-- Helper to check if point is inside button
local function isInsideButton(x, y, btnX, btnY)
  return x >= btnX and x <= btnX + BUTTON_WIDTH and
         y >= btnY and y <= btnY + BUTTON_HEIGHT
end

function game_screen.mousepressed(x, y, button)
  if button ~= 1 then return end

  -- Block input during flight animation
  if animation.isFlying() then
    return
  end

  local bx = box_at(x, y)

  -- Check merge button
  if isInsideButton(x, y, MERGE_BUTTON_X, MERGE_BUTTON_Y) then
    buttonState.merge.pressed = true
    buttonState.merge.targetScale = BUTTON_PRESS_SCALE
    return
  end

  -- Check add button
  if isInsideButton(x, y, ADD_BUTTON_X, ADD_BUTTON_Y) then
    buttonState.add.pressed = true
    buttonState.add.targetScale = BUTTON_PRESS_SCALE
    return
  end

  if not bx then return end

  if not animation.isHovering() then
    -- Pick up: Start hover animation
    local pack = game.pick_coin_from_box(bx, {remove = true})
    if pack == nil or #pack == 0 then
      return
    end
    selection = { box = bx, pack = pack }
    animation.startHover(pack, bx)
    pick_up_snd:play()
  else
    -- Place: Start flight animation
    local pack = animation.getHoveringCoins()

    -- Check if destination box has room
    if #game.getState().boxes[bx] + #pack > game.getState().BOX_ROWS then
      BOX_IS_FULL = true
      return
    end

    -- Calculate destination slot (where first coin will land)
    local dest_slot = #game.getState().boxes[bx] + 1

    -- Start flight with per-coin callback (adds each coin as it lands)
    animation.startFlight(bx, dest_slot,
      -- Final callback: when all coins have landed
      function()
        selection = nil
      end,
      -- Per-coin callback: when each coin lands
      function(color, slot)
        table.insert(boxes[bx], color)
        love.audio.play(pick_up_snd)
      end
    )
  end
end

function game_screen.mousereleased(x, y, button)
  if button ~= 1 then return end

  -- Release merge button
  if buttonState.merge.pressed then
    buttonState.merge.pressed = false
    buttonState.merge.targetScale = 1.0
    -- Trigger action if released over button
    if isInsideButton(x, y, MERGE_BUTTON_X, MERGE_BUTTON_Y) and not animation.isAnimating() then
      game.merge()
      merge_snd:play()
    end
  end

  -- Release add button
  if buttonState.add.pressed then
    buttonState.add.pressed = false
    buttonState.add.targetScale = 1.0
    -- Trigger action if released over button
    if isInsideButton(x, y, ADD_BUTTON_X, ADD_BUTTON_Y) and not animation.isAnimating() then
      game.add_coins()
      add_snd:play()
    end
  end
end

function love.load()
  loading_snds()
  math.randomseed(os.time())
  window_stuff()

  -- background scroll
  loadBackground(bgNumber)

  -- coin sprite
  ballImage = love.graphics.newImage("assets/ball.png")

  -- button images
  addButtonImage = love.graphics.newImage("assets/add_button.png")
  addButtonPressedImage = love.graphics.newImage("assets/add_button_pressed.png")
  mergeButtonImage = love.graphics.newImage("assets/merge_button.png")
  mergeButtonPressedImage = love.graphics.newImage("assets/merge_button_pressed.png")

  -- Calculate button dimensions and positions (side by side, centered)
  local btnW, btnH = addButtonImage:getDimensions()
  BUTTON_WIDTH = btnW * BUTTON_SCALE
  BUTTON_HEIGHT = btnH * BUTTON_SCALE
  local totalWidth = BUTTON_WIDTH * 2 + BUTTON_SPACING
  local startX = (VW - totalWidth) / 2
  ADD_BUTTON_X = startX
  ADD_BUTTON_Y = layout.BUTTON_AREA_Y
  MERGE_BUTTON_X = startX + BUTTON_WIDTH + BUTTON_SPACING
  MERGE_BUTTON_Y = layout.BUTTON_AREA_Y

  bgScrollX, bgScrollY = 0, 0           -- scroll offsets
  bgScrollSpeedX = 10                   -- pixels per second (texture space)
  bgScrollSpeedY = 5

  --fonts
  love.graphics.setDefaultFilter("nearest", "nearest", 1) -- affects images, fonts, canvases
  font = love.graphics.newFont("comic shanns.otf", layout.FONT_SIZE)
  love.graphics.setFont(font)

  -- Register and start with mode selection screen
  screens.register("game", game_screen)
  screens.switch("mode_select")
end

function love.resize(w, h)
  recalcScale(w, h)
end

-- Convert window/screen coords to virtual game coords
local function toGame(x, y)
  return (x - ox) / scale, (y - oy) / scale
end

function love.update(dt)
  screens.update(dt)
end

function love.draw()
  love.graphics.setCanvas(canvas)
  love.graphics.clear()

  -- Delegate drawing to current screen
  screens.draw()

  -- Canvas stuff
  love.graphics.setCanvas()

  -- Blit the canvas to the actual window with letterboxing
  love.graphics.push("all")
  love.graphics.origin()
  love.graphics.translate(ox, oy)
  love.graphics.scale(scale, scale)
  love.graphics.draw(canvas, 0, 0)
  love.graphics.pop()
end

function love.keypressed(key, scancode, isrepeat)
  screens.keypressed(key, scancode, isrepeat)
end

function love.mousepressed(x, y, button)
  x, y = toGame(x, y)
  screens.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
  x, y = toGame(x, y)
  screens.mousereleased(x, y, button)
end

utils.debug_stuff2()
