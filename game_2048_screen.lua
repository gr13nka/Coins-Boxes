-- game_2048_screen.lua
-- 2048 mode gameplay screen

local game_2048 = require("game_2048")
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
local currency = require("currency")
local upgrades = require("upgrades")
local powerups = require("powerups")
local emoji = require("emoji")

local game_2048_screen = {}

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

-- Flying shard animation (merge reward feedback)
local flying_shards = {}
local SHARD_FLIGHT_DURATION = 0.55
local SHARD_ARC_HEIGHT = 180
local SHARD_SIZE = 24

-- HUD pop effect when shards arrive
local hud_pops = {}  -- keyed by color_name: {time, amount}
local HUD_POP_DURATION = 0.55
local HUD_POP_OVERSHOOT = 2.5

-- Debug size slider
local SLIDER_X = 200
local SLIDER_W = 680
local SLIDER_Y = 1860
local SLIDER_H = 36
local SLIDER_HANDLE_R = 22
local size_scale = 1.0
local slider_dragging = false
local base_coin_r = 0
local base_row_step = 0

-- Get HUD diamond position for a shard color
local function getShardHudPosition(color_name)
  local names = coin_utils.getShardNames()
  local spacing = 160
  local total_w = (#names - 1) * spacing
  local start_x = (VW - total_w) / 2
  local y = 50
  for i, name in ipairs(names) do
    if name == color_name then
      return start_x + (i - 1) * spacing, y
    end
  end
  return VW / 2, y
end

-- Spawn flying shard from merge position to HUD
local function spawnFlyingShards(from_x, from_y, coin_number, coin_count)
  local color_name = coin_utils.numberToShardColor(coin_number)
  local rgb = coin_utils.getShardRGB(color_name)
  local dest_x, dest_y = getShardHudPosition(color_name)
  local base_amount = coin_count * 5
  local multiplier = upgrades.getShardBonusMultiplier()
  local amount = math.floor(base_amount * multiplier)

  table.insert(flying_shards, {
    x = from_x, y = from_y,
    start_x = from_x, start_y = from_y,
    dest_x = dest_x, dest_y = dest_y,
    time = 0,
    color = rgb,
    color_name = color_name,
    amount = amount,
  })
end

-- Update flying shard positions
local function updateFlyingShards(dt)
  local i = 1
  while i <= #flying_shards do
    local s = flying_shards[i]
    s.time = s.time + dt
    local t = math.min(s.time / SHARD_FLIGHT_DURATION, 1)
    local t_eased = 1 - (1 - t) * (1 - t)  -- ease-out quadratic
    s.x = s.start_x + (s.dest_x - s.start_x) * t_eased
    s.y = s.start_y + (s.dest_y - s.start_y) * t_eased - SHARD_ARC_HEIGHT * math.sin(t * math.pi)

    if t >= 1 then
      hud_pops[s.color_name] = { time = 0, amount = s.amount }
      table.remove(flying_shards, i)
    else
      i = i + 1
    end
  end

  for name, pop in pairs(hud_pops) do
    pop.time = pop.time + dt
    if pop.time >= HUD_POP_DURATION then
      hud_pops[name] = nil
    end
  end
end

-- Draw flying shard diamonds
local function drawFlyingShards()
  love.graphics.setFont(font)
  for _, s in ipairs(flying_shards) do
    local rgb = s.color
    local pulse = 1 + 0.15 * math.sin(love.timer.getTime() * 12)
    local sz = SHARD_SIZE * pulse

    -- Glow circle behind emoji
    love.graphics.setColor(rgb[1], rgb[2], rgb[3], 0.3)
    love.graphics.circle("fill", s.x, s.y, sz * 1.6)

    -- Emoji icon
    emoji.draw(s.color_name, s.x, s.y, sz)

    -- "+N" text with dark outline for readability
    local text = "+" .. s.amount
    local tx, ty = s.x + sz + 6, s.y - 14
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.print(text, tx + 2, ty + 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(text, tx, ty)
  end
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function game_2048_screen.init(assets)
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
  local state = game_2048.getState()
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(font)
  love.graphics.printf("Merges: " .. state.total_merges .. "  |  Max Spawn: " .. state.max_spawn_number,
    0, layout.HINT_Y, VW, "center")
end

local function draw_points_2048()
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(font)
  love.graphics.printf("Points: " .. game_2048.getState().points, 0, layout.POINTS_Y, VW, "center")
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

local function drawHammerOverlay()
  if not hammer_mode then return end
  local state = game_2048.getState()
  -- Red tint overlay on each column
  for col_idx, box in ipairs(state.boxes) do
    local col_x, col_top_y = layout.columnPosition(col_idx)
    local col_w = layout.COIN_R * 2 + 20
    local col_h = layout.ROW_STEP * state.BOX_ROWS + 40
    local col_top = col_top_y + layout.ROW_STEP - 20
    love.graphics.setColor(1, 0.1, 0.1, 0.15)
    love.graphics.rectangle("fill", col_x - col_w/2, col_top, col_w, col_h, 8, 8)
  end
  -- Hint text
  love.graphics.setColor(1, 0.3, 0.3)
  love.graphics.setFont(font)
  love.graphics.printf("TAP COLUMN TO CLEAR", 0, POWERUP_Y - 50, VW, "center")
end

-- Apply the slider scale to coin/tray sizing
local function applySliderScale()
  layout.COIN_R = math.max(10, math.floor(base_coin_r * size_scale))
  layout.ROW_STEP = math.max(5, math.floor(base_row_step * size_scale))
  graphics.updateMetrics()
  input.updateMetrics()
  COIN_R = layout.COIN_R
  ROW_STEP = layout.ROW_STEP
  local fs = layout.USE_FRUIT_IMAGES and 0.35 or 0.6
  coinNumberFont = love.graphics.newFont("comic shanns.otf", math.max(8, math.floor(layout.COIN_R * fs)))
end

-- Update slider drag tracking
local function updateSliderDrag()
  if not slider_dragging then return end
  if not love.mouse.isDown(1) then
    slider_dragging = false
    return
  end
  local mx, my = love.mouse.getPosition()
  local ww, wh = love.graphics.getDimensions()
  local sc = math.min(ww / VW, wh / VH)
  local ox = (ww - VW * sc) / 2
  local gx = (mx - ox) / sc
  local t = math.max(0, math.min(1, (gx - SLIDER_X) / SLIDER_W))
  size_scale = 0.5 + t * 1.5  -- 50% to 200%
  applySliderScale()
end

-- Draw the debug size slider
local function drawSlider()
  -- Bar background
  love.graphics.setColor(0.15, 0.15, 0.2, 0.8)
  love.graphics.rectangle("fill", SLIDER_X, SLIDER_Y, SLIDER_W, SLIDER_H, 6, 6)

  -- Fill
  local t = (size_scale - 0.5) / 1.5
  love.graphics.setColor(0.25, 0.45, 0.7, 0.6)
  love.graphics.rectangle("fill", SLIDER_X, SLIDER_Y, SLIDER_W * t, SLIDER_H, 6, 6)

  -- Handle
  local hx = SLIDER_X + SLIDER_W * t
  local hy = SLIDER_Y + SLIDER_H / 2
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.circle("fill", hx, hy, SLIDER_HANDLE_R)
  love.graphics.setColor(0.3, 0.3, 0.4)
  love.graphics.circle("line", hx, hy, SLIDER_HANDLE_R)

  -- Label
  local pct = math.floor(size_scale * 100)
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(font)
  love.graphics.printf("Size: " .. pct .. "%", 0, SLIDER_Y - 36, VW, "center")
end

local function executeReset()
  progression.reset()
  currency.init()
  upgrades.init()
  powerups.init()
  resetState.flash_time = 1.0
  -- Restart the game screen with fresh state
  game_2048_screen.enter()
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
  local state = game_2048.getState()
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

-- Draw small shard/crystal HUD at top
local function drawCurrencyHUD()
  local names = coin_utils.getShardNames()
  local shards = currency.getShards()
  local crystals = currency.getCrystals()
  local spacing = 160
  local total_w = (#names - 1) * spacing
  local start_x = (VW - total_w) / 2
  local y = 50

  love.graphics.setFont(font)
  for i, name in ipairs(names) do
    local x = start_x + (i - 1) * spacing
    local rgb = coin_utils.getShardRGB(name)

    -- Pop scale when shards arrive
    local pop = hud_pops[name]
    local ps = 1
    if pop then
      local t = pop.time / HUD_POP_DURATION
      ps = 1 + (HUD_POP_OVERSHOOT - 1) * math.sin(t * math.pi) * (1 - t * 0.5)
    end

    -- Emoji icon (scaled by pop)
    local ds = 8 * ps
    emoji.draw(name, x, y, ds)
    -- Crystal count
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf(tostring(crystals[name] or 0), x + 15, y - 14, 60, "left")

    -- Show shard amount arriving (prominent pop text)
    if pop then
      local fade = 1 - pop.time / HUD_POP_DURATION
      local rise = pop.time / HUD_POP_DURATION * 20  -- float upward
      local pop_text = "+" .. pop.amount
      local tx, ty = x - 20, y - 50 - rise
      -- Dark outline
      love.graphics.setColor(0, 0, 0, fade * 0.7)
      love.graphics.printf(pop_text, tx + 2, ty + 2, 100, "center")
      -- Colored text
      love.graphics.setColor(rgb[1], rgb[2], rgb[3], fade)
      love.graphics.printf(pop_text, tx, ty, 100, "center")
    end
  end
end

--------------------------------------------------------------------------------
-- Screen lifecycle
--------------------------------------------------------------------------------

function game_2048_screen.enter()
  -- Compute progressive grid metrics from current upgrade levels
  local num_columns = upgrades.getBaseColumns()
  local num_rows = upgrades.getBaseRows()
  local metrics = layout.getGridMetrics(num_columns, num_rows)
  layout.applyMetrics(metrics)

  -- Refresh all module caches
  graphics.updateMetrics()
  input.updateMetrics()

  -- Update screen-local caches
  COLUMN_STEP = layout.COLUMN_STEP
  COIN_R = layout.COIN_R
  ROW_STEP = layout.ROW_STEP
  TOP_Y = layout.GRID_TOP_Y

  -- Recreate coin number font to match new COIN_R (halved for tight stacking)
  local fontScale = layout.USE_FRUIT_IMAGES and 0.35 or 0.6
  coinNumberFont = love.graphics.newFont("comic shanns.otf", math.floor(layout.COIN_R * fontScale))

  -- Store base values for debug slider
  base_coin_r = layout.COIN_R
  base_row_step = layout.ROW_STEP
  slider_dragging = false

  game_2048.init()
  currency.startRun()
  selection = nil
  shakeState.active = false
  hammer_mode = false
  flying_shards = {}
  hud_pops = {}
  resetState.held = false
  resetState.time = 0
end

function game_2048_screen.exit()
  -- Track game end
  local state = game_2048.getState()
  progression.onGameEnd("2048", state.points)
end

function game_2048_screen.update(dt)
  game_2048.update(dt)
  animation.update(dt)
  particles.update(dt)
  updateButtonAnimations(dt)
  upgrades.updateProduction(dt)
  updateSliderDrag()

  -- Update shake animation
  if shakeState.active then
    shakeState.time = shakeState.time + dt
    if shakeState.time >= shakeState.duration then
      shakeState.active = false
    end
  end

  updateFlyingShards(dt)

  -- Reset button hold tracking
  if resetState.held then
    if not love.mouse.isDown(1) then
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

function game_2048_screen.draw()
  local state = game_2048.getState()

  -- Apply screen shake
  local shake_x, shake_y = animation.getScreenShake()
  if shake_x ~= 0 or shake_y ~= 0 then
    love.graphics.push()
    love.graphics.translate(shake_x, shake_y)
  end

  graphics.drawBackground()
  drawCurrencyHUD()
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
  drawFlyingShards()

  draw_merge_button()
  draw_add_coins_button()
  drawPowerupButtons()
  drawHammerOverlay()
  drawSoundToggles()
  drawSlider()

  -- End screen shake
  if shake_x ~= 0 or shake_y ~= 0 then
    love.graphics.pop()
  end
end

function game_2048_screen.keypressed(key, scancode, isrepeat)
  if key == "\\" then
    love.event.quit()
  end
  if key == "escape" then
    if hammer_mode then
      hammer_mode = false
      return
    end
    screens.switch("upgrades")
  end
  if key == "f3" then
    -- Debug: give +10 of each crystal and go to upgrades
    local names = coin_utils.getShardNames()
    for _, name in ipairs(names) do
      currency.addCrystal(name, 10)
    end
    currency.save()
    screens.switch("upgrades")
  end
end

function game_2048_screen.mousepressed(x, y, button)
  if button ~= 1 then return end

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

  -- Check debug size slider
  if y >= SLIDER_Y - SLIDER_HANDLE_R and y <= SLIDER_Y + SLIDER_H + SLIDER_HANDLE_R
     and x >= SLIDER_X - SLIDER_HANDLE_R and x <= SLIDER_X + SLIDER_W + SLIDER_HANDLE_R then
    slider_dragging = true
    local t = math.max(0, math.min(1, (x - SLIDER_X) / SLIDER_W))
    size_scale = 0.5 + t * 1.5
    applySliderScale()
    return
  end

  -- Block all input only during flight (coins in transit)
  -- Allow picking/placing during merge and dealing for fast gameplay
  if animation.isFlying() then
    return
  end

  local state = game_2048.getState()
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
        local state = game_2048.getState()
        local removed = game_2048.clearColumn(bx)
        -- Spawn particles for each removed coin
        for slot, coin in ipairs(removed) do
          local px, py = layout.slotPosition(bx, slot)
          local num = coin_utils.getCoinNumber(coin)
          local col = coin_utils.numberToColor(num, state.MAX_NUMBER)
          particles.spawnMergeExplosion(px, py, col)
        end
        sound.playMerge()
        hammer_mode = false
        if game_2048.isGameOver() then
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
    local pack = game_2048.pick_coin_from_box(bx, {remove = true})
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
        game_2048.place_coin(source_box_idx, coin)
      end
      animation.cancel()
      selection = nil
      sound.playPickup()
      return
    end

    -- Validate placement
    local can_place, err_msg, available_slots = game_2048.can_place(bx, pack)
    if not can_place then
      -- Invalid placement: shake box and show error
      shakeState.active = true
      shakeState.box_index = bx
      shakeState.time = 0
      game_2048.setError(err_msg)
      mobile.vibrateError()
      return
    end

    -- Partial placement: if not all coins fit, return extras to source
    if available_slots < #pack then
      local returned_coins = animation.splitHoveringCoins(available_slots)
      -- Return extra coins to source box immediately
      for _, coin in ipairs(returned_coins) do
        game_2048.place_coin(source_box_idx, coin)
      end
    end

    -- Calculate destination slot
    local dest_slot = #state.boxes[bx] + 1

    -- Start flight with per-coin callback
    animation.startFlight(bx, dest_slot,
      -- Final callback: when all coins have landed
      function()
        selection = nil
        if game_2048.isGameOver() then
          screens.switch("game_over")
        end
      end,
      -- Per-coin callback: when each coin lands
      function(coin_data, slot)
        game_2048.place_coin(bx, coin_data)
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

function game_2048_screen.mousereleased(x, y, button)
  if button ~= 1 then return end

  -- Stop slider drag
  slider_dragging = false

  -- Release merge button
  if buttonState.merge.pressed then
    buttonState.merge.pressed = false
    buttonState.merge.targetScale = 1.0
    if input.isInsideButton(x, y, MERGE_BUTTON_X, MERGE_BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT) and not animation.isAnimating() then
      -- Get mergeable boxes and start animation
      local mergeable = game_2048.getMergeableBoxes()
      if #mergeable > 0 then
        animation.startMerge(mergeable,
          -- Final callback: when all boxes done
          function()
            if game_2048.isGameOver() then
              screens.switch("game_over")
            end
          end,
          -- Per-box callback: when each box finishes merging
          function(box_data)
            game_2048.executeMergeOnBox(box_data.box_idx)
            sound.playMerge()
            mobile.vibrateMerge()
            progression.onMerge("2048", 1)
            -- Spawn flying shard to HUD
            local from_x = box_data.slot_x[1]
            local from_y = box_data.slot_y[1]
            spawnFlyingShards(from_x, from_y, box_data.old_number, #box_data.coins)
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
      local coins_to_deal = game_2048.calculateCoinsToAdd()

      if #coins_to_deal > 0 then
        local state = game_2048.getState()

        animation.startDealing(coins_to_deal, "2048",
          -- Final callback: when all coins have landed
          function()
            if game_2048.isGameOver() then
              screens.switch("game_over")
            end
          end,
          -- Per-coin callback: when each coin lands
          function(coin_data, box_idx, slot)
            game_2048.place_coin(box_idx, coin_data)
            sound.playPickup()
            mobile.vibrateDrop()
            -- Spawn particle effect at landing position
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

  -- Release sort button
  if powerupButtonState.sort.pressed then
    powerupButtonState.sort.pressed = false
    powerupButtonState.sort.targetScale = 1.0
    if input.isInsideButton(x, y, SORT_BTN_X, POWERUP_Y, POWERUP_BTN_W, POWERUP_BTN_H)
       and not animation.isAnimating()
       and not animation.isHovering()
       and powerups.getAutoSortCount() > 0 then
      if powerups.useAutoSort() then
        local coins_to_deal = game_2048.autoSort()
        if #coins_to_deal > 0 then
          local state = game_2048.getState()
          animation.startDealing(coins_to_deal, "2048",
            function()
              if game_2048.isGameOver() then
                screens.switch("game_over")
              end
            end,
            function(coin_data, box_idx, slot)
              game_2048.place_coin(box_idx, coin_data)
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

return game_2048_screen
