-- upgrades_screen.lua
-- Meta/shop screen: crystal display, house grid, row/column upgrades, play button.
-- All upgrades cost 1 red + 1 green crystal. Row/column buy directly (no picker).
-- Houses use picker only for choosing production color.

local screens = require("screens")
local layout = require("layout")
local currency = require("currency")
local upgrades = require("upgrades")
local coin_utils = require("coin_utils")
local powerups = require("powerups")
local emoji = require("emoji")

local upgrades_screen = {}

local VW, VH = layout.VW, layout.VH
local font

-- Animation time for pulsating "+" buttons
local anim_time = 0

-- Notification state (timed error/info messages)
local notification = {
  message = "",
  timer = 0,
  duration = 2.0,
  type = "error",  -- "error" or "success"
  y = 0,           -- stored Y position (frozen at creation time)
}

-- Flying crystal animation state
local flying_crystals = {}

-- Flying crystal config
local FLY_DURATION = 0.6
local FLY_ARC_HEIGHT = 200
local FLY_POP_DURATION = 0.25
local FLY_POP_OVERSHOOT = 1.4

local function showNotification(msg, ntype)
  notification.message = msg
  notification.timer = notification.duration
  notification.type = ntype or "error"
  notification.y = (PLAY_BTN_Y or 1540) + (yoff or 0) - 80
end

-- Color picker state (only used for house production color)
local picker = {
  active = false,
  slot = 0,
  mode = "build",  -- "build" or "change"
}

-- Layout constants
local CRYSTAL_Y = 80
local HOUSE_Y = 370
local HOUSE_COLS = 3
local HOUSE_ROWS = 2
local HOUSE_W = 280
local HOUSE_H = 250
local HOUSE_PAD = 30

local UPGRADE_Y = 960
local UPGRADE_BTN_W = 420
local UPGRADE_BTN_H = 110
local UPGRADE_PAD = 40

local DIFFICULTY_Y = 1160
local DIFFICULTY_ARROW_W = 90
local DIFFICULTY_ARROW_H = 80
local DIFFICULTY_LABEL_W = 600

local POWERUP_SHOP_Y = 1280
local POWERUP_SHOP_BTN_W = 420
local POWERUP_SHOP_BTN_H = 110
local POWERUP_SHOP_PAD = 40

local PLAY_BTN_W = 500
local PLAY_BTN_H = 140
local PLAY_BTN_Y = 1540

-- Y offset when houses are locked (mystery section is shorter than house grid)
local LOCKED_Y_OFFSET = 410
-- Mystery/unlock section layout
local MYSTERY_Y = 350
local MYSTERY_BAR_W = 500
local MYSTERY_BAR_H = 24
local UNLOCK_BTN_W = 600
local UNLOCK_BTN_H = 120

-- Module-level Y offset (recomputed every frame)
local yoff = 0

-- Celebration firework particles (self-contained, upgrades screen only)
local fireworks = {}
local FIREWORK_GRAVITY = 800
local FIREWORK_MAX = 200

