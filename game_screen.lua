-- game_screen.lua
-- Classic mode gameplay screen

local game = require("game")
local animation = require("animation")
local particles = require("particles")
local graphics = require("graphics")
local input = require("input")
local sound = require("sound")
local layout = require("layout")
local screens = require("screens")
local progression = require("progression")
local mobile = require("mobile")

local game_screen = {}

-- Layout constants
local VW, VH = layout.VW, layout.VH
local TOP_Y = layout.GRID_TOP_Y
local COIN_R = layout.COIN_R
local ROW_STEP = layout.ROW_STEP
local COLUMN_STEP = layout.COLUMN_STEP
local GRID_X_OFFSET = layout.GRID_LEFT_OFFSET

-- Screen-local state
local selection = nil
local merge_timer = 0
local top_x, top_y = 0, 0  -- Bottom-right grid bounds (for hit testing)

-- Button images and layout (will be set via init)
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

-- Font reference (set via init)
local font

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function game_screen.init(assets)
  -- Store asset references
  addButtonImage = assets.addButtonImage
  addButtonPressedImage = assets.addButtonPressedImage
  mergeButtonImage = assets.mergeButtonImage
  mergeButtonPressedImage = assets.mergeButtonPressedImage
  font = assets.font

  -- Calculate button dimensions and positions
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

local function draw_hint()
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(font)
  love.graphics.printf("Points = Combo * amount of coins in stack!", 0, layout.HINT_Y, VW, "center")
end

local function draw_points()
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(font)
  love.graphics.printf("Points: " .. game.getState().points, 0, layout.POINTS_Y, VW, "center")
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

-- Draw speaker icon (for SFX toggle)
local function drawSpeakerIcon(x, y, size, enabled)
  local s = size
  love.graphics.setColor(1, 1, 1, enabled and 1 or 0.4)
  love.graphics.rectangle("fill", x + s*0.2, y + s*0.35, s*0.2, s*0.3)
  love.graphics.polygon("fill",
    x + s*0.4, y + s*0.35,
    x + s*0.6, y + s*0.15,
    x + s*0.6, y + s*0.85,
    x + s*0.4, y + s*0.65
  )
  if enabled then
    love.graphics.setLineWidth(3)
    love.graphics.arc("line", "open", x + s*0.6, y + s*0.5, s*0.15, -math.pi/4, math.pi/4)
    love.graphics.arc("line", "open", x + s*0.6, y + s*0.5, s*0.25, -math.pi/4, math.pi/4)
  else
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.setLineWidth(4)
    love.graphics.line(x + s*0.65, y + s*0.25, x + s*0.9, y + s*0.75)
    love.graphics.line(x + s*0.65, y + s*0.75, x + s*0.9, y + s*0.25)
  end
  love.graphics.setLineWidth(1)
  love.graphics.setColor(1, 1, 1)
end

-- Draw music note icon (for music toggle)
local function drawMusicIcon(x, y, size, enabled)
  local s = size
  love.graphics.setColor(1, 1, 1, enabled and 1 or 0.4)
  love.graphics.ellipse("fill", x + s*0.3, y + s*0.7, s*0.15, s*0.1)
  love.graphics.ellipse("fill", x + s*0.6, y + s*0.55, s*0.15, s*0.1)
  love.graphics.setLineWidth(3)
  love.graphics.line(x + s*0.43, y + s*0.7, x + s*0.43, y + s*0.25)
  love.graphics.line(x + s*0.73, y + s*0.55, x + s*0.73, y + s*0.2)
  love.graphics.setLineWidth(5)
  love.graphics.line(x + s*0.43, y + s*0.25, x + s*0.73, y + s*0.2)
  if not enabled then
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.setLineWidth(4)
    love.graphics.line(x + s*0.1, y + s*0.2, x + s*0.4, y + s*0.5)
    love.graphics.line(x + s*0.1, y + s*0.5, x + s*0.4, y + s*0.2)
  end
  love.graphics.setLineWidth(1)
  love.graphics.setColor(1, 1, 1)
end

local function drawSoundToggles()
  local size = layout.SOUND_TOGGLE_SIZE
  local margin = layout.SOUND_TOGGLE_MARGIN
  local y = layout.SOUND_TOGGLE_Y

  -- SFX toggle (left)
  local sfxX = VW - margin - size * 2 - margin
  drawSpeakerIcon(sfxX, y, size, sound.isSfxEnabled())

  -- Music toggle (right)
  local musicX = VW - margin - size
  drawMusicIcon(musicX, y, size, sound.isMusicEnabled())
end

local function handleSoundToggleClick(x, y)
  if input.isOnSfxToggle(x, y) then
    sound.toggleSfx()
    return true
  elseif input.isOnMusicToggle(x, y) then
    sound.toggleMusic()
    return true
  end
  return false
end

--------------------------------------------------------------------------------
-- Screen lifecycle
--------------------------------------------------------------------------------

function game_screen.enter()
  game.init()
  selection = nil
end

function game_screen.exit()
  -- Could track game end here
  local state = game.getState()
  progression.onGameEnd("classic", state.points)
end

function game_screen.update(dt)
  merge_timer = game.update(dt)
  animation.update(dt)
  particles.update(dt)
  updateButtonAnimations(dt)
end

