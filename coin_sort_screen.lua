-- coin_sort_screen.lua
-- Coin Sort gameplay screen

local coin_sort = require("coin_sort")
local animation = require("animation")
local particles = require("particles")
local graphics = require("graphics")
local input = require("input")
local sound = require("sound")
local layout = require("layout")
local screens = require("screens")
local coin_utils = require("coin_utils")
local progression = require("progression")
local mobile = require("mobile")
local resources = require("resources")
local bags = require("bags")
local powerups = require("powerups")
local tab_bar = require("tab_bar")

local coin_sort_screen = {}

-- Layout constants
local VW, VH = layout.VW, layout.VH
local TOP_Y = layout.GRID_TOP_Y
local COIN_R = layout.COIN_R
local ROW_STEP = layout.ROW_STEP
local COLUMN_STEP = layout.COLUMN_STEP
local GRID_X_OFFSET = layout.GRID_LEFT_OFFSET

-- Screen-local state
local selection = nil
local top_x, top_y = 0, 0  -- Bottom-right grid bounds (for hit testing)

-- Shake animation for invalid placement
local shakeState = {
  active = false,
  box_index = 0,
  time = 0,
  duration = 0.3
}

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

-- Power-up button layout
local POWERUP_Y = layout.BUTTON_AREA_Y + 180
local POWERUP_BTN_W = 350
local POWERUP_BTN_H = 80
local POWERUP_SPACING = 40
local SORT_BTN_X, HAMMER_BTN_X

-- Power-up state
local hammer_mode = false

-- Reset button hold state
local RESET_HOLD_DURATION = 3.0
local resetState = {
  held = false,
  time = 0,
  flash_time = 0,
}

-- Power-up button animation state
local powerupButtonState = {
  sort = { pressed = false, scale = 1.0, targetScale = 1.0 },
  hammer = { pressed = false, scale = 1.0, targetScale = 1.0 },
}

-- Fonts (set via init)
local font
local coinNumberFont

-- Resource feedback animation (floating text on merge)
local resource_popups = {}  -- array of {text, x, y, time, color}
local POPUP_DURATION = 1.0
local POPUP_RISE = 60

-- Box unlock flash animation (green glow when a new box unlocks)
local box_unlock_flashes = {}  -- array of {grid_idx, timer, duration}
local BOX_UNLOCK_FLASH_DURATION = 1.2