local function spawnFireworks(cx, cy, count)
  for i = 1, (count or 60) do
    local angle = math.random() * math.pi * 2
    local speed = 200 + math.random() * 600
    local hue = math.random()
    -- HSV inline (reuse hsvToRGB later, but it's not defined yet, so inline)
    local hi = math.floor(hue * 6) % 6
    local f = hue * 6 - math.floor(hue * 6)
    local r, g, b
    if hi == 0 then r, g, b = 1, f, 0
    elseif hi == 1 then r, g, b = 1 - f, 1, 0
    elseif hi == 2 then r, g, b = 0, 1, f
    elseif hi == 3 then r, g, b = 0, 1 - f, 1
    elseif hi == 4 then r, g, b = f, 0, 1
    else r, g, b = 1, 0, 1 - f end
    fireworks[#fireworks + 1] = {
      x = cx, y = cy,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed - 200,
      r = r, g = g, b = b,
      life = 1.0 + math.random() * 0.8,
      maxLife = 1.8,
      size = 4 + math.random() * 10,
      rotation = math.random() * math.pi * 2,
      rotSpeed = (math.random() - 0.5) * 10,
    }
  end
end

local function updateFireworks(dt)
  local i = 1
  while i <= #fireworks do
    local p = fireworks[i]
    p.vy = p.vy + FIREWORK_GRAVITY * dt
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.rotation = p.rotation + p.rotSpeed * dt
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(fireworks, i)
    else
      i = i + 1
    end
  end
end

local function drawFireworks()
  for _, p in ipairs(fireworks) do
    local alpha = math.min(p.life / 0.4, 1)
    local scale = 0.5 + (p.life / p.maxLife) * 0.5
    local sz = p.size * scale
    love.graphics.push()
    love.graphics.translate(p.x, p.y)
    love.graphics.rotate(p.rotation)
    love.graphics.setColor(p.r, p.g, p.b, alpha)
    love.graphics.rectangle("fill", -sz / 2, -sz / 2, sz, sz)
    -- Highlight
    if sz > 6 then
      love.graphics.setColor(1, 1, 1, alpha * 0.4)
      love.graphics.rectangle("fill", -sz / 2, -sz / 2, sz * 0.4, sz * 0.4)
    end
    love.graphics.pop()
  end
end

-- Precomputed positions
local house_positions = {}
local function calcHousePositions()
  local total_w = HOUSE_COLS * HOUSE_W + (HOUSE_COLS - 1) * HOUSE_PAD
  local start_x = (VW - total_w) / 2
  house_positions = {}
  for row = 0, HOUSE_ROWS - 1 do
    for col = 0, HOUSE_COLS - 1 do
      local idx = row * HOUSE_COLS + col + 1
      house_positions[idx] = {
        x = start_x + col * (HOUSE_W + HOUSE_PAD),
        y = HOUSE_Y + row * (HOUSE_H + HOUSE_PAD),
      }
    end
  end
end

-- Flying crystal animation helpers (after layout constants so locals are visible)
local function getCurrencyDiamondPos(color_name)
  local names = coin_utils.getShardNames()
  local spacing = 180
  local total_w = (#names - 1) * spacing
  local start_x = (VW - total_w) / 2
  for i, name in ipairs(names) do
    if name == color_name then
      return start_x + (i - 1) * spacing, CRYSTAL_Y + 60
    end
  end
  return VW / 2, CRYSTAL_Y + 60
end

local function spawnFlyingCrystal(slot, color_name)
  local pos = house_positions[slot]
  if not pos then return end
  local rgb = coin_utils.getShardRGB(color_name)
  local bar_x = pos.x + 30
  local bar_y = pos.y + 140
  local bar_w = HOUSE_W - 60
  local bar_h = 24
  local sx = bar_x + bar_w / 2
  local sy = bar_y + bar_h / 2
  local dx, dy = getCurrencyDiamondPos(color_name)
  flying_crystals[#flying_crystals + 1] = {
    sx = sx, sy = sy,
    dx = dx, dy = dy,
    color = rgb,
    color_name = color_name,
    elapsed = 0,
    phase = "fly",
    pop_elapsed = 0,
    scale = 1,
  }
end

local function updateFlyingCrystals(dt)
  local i = 1
  while i <= #flying_crystals do
    local fc = flying_crystals[i]
    if fc.phase == "fly" then
      fc.elapsed = fc.elapsed + dt
      local t = math.min(fc.elapsed / FLY_DURATION, 1)
      if t >= 1 then
        fc.phase = "pop"
        fc.pop_elapsed = 0
        fc.scale = FLY_POP_OVERSHOOT
      end
      i = i + 1
    elseif fc.phase == "pop" then
      fc.pop_elapsed = fc.pop_elapsed + dt
      local pt = math.min(fc.pop_elapsed / FLY_POP_DURATION, 1)
      fc.scale = 1 + (FLY_POP_OVERSHOOT - 1) * math.sin(pt * math.pi) * (1 - pt * 0.5)
      if pt >= 1 then
        table.remove(flying_crystals, i)
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end
end

local function drawFlyingCrystals()
  for _, fc in ipairs(flying_crystals) do
    local x, y, s
    if fc.phase == "fly" then
      local t = math.min(fc.elapsed / FLY_DURATION, 1)
      local ease = 1 - (1 - t) * (1 - t)
      x = fc.sx + (fc.dx - fc.sx) * ease
      y = fc.sy + (fc.dy - fc.sy) * ease - FLY_ARC_HEIGHT * math.sin(t * math.pi)
      s = 1 + 0.3 * math.sin(t * math.pi)
    else
      x = fc.dx
      y = fc.dy
      s = fc.scale
    end
    local size = 16 * s
    emoji.draw(fc.color_name, x, y, size)
  end
end

function upgrades_screen.init(assets)
  font = assets.font
  calcHousePositions()
end

function upgrades_screen.enter()
  picker.active = false
  anim_time = 0
  notification.timer = 0
  flying_crystals = {}
  fireworks = {}
end

function upgrades_screen.exit()
end

function upgrades_screen.update(dt)
  anim_time = anim_time + dt
  if notification.timer > 0 then
    notification.timer = notification.timer - dt
  end

  -- Tick house production and spawn flying crystals on events
  local events = upgrades.updateProduction(dt)
  for _, ev in ipairs(events) do
    spawnFlyingCrystal(ev.slot, ev.color)
  end

  updateFlyingCrystals(dt)
  updateFireworks(dt)
end

--------------------------------------------------------------------------------
-- Drawing helpers
--------------------------------------------------------------------------------

-- Draw the flat cost indicator: red dot + "1" + green dot + "1"
local function drawCostIndicator(x, y, affordable)
  local red_rgb = coin_utils.getShardRGB("red")
  local green_rgb = coin_utils.getShardRGB("green")
  local alpha = affordable and 1 or 0.4
  local dot_r = 12

  -- Red crystal dot + "1"
  love.graphics.setColor(red_rgb[1], red_rgb[2], red_rgb[3], alpha)
  love.graphics.circle("fill", x, y, dot_r)
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.printf("1", x + dot_r + 4, y - 14, 30, "left")

  -- "+" separator
  love.graphics.printf("+", x + dot_r + 30, y - 14, 20, "center")

  -- Green crystal dot + "1"
  love.graphics.setColor(green_rgb[1], green_rgb[2], green_rgb[3], alpha)
  love.graphics.circle("fill", x + dot_r + 60, y, dot_r)
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.printf("1", x + dot_r + 76, y - 14, 30, "left")
end

local function drawCurrencyDisplay()
  love.graphics.setFont(font)
  local names = coin_utils.getShardNames()
  local cr = currency.getCrystals()
  local sh = currency.getShards()
  local spc = currency.getShardsPerCrystal()

  love.graphics.setColor(0.9, 0.85, 0.3)
  love.graphics.printf("Crystals & Shards", 0, CRYSTAL_Y, VW, "center")

  local spacing = 180
  local total_w = (#names - 1) * spacing
  local start_x = (VW - total_w) / 2

  for i, name in ipairs(names) do
    local x = start_x + (i - 1) * spacing
    local y = CRYSTAL_Y + 60
    local rgb = coin_utils.getShardRGB(name)

    -- Emoji icon
    emoji.draw(name, x, y, 14)

    -- Crystal count
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(tostring(cr[name] or 0), x - 40, y + 20, 80, "center")

    -- Shard progress bar
    local bar_w = 60
    local bar_h = 10
    local bar_x = x - bar_w / 2
    local bar_y = y + 55
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 3, 3)
    local shard_count = sh[name] or 0
    local fill = math.min((shard_count / spc) * bar_w, bar_w)
    love.graphics.setColor(rgb[1] * 0.7, rgb[2] * 0.7, rgb[3] * 0.7)
    love.graphics.rectangle("fill", bar_x, bar_y, fill, bar_h, 3, 3)

    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.printf(shard_count .. "/" .. spc, x - 40, bar_y + bar_h + 2, 80, "center")
  end
end

local function drawHouseGrid()
  local houses = upgrades.getHouses()
  local cost = upgrades.getUpgradeCost()
  local affordable = currency.canAfford(cost)
  local has_free = upgrades.hasFreeHouse()
  love.graphics.setFont(font)

  love.graphics.setColor(0.7, 0.7, 0.7)
  love.graphics.printf("Houses", 0, HOUSE_Y - 55, VW, "center")

  for idx = 1, upgrades.getMaxHouses() do
    local pos = house_positions[idx]
    local house = houses[idx]

    if house.built then
      local rgb = coin_utils.getShardRGB(house.color)
      love.graphics.setColor(rgb[1] * 0.3, rgb[2] * 0.3, rgb[3] * 0.3)
      love.graphics.rectangle("fill", pos.x, pos.y, HOUSE_W, HOUSE_H, 10, 10)
      love.graphics.setColor(rgb[1], rgb[2], rgb[3])
      love.graphics.rectangle("line", pos.x, pos.y, HOUSE_W, HOUSE_H, 10, 10)

      love.graphics.setColor(rgb[1], rgb[2], rgb[3])
      love.graphics.circle("fill", pos.x + HOUSE_W / 2, pos.y + 70, 35)

      -- Progress bar
      local bar_x = pos.x + 30
      local bar_y = pos.y + 140
      local bar_w = HOUSE_W - 60
      local bar_h = 24
      love.graphics.setColor(0.2, 0.2, 0.2)
      love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 4, 4)
      local fill_w = bar_w * math.min(house.progress, 1.0)
      love.graphics.setColor(rgb[1], rgb[2], rgb[3])
      love.graphics.rectangle("fill", bar_x, bar_y, fill_w, bar_h, 4, 4)

      -- Countdown timer on progress bar
      local rate = upgrades.getHouseRate()
      local remaining_progress = 1.0 - house.progress
      local remaining_secs = remaining_progress / (rate / 60)
      local mins = math.floor(remaining_secs / 60)
      local secs = math.floor(remaining_secs % 60)
      local timer_text = string.format("%d:%02d", mins, secs)
      love.graphics.setColor(1, 1, 1, 0.9)
      love.graphics.printf(timer_text, bar_x, bar_y + 2, bar_w, "center")

      love.graphics.setColor(0.6, 0.6, 0.6)
      love.graphics.printf("tap: color", pos.x, pos.y + HOUSE_H - 40, HOUSE_W, "center")
    else
      -- Empty slot - check if first empty gets the free badge
      local slot_free = has_free
      local slot_affordable = slot_free or affordable

      love.graphics.setColor(0.15, 0.15, 0.15)
      love.graphics.rectangle("fill", pos.x, pos.y, HOUSE_W, HOUSE_H, 10, 10)
      if slot_free then
        -- Golden pulsating border for free slot
        local pulse = 0.5 + 0.5 * math.sin(anim_time * 3 + idx)
        love.graphics.setColor(0.9, 0.8, 0.2, 0.5 + 0.5 * pulse)
      else
        love.graphics.setColor(slot_affordable and {0.3, 0.5, 0.3} or {0.25, 0.25, 0.25})
      end
      love.graphics.rectangle("line", pos.x, pos.y, HOUSE_W, HOUSE_H, 10, 10)

      -- Pulsating "+"
      local pulse = 0.5 + 0.5 * math.sin(anim_time * 2 + idx)
      local scale = 0.9 + 0.1 * pulse
      if slot_free then
        love.graphics.setColor(0.9, 0.85, 0.2, 0.6 + 0.4 * pulse)
      elseif slot_affordable then
        love.graphics.setColor(0.2, 0.8, 0.3, 0.5 + 0.5 * pulse)
      else
        love.graphics.setColor(0.35, 0.35, 0.35, 0.3 + 0.2 * pulse)
      end
      local cx, cy = pos.x + HOUSE_W / 2, pos.y + HOUSE_H / 2 - 30
      local arm = 30 * scale
      love.graphics.setLineWidth(8)
      love.graphics.line(cx - arm, cy, cx + arm, cy)
      love.graphics.line(cx, cy - arm, cx, cy + arm)
      love.graphics.setLineWidth(1)

      -- Cost indicator or FREE badge
      if slot_free then
        love.graphics.setColor(0.9, 0.85, 0.2)
        love.graphics.printf("FREE!", pos.x, pos.y + HOUSE_H - 42, HOUSE_W, "center")
      else
        drawCostIndicator(pos.x + HOUSE_W / 2 - 50, pos.y + HOUSE_H - 35, affordable)
      end

      -- Only the first empty slot gets the free token
      if has_free then has_free = false end
    end
  end
end

-- HSV to RGB helper for rainbow cycling
local function hsvToRGB(h, s, v)
  local i = math.floor(h * 6)
  local f = h * 6 - i
  local p = v * (1 - s)
  local q = v * (1 - f * s)
  local t = v * (1 - (1 - f) * s)
  i = i % 6
  if i == 0 then return v, t, p
  elseif i == 1 then return q, v, p
  elseif i == 2 then return p, v, t
  elseif i == 3 then return p, q, v
  elseif i == 4 then return t, p, v
  else return v, p, q end
end

local function drawMysteryProgress()
  love.graphics.setFont(font)
  local unique = upgrades.getUniqueColorCount()
  local cx = VW / 2
  local y = MYSTERY_Y

  -- Lock icon (simple padlock)
  local lock_w, lock_h = 40, 36
  local lock_x = cx - lock_w / 2
  local lock_y = y
  love.graphics.setColor(0.5, 0.5, 0.5, 0.7)
  -- Arc (shackle)
  love.graphics.setLineWidth(6)
  love.graphics.arc("line", "open", cx, lock_y, 16, math.pi, 0)
  -- Body
  love.graphics.setColor(0.4, 0.4, 0.4, 0.8)
  love.graphics.rectangle("fill", lock_x, lock_y, lock_w, lock_h, 4, 4)
  -- Keyhole
  love.graphics.setColor(0.2, 0.2, 0.2)
  love.graphics.circle("fill", cx, lock_y + lock_h / 2 - 4, 6)
  love.graphics.rectangle("fill", cx - 3, lock_y + lock_h / 2, 6, 10)
  love.graphics.setLineWidth(1)

  -- "???" label
  love.graphics.setColor(0.6, 0.6, 0.6, 0.8)
  love.graphics.printf("???", 0, y + lock_h + 10, VW, "center")

  -- Progress bar with rainbow fill
  local bar_x = cx - MYSTERY_BAR_W / 2
  local bar_y = y + lock_h + 55
  -- Background
  love.graphics.setColor(0.15, 0.15, 0.15)
  love.graphics.rectangle("fill", bar_x, bar_y, MYSTERY_BAR_W, MYSTERY_BAR_H, 6, 6)
  -- Rainbow fill
  local fill_w = (unique / 5) * MYSTERY_BAR_W
  if fill_w > 0 then
    local segments = math.max(1, math.floor(fill_w / 3))
    for seg = 0, segments - 1 do
      local sx = bar_x + seg * 3
      local sw = math.min(3, fill_w - seg * 3)
      if sw <= 0 then break end
      local hue = ((seg / segments) + anim_time * 0.3) % 1.0
      local r, g, b = hsvToRGB(hue, 0.7, 0.85)
      love.graphics.setColor(r, g, b)
      love.graphics.rectangle("fill", sx, bar_y, sw, MYSTERY_BAR_H)
    end
    -- Round corners by redrawing border
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    love.graphics.rectangle("line", bar_x, bar_y, MYSTERY_BAR_W, MYSTERY_BAR_H, 6, 6)
  end

  -- Counter
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf(unique .. " / 5", 0, bar_y + MYSTERY_BAR_H + 8, VW, "center")
end

local function drawUnlockButton()
  love.graphics.setFont(font)
  local cx = VW / 2
  local btn_x = cx - UNLOCK_BTN_W / 2
  local btn_y = MYSTERY_Y

  -- Rainbow pulsating border
  local pulse = 0.7 + 0.3 * math.sin(anim_time * 3)
  love.graphics.setColor(0.1, 0.1, 0.14)
  love.graphics.rectangle("fill", btn_x, btn_y, UNLOCK_BTN_W, UNLOCK_BTN_H, 12, 12)

  -- Rainbow cycling border
  love.graphics.setLineWidth(4)
  local hue = (anim_time * 0.5) % 1.0
  local r, g, b = hsvToRGB(hue, 0.6, 0.9 * pulse)
  love.graphics.setColor(r, g, b)
  love.graphics.rectangle("line", btn_x, btn_y, UNLOCK_BTN_W, UNLOCK_BTN_H, 12, 12)
  love.graphics.setLineWidth(1)

  -- "UNLOCK" text
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("UNLOCK", btn_x, btn_y + 15, UNLOCK_BTN_W, "center")

  -- Row of 5 color emoji with "1" cost each
  local names = coin_utils.getShardNames()
  local icon_spacing = 100
  local icons_w = (#names - 1) * icon_spacing
  local icons_x = cx - icons_w / 2
  local icons_y = btn_y + 75
  for i, name in ipairs(names) do
    local ix = icons_x + (i - 1) * icon_spacing
    emoji.draw(name, ix, icons_y, 12)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf("1", ix + 14, icons_y - 10, 30, "left")
  end
end

local function drawUpgradeButtons()
  love.graphics.setFont(font)
  local uy = UPGRADE_Y + yoff
  local cost = upgrades.getUpgradeCost()
  local affordable = currency.canAfford(cost)
  local total_w = UPGRADE_BTN_W * 2 + UPGRADE_PAD
  local start_x = (VW - total_w) / 2

  -- Row upgrade
  local row_x = start_x
  local row_maxed = not upgrades.canBuyRow()

  if row_maxed then
    love.graphics.setColor(0.25, 0.25, 0.25)
  elseif affordable then
    love.graphics.setColor(0.2, 0.5, 0.2)
  else
    love.graphics.setColor(0.22, 0.22, 0.22)
  end
  love.graphics.rectangle("fill", row_x, uy, UPGRADE_BTN_W, UPGRADE_BTN_H, 10, 10)

  love.graphics.setColor(1, 1, 1, (row_maxed or not affordable) and 0.4 or 1)
  love.graphics.printf(row_maxed and "Rows MAX" or "Buy Row",
    row_x, uy + 15, UPGRADE_BTN_W, "center")

  if not row_maxed then
    drawCostIndicator(row_x + UPGRADE_BTN_W / 2 - 50, uy + UPGRADE_BTN_H - 25, affordable)
  end

  love.graphics.setColor(0.6, 0.6, 0.6)
  love.graphics.printf("Rows: " .. upgrades.getBaseRows(),
    row_x, uy + UPGRADE_BTN_H + 10, UPGRADE_BTN_W, "center")

  -- Column upgrade
  local col_x = start_x + UPGRADE_BTN_W + UPGRADE_PAD
  local col_maxed = not upgrades.canBuyColumn()

  if col_maxed then
    love.graphics.setColor(0.25, 0.25, 0.25)
  elseif affordable then
    love.graphics.setColor(0.2, 0.5, 0.2)
  else
    love.graphics.setColor(0.22, 0.22, 0.22)
  end
  love.graphics.rectangle("fill", col_x, uy, UPGRADE_BTN_W, UPGRADE_BTN_H, 10, 10)

  love.graphics.setColor(1, 1, 1, (col_maxed or not affordable) and 0.4 or 1)
  love.graphics.printf(col_maxed and "Cols MAX" or "Buy Column",
    col_x, uy + 15, UPGRADE_BTN_W, "center")

  if not col_maxed then
    drawCostIndicator(col_x + UPGRADE_BTN_W / 2 - 50, uy + UPGRADE_BTN_H - 25, affordable)
  end

  love.graphics.setColor(0.6, 0.6, 0.6)
  love.graphics.printf("Cols: " .. upgrades.getBaseColumns(),
    col_x, uy + UPGRADE_BTN_H + 10, UPGRADE_BTN_W, "center")
end

local function getDifficultyLabel(extra)
  if extra == 0 then return "Normal" end
  if extra == 1 then return "Hard" end
  if extra == 2 then return "Extreme" end
  return "Extreme+" .. (extra - 2)
end

local function getDifficultyColor(extra)
  if extra == 0 then return {1, 1, 1} end
  if extra == 1 then return {1, 0.75, 0.2} end
  return {1, 0.3, 0.3}
end

local function drawDifficultyToggle()
  love.graphics.setFont(font)
  local dy = DIFFICULTY_Y + yoff
  local current = upgrades.getDifficultyExtraTypes()
  local max_extra = upgrades.getMaxDifficultyExtraTypes()
  local multiplier = upgrades.getShardBonusMultiplier()
  local bonus_pct = math.floor((multiplier - 1.0) * 100 + 0.5)

  local label = getDifficultyLabel(current)
  local tint = getDifficultyColor(current)

  -- Center the row: [<] LABEL [>]
  local total_w = DIFFICULTY_ARROW_W + DIFFICULTY_LABEL_W + DIFFICULTY_ARROW_W
  local start_x = (VW - total_w) / 2

  -- Left arrow
  local left_x = start_x
  local can_decrease = current > 0
  love.graphics.setColor(can_decrease and {0.3, 0.3, 0.4} or {0.15, 0.15, 0.15})
  love.graphics.rectangle("fill", left_x, dy, DIFFICULTY_ARROW_W, DIFFICULTY_ARROW_H, 8, 8)
  love.graphics.setColor(1, 1, 1, can_decrease and 1 or 0.3)
  love.graphics.printf("<", left_x, dy + (DIFFICULTY_ARROW_H - layout.FONT_SIZE) / 2, DIFFICULTY_ARROW_W, "center")

  -- Center label area
  local label_x = left_x + DIFFICULTY_ARROW_W
  love.graphics.setColor(0.12, 0.12, 0.16)
  love.graphics.rectangle("fill", label_x, dy, DIFFICULTY_LABEL_W, DIFFICULTY_ARROW_H, 8, 8)

  -- Difficulty name + bonus
  love.graphics.setColor(tint[1], tint[2], tint[3])
  local bonus_text = bonus_pct > 0 and (" (+" .. bonus_pct .. "% shards)") or ""
  love.graphics.printf("DIFFICULTY: " .. label .. bonus_text,
    label_x, dy + 10, DIFFICULTY_LABEL_W, "center")

  -- Buffer / types stats line
  local cols = upgrades.getBaseColumns()
  local default_types = math.floor(cols * 0.70)
  local actual_types = default_types + current
  if actual_types >= cols then actual_types = cols - 1 end
  local buffer_pct = math.floor(((cols - actual_types) / cols) * 100 + 0.5)
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("Buffer: " .. buffer_pct .. "%  |  Types: " .. actual_types .. "/" .. cols .. " cols",
    label_x, dy + 46, DIFFICULTY_LABEL_W, "center")

  -- Right arrow
  local right_x = label_x + DIFFICULTY_LABEL_W
  local can_increase = current < max_extra
  love.graphics.setColor(can_increase and {0.3, 0.3, 0.4} or {0.15, 0.15, 0.15})
  love.graphics.rectangle("fill", right_x, dy, DIFFICULTY_ARROW_W, DIFFICULTY_ARROW_H, 8, 8)
  love.graphics.setColor(1, 1, 1, can_increase and 1 or 0.3)
  love.graphics.printf(">", right_x, dy + (DIFFICULTY_ARROW_H - layout.FONT_SIZE) / 2, DIFFICULTY_ARROW_W, "center")
end

-- Draw a generic cost indicator from a cost table, e.g. {red=2, green=2} or {red=1}
local function drawCostTable(x, y, cost, affordable)
  local alpha = affordable and 1 or 0.4
  local dot_r = 12
  local offset = 0
  local first = true
  -- Sort keys for consistent order
  local keys = {}
  for k in pairs(cost) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, color in ipairs(keys) do
    local amount = cost[color]
    if not first then
      love.graphics.setColor(1, 1, 1, alpha)
      love.graphics.printf("+", x + offset, y - 14, 20, "center")
      offset = offset + 24
    end
    local rgb = coin_utils.getShardRGB(color)
    love.graphics.setColor(rgb[1], rgb[2], rgb[3], alpha)
    love.graphics.circle("fill", x + offset, y, dot_r)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf(tostring(amount), x + offset + dot_r + 4, y - 14, 30, "left")
    offset = offset + dot_r + 38
    first = false
  end
end

local function drawPowerupShop()
  love.graphics.setFont(font)
  local py = POWERUP_SHOP_Y + yoff
  love.graphics.setColor(0.7, 0.7, 0.7)
  love.graphics.printf("Power-ups", 0, py - 40, VW, "center")

  local total_w = POWERUP_SHOP_BTN_W * 2 + POWERUP_SHOP_PAD
  local start_x = (VW - total_w) / 2

  -- Buy Sort button
  local sort_x = start_x
  local sort_cost = powerups.getSortCost()
  local sort_affordable = currency.canAfford(sort_cost)
  local sort_count = powerups.getAutoSortCount()

  if sort_affordable then
    love.graphics.setColor(0.2, 0.4, 0.55)
  else
    love.graphics.setColor(0.22, 0.22, 0.22)
  end
  love.graphics.rectangle("fill", sort_x, py, POWERUP_SHOP_BTN_W, POWERUP_SHOP_BTN_H, 10, 10)

  love.graphics.setColor(1, 1, 1, sort_affordable and 1 or 0.4)
  love.graphics.printf("Buy Sort (x" .. sort_count .. ")",
    sort_x, py + 12, POWERUP_SHOP_BTN_W, "center")

  drawCostTable(sort_x + POWERUP_SHOP_BTN_W / 2 - 70, py + POWERUP_SHOP_BTN_H - 25, sort_cost, sort_affordable)

  -- Buy Hammer button
  local hammer_x = start_x + POWERUP_SHOP_BTN_W + POWERUP_SHOP_PAD
  local hammer_cost = powerups.getHammerCost()
  local hammer_affordable = currency.canAfford(hammer_cost)
  local hammer_count = powerups.getHammerCount()

  if hammer_affordable then
    love.graphics.setColor(0.55, 0.3, 0.2)
  else
    love.graphics.setColor(0.22, 0.22, 0.22)
  end
  love.graphics.rectangle("fill", hammer_x, py, POWERUP_SHOP_BTN_W, POWERUP_SHOP_BTN_H, 10, 10)

  love.graphics.setColor(1, 1, 1, hammer_affordable and 1 or 0.4)
  love.graphics.printf("Buy Hammer (x" .. hammer_count .. ")",
    hammer_x, py + 12, POWERUP_SHOP_BTN_W, "center")

  drawCostTable(hammer_x + POWERUP_SHOP_BTN_W / 2 - 30, py + POWERUP_SHOP_BTN_H - 25, hammer_cost, hammer_affordable)
end

local function drawPlayButton()
  local by = PLAY_BTN_Y + yoff
  local x = (VW - PLAY_BTN_W) / 2
  love.graphics.setColor(0.2, 0.75, 0.3)
  love.graphics.rectangle("fill", x, by, PLAY_BTN_W, PLAY_BTN_H, 14, 14)
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(font)
  love.graphics.printf("PLAY", x, by + (PLAY_BTN_H - layout.FONT_SIZE) / 2, PLAY_BTN_W, "center")
end

local function drawNotification()
  if notification.timer <= 0 then return end
  local ny = notification.y
  local alpha = math.min(notification.timer / 0.3, 1)
  if notification.type == "success" then
    love.graphics.setColor(0.9, 0.85, 0.2, alpha)
  else
    love.graphics.setColor(1, 0.25, 0.25, alpha)
  end
  love.graphics.setFont(font)
  love.graphics.printf(notification.message, 0, ny, VW, "center")
end

-- Color picker (house production color only)
local PICKER_W, PICKER_H = 700, 450
local PICKER_X = (VW - PICKER_W) / 2
local PICKER_BTN_SIZE = 80
local PICKER_BTN_PAD = 20

local function getPickerY()
  return (VH - PICKER_H) / 2
end

local function getPickerColorPositions()
  local names = coin_utils.getShardNames()
  local total = #names * PICKER_BTN_SIZE + (#names - 1) * PICKER_BTN_PAD
  local sx = PICKER_X + (PICKER_W - total) / 2
  local sy = getPickerY() + 120
  local positions = {}
  for i = 1, #names do
    positions[i] = {
      x = sx + (i - 1) * (PICKER_BTN_SIZE + PICKER_BTN_PAD),
      y = sy,
    }
  end
  return positions
end

local function drawColorPicker()
  if not picker.active then return end

  local py = getPickerY()

  -- Overlay
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, VW, VH)

  -- Panel
  love.graphics.setColor(0.15, 0.15, 0.15)
  love.graphics.rectangle("fill", PICKER_X, py, PICKER_W, PICKER_H, 12, 12)
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.rectangle("line", PICKER_X, py, PICKER_W, PICKER_H, 12, 12)

  -- Title
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(font)
  local title = picker.mode == "build" and "Choose Production Color" or "Change Production Color"
  love.graphics.printf(title, PICKER_X, py + 25, PICKER_W, "center")

  if picker.mode == "build" then
    if upgrades.hasFreeHouse() then
      love.graphics.setColor(0.9, 0.85, 0.2)
      love.graphics.printf("FREE!", PICKER_X, py + 70, PICKER_W, "center")
    else
      love.graphics.setColor(0.9, 0.85, 0.3)
      love.graphics.printf("Cost:", PICKER_X + PICKER_W / 2 - 120, py + 70, 80, "right")
      drawCostIndicator(PICKER_X + PICKER_W / 2 - 30, py + 82, true)
    end
  end

  -- Color buttons
  local names = coin_utils.getShardNames()
  local positions = getPickerColorPositions()
  for i, name in ipairs(names) do
    local pos = positions[i]
    local rgb = coin_utils.getShardRGB(name)
    local cx, cy = pos.x + PICKER_BTN_SIZE / 2, pos.y + PICKER_BTN_SIZE / 2

    love.graphics.setColor(rgb[1], rgb[2], rgb[3])
    love.graphics.circle("fill", cx, cy, PICKER_BTN_SIZE / 2)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(name, pos.x - 10, pos.y + PICKER_BTN_SIZE + 8, PICKER_BTN_SIZE + 20, "center")
  end

  -- Cancel button
  local cancel_x = PICKER_X + PICKER_W / 2 - 100
  local cancel_y = py + PICKER_H - 70
  love.graphics.setColor(0.5, 0.2, 0.2)
  love.graphics.rectangle("fill", cancel_x, cancel_y, 200, 55, 8, 8)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Cancel", cancel_x, cancel_y + 12, 200, "center")
end

local function drawBestCoinStat()
  local best = upgrades.getMaxCoinReached()
  if best <= 0 then return end
  local col = coin_utils.numberToColor(best, 50)
  local cx = VW / 2 - 60
  local y = 65

  -- Emoji icon for best coin color
  local best_color_name = coin_utils.numberToShardColor(best)
  emoji.draw(best_color_name, cx, y, 10)

  -- Label
  love.graphics.setColor(col[1], col[2], col[3], 0.9)
  love.graphics.setFont(font)
  love.graphics.printf("Best Coin: " .. best, cx + 14, y - 14, 200, "left")
end

function upgrades_screen.draw()
  love.graphics.clear(0.08, 0.08, 0.12)

  -- Compute Y offset based on house unlock state
  yoff = upgrades.isHousesUnlocked() and 0 or -LOCKED_Y_OFFSET

  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(font)
  love.graphics.printf("Upgrades", 0, 30, VW, "center")

  drawBestCoinStat()
  drawCurrencyDisplay()

  if upgrades.isHousesUnlocked() then
    drawHouseGrid()
    drawFlyingCrystals()
  else
    local can_afford_rainbow = currency.canAfford(upgrades.getRainbowCost())
    if can_afford_rainbow then
      drawUnlockButton()
    else
      drawMysteryProgress()
    end
  end

  drawUpgradeButtons()
  drawDifficultyToggle()
  drawPowerupShop()
  drawPlayButton()
  drawNotification()
  drawFireworks()
  drawColorPicker()
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

local function handlePickerClick(x, y)
  if not picker.active then return false end

  local py = getPickerY()
  local names = coin_utils.getShardNames()
  local positions = getPickerColorPositions()

  -- Check color button clicks
  for i, name in ipairs(names) do
    local pos = positions[i]
    local cx, cy = pos.x + PICKER_BTN_SIZE / 2, pos.y + PICKER_BTN_SIZE / 2
    local dist = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
    if dist <= PICKER_BTN_SIZE / 2 then
      if picker.mode == "build" then
        local success = upgrades.buildHouse(picker.slot, name)
        if not success then
          showNotification("Not enough red + green crystals!")
          return true
        end
      else
        upgrades.setHouseColor(picker.slot, name)
      end
      picker.active = false
      return true
    end
  end

  -- Cancel button
  local cancel_x = PICKER_X + PICKER_W / 2 - 100
  local cancel_y = py + PICKER_H - 70
  if x >= cancel_x and x <= cancel_x + 200 and y >= cancel_y and y <= cancel_y + 55 then
    picker.active = false
    return true
  end

  -- Click outside panel = cancel
  if x < PICKER_X or x > PICKER_X + PICKER_W or y < py or y > py + PICKER_H then
    picker.active = false
    return true
  end

  return true
end

local function handleHouseClick(x, y)
  local houses = upgrades.getHouses()
  local has_free = upgrades.hasFreeHouse()
  for idx = 1, upgrades.getMaxHouses() do
    local pos = house_positions[idx]
    if x >= pos.x and x <= pos.x + HOUSE_W and y >= pos.y and y <= pos.y + HOUSE_H then
      if houses[idx].built then
        picker.active = true
        picker.slot = idx
        picker.mode = "change"
      else
        -- Free house token or crystal cost
        if has_free then
          picker.active = true
          picker.slot = idx
          picker.mode = "build"
        elseif not currency.canAfford(upgrades.getUpgradeCost()) then
          showNotification("Not enough crystals! Need 1 red + 1 green")
        else
          picker.active = true
          picker.slot = idx
          picker.mode = "build"
        end
      end
      return true
    end
  end
  return false
end

local function handleUpgradeClick(x, y)
  local uy = UPGRADE_Y + yoff
  local total_w = UPGRADE_BTN_W * 2 + UPGRADE_PAD
  local start_x = (VW - total_w) / 2

  -- Row upgrade button (direct buy, no picker)
  local row_x = start_x
  if x >= row_x and x <= row_x + UPGRADE_BTN_W and y >= uy and y <= uy + UPGRADE_BTN_H then
    if not upgrades.canBuyRow() then
      showNotification("Rows already at maximum!")
    elseif not currency.canAfford(upgrades.getUpgradeCost()) then
      showNotification("Not enough crystals! Need 1 red + 1 green")
    else
      upgrades.buyRow()
    end
    return true
  end

  -- Column upgrade button (direct buy, no picker)
  local col_x = start_x + UPGRADE_BTN_W + UPGRADE_PAD
  if x >= col_x and x <= col_x + UPGRADE_BTN_W and y >= uy and y <= uy + UPGRADE_BTN_H then
    if not upgrades.canBuyColumn() then
      showNotification("Columns already at maximum!")
    elseif not currency.canAfford(upgrades.getUpgradeCost()) then
      showNotification("Not enough crystals! Need 1 red + 1 green")
    else
      upgrades.buyColumn()
    end
    return true
  end

  return false
end

local function handleDifficultyClick(x, y)
  local dy = DIFFICULTY_Y + yoff
  local total_w = DIFFICULTY_ARROW_W + DIFFICULTY_LABEL_W + DIFFICULTY_ARROW_W
  local start_x = (VW - total_w) / 2

  -- Only respond to clicks in the difficulty row area
  if y < dy or y > dy + DIFFICULTY_ARROW_H then
    return false
  end

  local current = upgrades.getDifficultyExtraTypes()
  local max_extra = upgrades.getMaxDifficultyExtraTypes()

  -- Left arrow
  local left_x = start_x
  if x >= left_x and x <= left_x + DIFFICULTY_ARROW_W then
    if current > 0 then
      upgrades.setDifficultyExtraTypes(current - 1)
    end
    return true
  end

  -- Right arrow
  local right_x = start_x + DIFFICULTY_ARROW_W + DIFFICULTY_LABEL_W
  if x >= right_x and x <= right_x + DIFFICULTY_ARROW_W then
    if current < max_extra then
      upgrades.setDifficultyExtraTypes(current + 1)
    end
    return true
  end

  return false
end

local function handlePowerupShopClick(x, y)
  local py = POWERUP_SHOP_Y + yoff
  local total_w = POWERUP_SHOP_BTN_W * 2 + POWERUP_SHOP_PAD
  local start_x = (VW - total_w) / 2

  -- Buy Sort
  local sort_x = start_x
  if x >= sort_x and x <= sort_x + POWERUP_SHOP_BTN_W
     and y >= py and y <= py + POWERUP_SHOP_BTN_H then
    if not currency.canAfford(powerups.getSortCost()) then
      showNotification("Not enough crystals! Need 2 red + 2 green")
    else
      powerups.buyAutoSort()
    end
    return true
  end

  -- Buy Hammer
  local hammer_x = start_x + POWERUP_SHOP_BTN_W + POWERUP_SHOP_PAD
  if x >= hammer_x and x <= hammer_x + POWERUP_SHOP_BTN_W
     and y >= py and y <= py + POWERUP_SHOP_BTN_H then
    if not currency.canAfford(powerups.getHammerCost()) then
      showNotification("Not enough crystals! Need 1 red")
    else
      powerups.buyHammer()
    end
    return true
  end

  return false
end

local function handleUnlockClick(x, y)
  if upgrades.isHousesUnlocked() then return false end
  if not currency.canAfford(upgrades.getRainbowCost()) then return false end
  local btn_x = (VW - UNLOCK_BTN_W) / 2
  local btn_y = MYSTERY_Y
  if x >= btn_x and x <= btn_x + UNLOCK_BTN_W and y >= btn_y and y <= btn_y + UNLOCK_BTN_H then
    if upgrades.unlockHouses() then
      showNotification("Houses unlocked! First one is FREE!", "success")
      -- Spawn firework bursts from multiple points
      local cx = VW / 2
      local cy = MYSTERY_Y + UNLOCK_BTN_H / 2
      spawnFireworks(cx, cy, 80)
      spawnFireworks(cx - 200, cy - 60, 40)
      spawnFireworks(cx + 200, cy - 60, 40)
    end
    return true
  end
  return false
end

local function handlePlayClick(x, y)
  local by = PLAY_BTN_Y + yoff
  local px = (VW - PLAY_BTN_W) / 2
  if x >= px and x <= px + PLAY_BTN_W and y >= by and y <= by + PLAY_BTN_H then
    screens.switch("coin_sort")
    return true
  end
  return false
end

function upgrades_screen.mousepressed(x, y, button)
  if button ~= 1 then return end

  -- Compute Y offset for click handlers
  yoff = upgrades.isHousesUnlocked() and 0 or -LOCKED_Y_OFFSET

  if picker.active then
    handlePickerClick(x, y)
    return
  end

  if upgrades.isHousesUnlocked() then
    if handleHouseClick(x, y) then return end
  else
    if handleUnlockClick(x, y) then return end
  end
  if handleUpgradeClick(x, y) then return end
  if handleDifficultyClick(x, y) then return end
  if handlePowerupShopClick(x, y) then return end
  if handlePlayClick(x, y) then return end
end

function upgrades_screen.keypressed(key)
  if key == "escape" then
    picker.active = false
  end
  if key == "return" or key == "space" then
    if not picker.active then
      screens.switch("coin_sort")
    end
  end
  if key == "\\" then
    love.event.quit()
  end
end

return upgrades_screen