function game_screen.draw()
  local state = game.getState()

  -- Apply screen shake
  local shake_x, shake_y = animation.getScreenShake()
  if shake_x ~= 0 or shake_y ~= 0 then
    love.graphics.push()
    love.graphics.translate(shake_x, shake_y)
  end

  graphics.drawBackground()
  draw_hint()
  draw_points()

  if merge_timer > 0 then
    love.graphics.setColor(0, 1, 0)
    love.graphics.setFont(font)
    love.graphics.printf("Merged!", 0, layout.MERGED_MSG_Y, VW, "center")
  end

  top_x, top_y = graphics.drawBoxes(state.boxes, state.BOX_ROWS)

  -- Get boxes being animated (to skip drawing their static coins)
  local skipBoxes = animation.getMergingBoxIndices()
  graphics.drawCoins(state.boxes, state.COLORS, skipBoxes)

  -- Draw animated coins on top
  animation.draw(graphics.getBallImage(), state.COLORS, "classic")
  animation.drawMerge(graphics.getBallImage(), nil)
  animation.drawDealing(graphics.getBallImage(), state.COLORS, font)
  particles.draw()

  draw_merge_button()
  draw_add_coins_button()
  drawSoundToggles()

  -- End screen shake
  if shake_x ~= 0 or shake_y ~= 0 then
    love.graphics.pop()
  end
end

function game_screen.keypressed(key, scancode, isrepeat)
  if key == "\\" then
    love.event.quit()
  end
  if key == "escape" then
    screens.switch("mode_select")
  end
  if key == "a" then
    local state = game.getState()
    state.BOX_ROWS = state.BOX_ROWS + 1
  end
  if key == "b" then
    local state = game.getState()
    local name, color = next(state.non_active)
    if not name then return end
    state.COLORS[name] = color
    state.colors_str[#state.colors_str + 1] = name
    state.non_active[name] = nil
    table.insert(state.boxes, {})
  end
end

function game_screen.mousepressed(x, y, button)
  if button ~= 1 then return end

  -- Check sound toggle buttons first
  if handleSoundToggleClick(x, y) then
    return
  end

  -- Block input during any animation (except hovering which allows placement)
  if animation.isAnimating() and not animation.isHovering() then
    return
  end

  local state = game.getState()
  local bx = input.boxAt(x, y, state.boxes, top_y)

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

  if not bx then return end

  if not animation.isHovering() then
    -- Pick up: Start hover animation
    local pack = game.pick_coin_from_box(bx, {remove = true})
    if pack == nil or #pack == 0 then
      return
    end
    selection = { box = bx, pack = pack }
    animation.startHover(pack, bx)
    sound.playPickup()
    mobile.vibratePickup()
  else
    -- Place: Start flight animation
    local pack = animation.getHoveringCoins()
    local source_box_idx = animation.getSourceBox()

    -- If clicking on the source box, return coins and cancel
    if bx == source_box_idx then
      for _, color in ipairs(pack) do
        table.insert(state.boxes[source_box_idx], color)
      end
      animation.cancel()
      selection = nil
      sound.playPickup()
      return
    end

    -- Check if destination box has room
    if #state.boxes[bx] + #pack > state.BOX_ROWS then
      -- BOX_IS_FULL = true
      return
    end

    -- Calculate destination slot (where first coin will land)
    local dest_slot = #state.boxes[bx] + 1

    -- Start flight with per-coin callback
    animation.startFlight(bx, dest_slot,
      -- Final callback: when all coins have landed
      function()
        selection = nil
      end,
      -- Per-coin callback: when each coin lands
      function(color, slot)
        table.insert(state.boxes[bx], color)
        sound.playPickup()
        mobile.vibrateDrop()
        -- Spawn particle effect at landing position
        local px = GRID_X_OFFSET + COLUMN_STEP * bx
        local py = TOP_Y + ROW_STEP * slot
        local col = state.COLORS[color] or {1, 1, 1}
        particles.spawn(px, py, col)
        progression.onCoinPlaced()
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
    if input.isInsideButton(x, y, MERGE_BUTTON_X, MERGE_BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT) and not animation.isAnimating() then
      -- Get mergeable boxes and start animation
      local mergeable = game.getMergeableBoxes()
      if #mergeable > 0 then
        local combo = 0
        animation.startMerge(mergeable,
          -- Final callback: when all boxes done
          function()
            -- Animation complete
          end,
          -- Per-box callback: when each box finishes merging
          function(box_data)
            combo = combo + 1
            game.executeMergeOnBox(box_data.box_idx, combo)
            sound.playMerge()
            mobile.vibrateMerge()
            progression.onMerge("classic", 1)
          end,
          -- Particles module reference
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
      -- Calculate coins to add for dealing animation
      local coins_to_deal = game.calculateCoinsToAdd()

      if #coins_to_deal > 0 then
        local state = game.getState()

        animation.startDealing(coins_to_deal, "classic",
          -- Final callback: when all coins have landed
          function()
            -- Animation complete
          end,
          -- Per-coin callback: when each coin lands
          function(color, box_idx, slot)
            table.insert(state.boxes[box_idx], color)
            sound.playPickup()
            mobile.vibrateDrop()
            -- Spawn particle effect at landing position
            local px = GRID_X_OFFSET + COLUMN_STEP * box_idx
            local py = TOP_Y + ROW_STEP * slot
            local col = state.COLORS[color] or {1, 1, 1}
            particles.spawn(px, py, col)
          end,
          particles
        )
        sound.playAdd()
      end
    end
  end
end

return game_screen