-- Touch-aware pointer helpers (love.mouse.isDown doesn't track touches on mobile)
local function isPointerDown()
  if love.mouse.isDown(1) then return true end
  if love.touch then
    local touches = love.touch.getTouches()
    return #touches > 0
  end
  return false
end

local function getPointerPosition()
  if love.touch then
    local touches = love.touch.getTouches()
    if #touches > 0 then
      return love.touch.getPosition(touches[1])
    end
  end
  return love.mouse.getPosition()
end

-- Spawn floating resource popup from merge position
local function spawnResourcePopup(from_x, from_y, gained)
  local parts = {}
  if gained.fuel > 0 then parts[#parts + 1] = "+" .. gained.fuel .. " Fuel" end
  if gained.components > 0 then parts[#parts + 1] = "+" .. gained.components .. " Comp" end
  if gained.metal > 0 then parts[#parts + 1] = "+1 Metal" end
  if #parts == 0 then return end

  table.insert(resource_popups, {
    text = table.concat(parts, "  "),
    x = from_x, y = from_y,
    time = 0,
    color = gained.fuel > 0 and {1, 0.8, 0.2} or {0.5, 0.8, 1},
  })
end

-- Update resource popups
local function updateResourcePopups(dt)
  local i = 1
  while i <= #resource_popups do
    resource_popups[i].time = resource_popups[i].time + dt
    if resource_popups[i].time >= POPUP_DURATION then
      table.remove(resource_popups, i)
    else
      i = i + 1
    end
  end
end

-- Draw resource popups
local function drawResourcePopups()
  love.graphics.setFont(font)
  for _, p in ipairs(resource_popups) do
    local t = p.time / POPUP_DURATION
    local alpha = 1 - t
    local rise = POPUP_RISE * t
    love.graphics.setColor(0, 0, 0, alpha * 0.7)
    love.graphics.printf(p.text, p.x - 150 + 2, p.y - rise + 2, 300, "center")
    love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
    love.graphics.printf(p.text, p.x - 150, p.y - rise, 300, "center")
  end
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function coin_sort_screen.init(assets)
  -- Store asset references
  addButtonImage = assets.addButtonImage
  addButtonPressedImage = assets.addButtonPressedImage
  mergeButtonImage = assets.mergeButtonImage
  mergeButtonPressedImage = assets.mergeButtonPressedImage
  font = assets.font
  coinNumberFont = assets.coinNumberFont

  -- Calculate button dimensions and positions
  local btnW, btnH = addButtonImage:getDimensions()
  BUTTON_WIDTH = btnW * BUTTON_SCALE
  BUTTON_HEIGHT = btnH * BUTTON_SCALE
  local totalWidth = BUTTON_WIDTH * 2 + BUTTON_SPACING
  local startX = (VW - totalWidth) / 2
  ADD_BUTTON_X = startX
  ADD_BUTTON_Y = layout.BUTTON_AREA_Y - 40
  MERGE_BUTTON_X = startX + BUTTON_WIDTH + BUTTON_SPACING
  MERGE_BUTTON_Y = layout.BUTTON_AREA_Y - 40

  -- Power-up button positions (centered row below main buttons)
  local puTotalW = POWERUP_BTN_W * 2 + POWERUP_SPACING
  local puStartX = (VW - puTotalW) / 2
  SORT_BTN_X = puStartX
  HAMMER_BTN_X = puStartX + POWERUP_BTN_W + POWERUP_SPACING
end

--------------------------------------------------------------------------------
-- Drawing helpers
--------------------------------------------------------------------------------

local function draw_2048_info()
  local state = coin_sort.getState()
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(font)
  love.graphics.printf("Merges: " .. state.total_merges .. "  |  Max Spawn: " .. state.max_spawn_number,
    0, layout.HINT_Y, VW, "center")
end

local function draw_points_2048()
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(font)
  love.graphics.printf("Points: " .. coin_sort.getState().points, 0, layout.POINTS_Y, VW, "center")
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
  for _, state in pairs(powerupButtonState) do
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

local function drawResetButton()
  local size = layout.SOUND_TOGGLE_SIZE
  local margin = layout.SOUND_TOGGLE_MARGIN
  local y = layout.SOUND_TOGGLE_Y
  local resetX = VW - margin - size * 3 - margin * 2
  local cx, cy = resetX + size / 2, y + size / 2
  local progress = resetState.held and (resetState.time / RESET_HOLD_DURATION) or 0

  -- Background fill (red, grows with hold progress)
  if progress > 0 then
    love.graphics.setColor(0.8, 0.15, 0.15, 0.2 + progress * 0.5)
    love.graphics.rectangle("fill", resetX, y, size, size, 8, 8)
  end

  -- Flash on completion
  if resetState.flash_time > 0 then
    love.graphics.setColor(1, 1, 1, resetState.flash_time)
    love.graphics.rectangle("fill", resetX, y, size, size, 8, 8)
  end

  -- Circular arrow icon
  local r = size * 0.28
  local alpha = resetState.held and 1 or 0.5
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.setLineWidth(3)
  love.graphics.arc("line", "open", cx, cy, r, -math.pi * 0.7, math.pi * 0.8)
  -- Arrowhead at end of arc
  local end_angle = -math.pi * 0.7
  local ex, ey = cx + r * math.cos(end_angle), cy + r * math.sin(end_angle)
  local a = size * 0.13
  love.graphics.polygon("fill",
    ex, ey,
    ex + a * math.cos(end_angle - 0.3), ey + a * math.sin(end_angle - 0.3),
    ex + a * math.cos(end_angle + 1.8), ey + a * math.sin(end_angle + 1.8)
  )

  -- Progress ring around button
  if progress > 0 then
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.setLineWidth(4)
    love.graphics.arc("line", "open", cx, cy, size * 0.45,
      -math.pi / 2, -math.pi / 2 + progress * math.pi * 2)
  end

  -- Hold countdown text
  if resetState.held then
    love.graphics.setColor(1, 0.3, 0.3, 0.9)
    love.graphics.setFont(font)
    local secs = math.ceil(RESET_HOLD_DURATION - resetState.time)
    love.graphics.printf(secs .. "s", resetX, y + size + 4, size, "center")
  end

  love.graphics.setLineWidth(1)
end

local function drawSoundToggles()
  local size = layout.SOUND_TOGGLE_SIZE
  local margin = layout.SOUND_TOGGLE_MARGIN
  local y = layout.SOUND_TOGGLE_Y

  -- Reset button (leftmost)
  drawResetButton()

  -- SFX toggle (middle)
  local sfxX = VW - margin - size * 2 - margin
  drawSpeakerIcon(sfxX, y, size, sound.isSfxEnabled())

  -- Music toggle (right)
  local musicX = VW - margin - size
  drawMusicIcon(musicX, y, size, sound.isMusicEnabled())
end

local function drawPowerupButtons()
  love.graphics.setFont(font)

  -- Sort button
  local sort_count = powerups.getAutoSortCount()
  local sort_enabled = sort_count > 0
  local sort_s = powerupButtonState.sort.scale
  local sort_cx = SORT_BTN_X + POWERUP_BTN_W / 2
  local sort_cy = POWERUP_Y + POWERUP_BTN_H / 2
  local sort_w = POWERUP_BTN_W * sort_s
  local sort_h = POWERUP_BTN_H * sort_s

  if sort_enabled then
    love.graphics.setColor(0.2, 0.4, 0.6)
  else
    love.graphics.setColor(0.2, 0.2, 0.2)
  end
  love.graphics.rectangle("fill", sort_cx - sort_w/2, sort_cy - sort_h/2, sort_w, sort_h, 10, 10)
  love.graphics.setColor(1, 1, 1, sort_enabled and 1 or 0.4)
  love.graphics.printf("Sort x" .. sort_count, SORT_BTN_X, POWERUP_Y + (POWERUP_BTN_H - layout.FONT_SIZE) / 2, POWERUP_BTN_W, "center")

  -- Hammer button
  local hammer_count = powerups.getHammerCount()
  local hammer_enabled = hammer_count > 0
  local hammer_s = powerupButtonState.hammer.scale
  local hammer_cx = HAMMER_BTN_X + POWERUP_BTN_W / 2
  local hammer_cy = POWERUP_Y + POWERUP_BTN_H / 2
  local hammer_w = POWERUP_BTN_W * hammer_s
  local hammer_h = POWERUP_BTN_H * hammer_s

  if hammer_mode then
    love.graphics.setColor(0.7, 0.2, 0.2)
  elseif hammer_enabled then
    love.graphics.setColor(0.6, 0.3, 0.2)
  else
    love.graphics.setColor(0.2, 0.2, 0.2)
  end
  love.graphics.rectangle("fill", hammer_cx - hammer_w/2, hammer_cy - hammer_h/2, hammer_w, hammer_h, 10, 10)
  love.graphics.setColor(1, 1, 1, hammer_enabled and 1 or 0.4)
  love.graphics.printf("Hammer x" .. hammer_count, HAMMER_BTN_X, POWERUP_Y + (POWERUP_BTN_H - layout.FONT_SIZE) / 2, POWERUP_BTN_W, "center")
end

local function updateBoxUnlockFlashes(dt)
  local i = 1
  while i <= #box_unlock_flashes do
    box_unlock_flashes[i].timer = box_unlock_flashes[i].timer + dt
    if box_unlock_flashes[i].timer >= box_unlock_flashes[i].duration then
      table.remove(box_unlock_flashes, i)
    else
      i = i + 1
    end
  end
end

local function drawBoxUnlockFlashes()
  for _, flash in ipairs(box_unlock_flashes) do
    local t = flash.timer / flash.duration
    local alpha = math.sin(t * math.pi) * 0.55  -- fade in then out
    local bx, by = layout.boxPosition(flash.grid_idx)
    love.graphics.setColor(0.3, 0.9, 0.3, alpha)
    love.graphics.rectangle("fill", bx, by, layout.BOX_W, layout.BOX_H, 4, 4)
    love.graphics.setColor(0.2, 1.0, 0.2, math.min(1, alpha * 2))
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", bx, by, layout.BOX_W, layout.BOX_H, 4, 4)
    love.graphics.setLineWidth(1)
  end
end

local function drawHammerOverlay()
  if not hammer_mode then return end
  local state = coin_sort.getState()
  -- Red tint overlay on each active box only
  for col_idx = 1, 15 do
    if state.boxes[col_idx] then
      local bx, by = layout.boxPosition(col_idx)
      love.graphics.setColor(1, 0.1, 0.1, 0.15)
      love.graphics.rectangle("fill", bx, by, layout.BOX_W, layout.BOX_H, 8, 8)
    end
  end
  -- Hint text
  love.graphics.setColor(1, 0.3, 0.3)
  love.graphics.setFont(font)
  love.graphics.printf("TAP BOX TO CLEAR", 0, POWERUP_Y - 50, VW, "center")
end


local function executeReset()
  progression.reset()
  resources.init()
  bags.init()
  powerups.init()
  coin_sort.deactivate()
  resetState.flash_time = 1.0
  -- Restart the game screen with fresh state
  coin_sort_screen.enter()
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

-- Draw best coin progress bar
local function drawProgressBar()
  local state = coin_sort.getState()
  local best = state.max_coin_reached
  local max_num = state.MAX_NUMBER

  local bar_w = 600
  local bar_h = 16
  local bar_x = (VW - bar_w) / 2
  local bar_y = 250

  -- Background
  love.graphics.setColor(0.15, 0.15, 0.15)
  love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 6, 6)

  -- Fill
  if best > 0 then
    local fill = math.min(best / max_num, 1) * bar_w
    local col = coin_utils.numberToColor(best, max_num)
    love.graphics.setColor(col[1], col[2], col[3], 0.85)
    love.graphics.rectangle("fill", bar_x, bar_y, fill, bar_h, 6, 6)
  end

  -- Border
  love.graphics.setColor(0.3, 0.3, 0.3, 0.6)
  love.graphics.rectangle("line", bar_x, bar_y, bar_w, bar_h, 6, 6)

  -- Label
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.setFont(font)
  love.graphics.printf("Best: " .. best .. " / " .. max_num, bar_x, bar_y - 2, bar_w, "center")
end

-- Draw resource HUD at top (Fuel gauge, Metal, Components, Bags)
local function drawResourceHUD()
  love.graphics.setFont(font)
  local y = 35

  -- Fuel gauge (bar style)
  local fuel = resources.getFuel()
  local fuel_cap = resources.getFuelCap()
  local fuel_bar_x = 60
  local fuel_bar_w = 280
  local fuel_bar_h = 24
  local fuel_bar_y = y - fuel_bar_h / 2

  -- Label
  love.graphics.setColor(1, 0.8, 0.2, 0.9)
  love.graphics.print("Fuel", fuel_bar_x - 5, y - 30)

  -- Bar background
  love.graphics.setColor(0.15, 0.15, 0.15, 0.7)
  love.graphics.rectangle("fill", fuel_bar_x, fuel_bar_y, fuel_bar_w, fuel_bar_h, 4, 4)

  -- Bar fill
  local fill = math.min(fuel / fuel_cap, 1) * fuel_bar_w
  if fill > 0 then
    love.graphics.setColor(1, 0.7, 0.1, 0.85)
    love.graphics.rectangle("fill", fuel_bar_x, fuel_bar_y, fill, fuel_bar_h, 4, 4)
  end

  -- Bar text
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.printf(fuel .. "/" .. fuel_cap, fuel_bar_x, fuel_bar_y + 1, fuel_bar_w, "center")

  -- Metal count
  local metal_x = 420
  love.graphics.setColor(0.6, 0.7, 0.8)
  love.graphics.print("Metal", metal_x, y - 30)
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.printf(tostring(resources.getMetal()), metal_x, y - 10, 100, "left")

  -- Components count
  local comp_x = 580
  love.graphics.setColor(0.5, 0.8, 0.5)
  love.graphics.print("Comp", comp_x, y - 30)
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.printf(tostring(resources.getComponents()), comp_x, y - 10, 100, "left")

  -- Bags count
  local bags_x = 740
  local total_bags = bags.getTotalAvailable()
  love.graphics.setColor(0.8, 0.6, 0.3)
  love.graphics.print("Bags", bags_x, y - 30)
  love.graphics.setColor(1, 1, 1, total_bags > 0 and 0.9 or 0.4)
  love.graphics.printf(tostring(total_bags), bags_x, y - 10, 100, "left")

  -- Free bag timer (if queue not full)
  if bags.getFreeBagsQueued() < 2 then
    local timer = bags.getFreeInterval() - bags.getFreeTimer()
    local mins = math.floor(timer / 60)
    local secs = math.floor(timer % 60)
    love.graphics.setColor(0.6, 0.6, 0.6, 0.6)
    love.graphics.printf(string.format("%d:%02d", mins, secs), bags_x + 40, y - 10, 80, "left")
  end
end

-- (Quest tracker removed — replaced by resource HUD)

--------------------------------------------------------------------------------
-- Screen lifecycle
--------------------------------------------------------------------------------

function coin_sort_screen.enter()
  -- Register box-unlock callback (fires mid-session when a new coin nominal is reached)
  coin_sort.setBoxUnlockedCallback(function(grid_idx)
    table.insert(box_unlock_flashes, {
      grid_idx = grid_idx,
      timer = 0,
      duration = BOX_UNLOCK_FLASH_DURATION,
    })
    sound.playMerge()
  end)

  -- Only init a new game if not already active (preserves state on tab switch)
  if not coin_sort.isActive() then
    coin_sort.init()
    selection = nil
    shakeState.active = false
    hammer_mode = false
    resource_popups = {}
    box_unlock_flashes = {}
    resetState.held = false
    resetState.time = 0
  end

  -- Compute fixed 3×5 grid layout
  layout.computeBoxGrid()

  -- Refresh module caches
  graphics.updateMetrics()
  input.updateMetrics()

  -- Update screen-local caches
  COLUMN_STEP = layout.COLUMN_STEP
  COIN_R = layout.COIN_R
  ROW_STEP = layout.ROW_STEP
  TOP_Y = layout.GRID_TOP_Y

  -- Recreate coin number font to match new COIN_R
  local fontScale = 0.6
  coinNumberFont = love.graphics.newFont("comic shanns.otf", math.floor(layout.COIN_R * fontScale))
end

function coin_sort_screen.exit()
  -- Track game end
  local state = coin_sort.getState()
  progression.onGameEnd("coin_sort", state.points)
end

function coin_sort_screen.update(dt)
  coin_sort.update(dt)
  animation.update(dt)
  particles.update(dt)
  updateButtonAnimations(dt)
  bags.update(dt)

  -- Update shake animation
  if shakeState.active then
    shakeState.time = shakeState.time + dt
    if shakeState.time >= shakeState.duration then
      shakeState.active = false
    end
  end

  updateResourcePopups(dt)
  updateBoxUnlockFlashes(dt)

  -- Reset button hold tracking
  if resetState.held then
    if not isPointerDown() then
      resetState.held = false
      resetState.time = 0
    else
      resetState.time = resetState.time + dt
      if resetState.time >= RESET_HOLD_DURATION then
        executeReset()
      end
    end
  end
  if resetState.flash_time > 0 then
    resetState.flash_time = resetState.flash_time - dt
  end
end

function coin_sort_screen.draw()
  local state = coin_sort.getState()

  -- Apply screen shake
  local shake_x, shake_y = animation.getScreenShake()
  if shake_x ~= 0 or shake_y ~= 0 then
    love.graphics.push()
    love.graphics.translate(shake_x, shake_y)
  end

  graphics.drawBackground()
  drawResourceHUD()
  drawProgressBar()

  -- Show merge message
  if state.merge_timer > 0 then
    love.graphics.setColor(0, 1, 0)
    love.graphics.setFont(font)
    love.graphics.printf("Merged!", 0, layout.MERGED_MSG_Y, VW, "center")
  end

  -- Show error message
  if state.error_timer > 0 then
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.setFont(font)
    love.graphics.printf(state.error_message, 0, layout.MERGED_MSG_Y + 60, VW, "center")
  end

  top_x, top_y = graphics.drawBoxes2048(state.boxes, state.BOX_ROWS, shakeState)
  drawBoxUnlockFlashes()

  -- Get boxes being animated (to skip drawing their static coins)
  local skipBoxes = animation.getMergingBoxIndices()
  graphics.drawCoins2048(state.boxes, state.MAX_NUMBER, coinNumberFont, skipBoxes)

  -- Draw animated coins (hover/flight)
  animation.draw(graphics.getBallImage(), nil, "2048", coinNumberFont)

  -- Draw merge animation (squeeze, flash, pop)
  animation.drawMerge(graphics.getBallImage(), coinNumberFont)

  -- Draw dealing animation (burst + flight)
  animation.drawDealing(graphics.getBallImage(), nil, coinNumberFont)

  particles.draw()
  drawResourcePopups()

  draw_merge_button()
  draw_add_coins_button()
  drawPowerupButtons()
  drawHammerOverlay()
  drawSoundToggles()

  -- End screen shake
  if shake_x ~= 0 or shake_y ~= 0 then
    love.graphics.pop()
  end

  -- Tab bar (drawn outside shake transform)
  tab_bar.draw("coin_sort")
end

function coin_sort_screen.keypressed(key, scancode, isrepeat)
  if key == "\\" then
    love.event.quit()
  end
  if key == "escape" then
    if hammer_mode then
      hammer_mode = false
      return
    end
    screens.switch("arena")
  end
  if key == "f3" then
    -- Debug: give resources and go to arena
    resources.addFuel(50)
    resources.addMetal(5)
    resources.addComponents(10)
    bags.addBags(5)
    screens.switch("arena")
  end
end

function coin_sort_screen.mousepressed(x, y, button)
  if button ~= 1 then return end

  -- Check tab bar first
  local tab = tab_bar.mousepressed(x, y)
  if tab and tab ~= "coin_sort" then
    screens.switch(tab)
    return
  end

  -- Check sound toggle buttons first
  if handleSoundToggleClick(x, y) then
    return
  end

  -- Check reset button (start hold)
  if input.isOnResetButton(x, y) then
    resetState.held = true
    resetState.time = 0
    return
  end

  -- Block all input only during flight (coins in transit)
  -- Allow picking/placing during merge and dealing for fast gameplay
  if animation.isFlying() then
    return
  end

  local state = coin_sort.getState()
  local bx = input.boxAt2048(x, y, state.boxes, top_y)

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

  -- Check sort button
  if input.isInsideButton(x, y, SORT_BTN_X, POWERUP_Y, POWERUP_BTN_W, POWERUP_BTN_H) then
    powerupButtonState.sort.pressed = true
    powerupButtonState.sort.targetScale = BUTTON_PRESS_SCALE
    return
  end

  -- Check hammer button
  if input.isInsideButton(x, y, HAMMER_BTN_X, POWERUP_Y, POWERUP_BTN_W, POWERUP_BTN_H) then
    powerupButtonState.hammer.pressed = true
    powerupButtonState.hammer.targetScale = BUTTON_PRESS_SCALE
    return
  end

  -- Hammer targeting: click on a column to clear it
  if hammer_mode and bx then
    local merge_locked = animation.getMergeLockedBoxes()
    if not merge_locked[bx] then
      if powerups.useHammer() then
        local state = coin_sort.getState()
        local removed = coin_sort.clearColumn(bx)
        -- Spawn particles for each removed coin
        for slot, coin in ipairs(removed) do
          local px, py = layout.slotPosition(bx, slot)
          local num = coin_utils.getCoinNumber(coin)
          local col = coin_utils.numberToColor(num, state.MAX_NUMBER)
          particles.spawnMergeExplosion(px, py, col)
        end
        sound.playMerge()
        hammer_mode = false
        if coin_sort.isGameOver() then
          coin_sort.deactivate()
          screens.switch("game_over")
        end
      end
    end
    return
  end

  if not bx then return end

  -- Don't interact with boxes locked by merge animation
  local merge_locked = animation.getMergeLockedBoxes()
  if merge_locked[bx] then return end

  if not animation.isHovering() then
    -- Pick up: Start hover animation
    local pack = coin_sort.pick_coin_from_box(bx, {remove = true})
    if pack == nil or #pack == 0 then
      return
    end
    selection = { box = bx, pack = pack }
    animation.startHover(pack, bx)
    sound.playPickup()
    mobile.vibratePickup()
  else
    -- Place: Validate and start flight animation
    local pack = animation.getHoveringCoins()
    local source_box_idx = animation.getSourceBox()

    -- If clicking on the source box, return coins and cancel
    if bx == source_box_idx then
      for _, coin in ipairs(pack) do
        coin_sort.place_coin(source_box_idx, coin)
      end
      animation.cancel()
      selection = nil
      sound.playPickup()
      return
    end

    -- Validate placement
    local can_place, err_msg, available_slots = coin_sort.can_place(bx, pack)
    if not can_place then
      -- Invalid placement: shake box and show error
      shakeState.active = true
      shakeState.box_index = bx
      shakeState.time = 0
      coin_sort.setError(err_msg)
      mobile.vibrateError()
      return
    end

    -- Partial placement: if not all coins fit, return extras to source
    if available_slots < #pack then
      local returned_coins = animation.splitHoveringCoins(available_slots)
      -- Return extra coins to source box immediately
      for _, coin in ipairs(returned_coins) do
        coin_sort.place_coin(source_box_idx, coin)
      end
    end

    -- Calculate destination slot
    local dest_slot = #state.boxes[bx] + 1

    -- Start flight with per-coin callback
    animation.startFlight(bx, dest_slot,
      -- Final callback: when all coins have landed
      function()
        selection = nil
        if coin_sort.isGameOver() then
          coin_sort.deactivate()
          screens.switch("game_over")
        end
      end,
      -- Per-coin callback: when each coin lands
      function(coin_data, slot)
        coin_sort.place_coin(bx, coin_data)
        sound.playPickup()
        mobile.vibrateDrop()
        -- Spawn particle effect at landing position
        local px, py = layout.slotPosition(bx, slot)
        local num = coin_utils.getCoinNumber(coin_data)
        local col = coin_utils.numberToColor(num, state.MAX_NUMBER)
        particles.spawn(px, py, col)
        progression.onCoinPlaced()
      end
    )
  end
end

function coin_sort_screen.mousereleased(x, y, button)
  if button ~= 1 then return end

  -- Release merge button
  if buttonState.merge.pressed then
    buttonState.merge.pressed = false
    buttonState.merge.targetScale = 1.0
    if input.isInsideButton(x, y, MERGE_BUTTON_X, MERGE_BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT) and not animation.isAnimating() then
      -- Get mergeable boxes and start animation
      local mergeable = coin_sort.getMergeableBoxes()
      if #mergeable > 0 then
        animation.startMerge(mergeable,
          -- Final callback: when all boxes done
          function()
            if coin_sort.isGameOver() then
              coin_sort.deactivate()
              screens.switch("game_over")
            end
          end,
          -- Per-box callback: when each box finishes merging
          function(box_data)
            local success, gained = coin_sort.executeMergeOnBox(box_data.box_idx)
            sound.playMerge()
            mobile.vibrateMerge()
            progression.onMerge("2048", 1)
            -- Spawn resource feedback popup
            if gained then
              local from_x = box_data.slot_x[1]
              local from_y = box_data.slot_y[1]
              spawnResourcePopup(from_x, from_y, gained)
            end
          end,
          -- Particles module reference
          particles
        )
      end
    end
  end

  -- Release add button (bag-based dealing)
  if buttonState.add.pressed then
    buttonState.add.pressed = false
    buttonState.add.targetScale = 1.0
    if input.isInsideButton(x, y, ADD_BUTTON_X, ADD_BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT) and not animation.isAnimating() then
      -- Only deal if bags available
      if coin_sort.hasBags() then
        local coins_to_deal = coin_sort.dealFromBag()
        if coins_to_deal and #coins_to_deal > 0 then
          local state = coin_sort.getState()

          animation.startDealing(coins_to_deal, "2048",
            function()
              if coin_sort.isGameOver() then
                coin_sort.deactivate()
                screens.switch("game_over")
              end
            end,
            function(coin_data, box_idx, slot)
              coin_sort.place_coin(box_idx, coin_data)
              sound.playPickup()
              mobile.vibrateDrop()
              local px, py = layout.slotPosition(box_idx, slot)
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

  -- Release sort button
  if powerupButtonState.sort.pressed then
    powerupButtonState.sort.pressed = false
    powerupButtonState.sort.targetScale = 1.0
    if input.isInsideButton(x, y, SORT_BTN_X, POWERUP_Y, POWERUP_BTN_W, POWERUP_BTN_H)
       and not animation.isAnimating()
       and not animation.isHovering()
       and powerups.getAutoSortCount() > 0 then
      if powerups.useAutoSort() then
        local coins_to_deal = coin_sort.autoSort()
        if #coins_to_deal > 0 then
          local state = coin_sort.getState()
          animation.startDealing(coins_to_deal, "2048",
            function()
              if coin_sort.isGameOver() then
                coin_sort.deactivate()
                screens.switch("game_over")
              end
            end,
            function(coin_data, box_idx, slot)
              coin_sort.place_coin(box_idx, coin_data)
              sound.playPickup()
              mobile.vibrateDrop()
              local px, py = layout.slotPosition(box_idx, slot)
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

  -- Release hammer button
  if powerupButtonState.hammer.pressed then
    powerupButtonState.hammer.pressed = false
    powerupButtonState.hammer.targetScale = 1.0
    if input.isInsideButton(x, y, HAMMER_BTN_X, POWERUP_Y, POWERUP_BTN_W, POWERUP_BTN_H) then
      if hammer_mode then
        -- Toggle off
        hammer_mode = false
      elseif not animation.isAnimating()
         and not animation.isHovering()
         and powerups.getHammerCount() > 0 then
        hammer_mode = true
      end
    end
  end
end

return coin_sort_screen
