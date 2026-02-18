-- upgrades_screen.lua
-- Meta/shop screen: crystal display, house grid, row/column upgrades, play button.

local screens = require("screens")
local layout = require("layout")
local currency = require("currency")
local upgrades = require("upgrades")
local coin_utils = require("coin_utils")

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
}

local function showNotification(msg)
  notification.message = msg
  notification.timer = notification.duration
end

-- Color picker state
local picker = {
  active = false,
  slot = 0,
  mode = "build",  -- "build", "change", "buy_row", "buy_column"
  cost = 0,        -- crystal cost (0 for "change" mode)
}

-- Layout constants
local CRYSTAL_Y = 100
local HOUSE_Y = 460
local HOUSE_COLS = 3
local HOUSE_ROWS = 2
local HOUSE_W = 280
local HOUSE_H = 250
local HOUSE_PAD = 30

local UPGRADE_Y = 1200
local UPGRADE_BTN_W = 420
local UPGRADE_BTN_H = 110
local UPGRADE_PAD = 40

local PLAY_BTN_W = 500
local PLAY_BTN_H = 140
local PLAY_BTN_Y = 1800

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

-- Check if any crystal color can afford a cost
local function canAffordAny(cost)
  if cost <= 0 then return true end
  local cr = currency.getCrystals()
  for _, name in ipairs(coin_utils.getShardNames()) do
    if (cr[name] or 0) >= cost then return true end
  end
  return false
end

function upgrades_screen.init(assets)
  font = assets.font
  calcHousePositions()
end

function upgrades_screen.enter()
  picker.active = false
  anim_time = 0
  notification.timer = 0
end

function upgrades_screen.exit()
end

function upgrades_screen.update(dt)
  anim_time = anim_time + dt
  if notification.timer > 0 then
    notification.timer = notification.timer - dt
  end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

local function drawCurrencyDisplay()
  love.graphics.setFont(font)
  local names = coin_utils.getShardNames()
  local cr = currency.getCrystals()
  local sh = currency.getShards()
  local spc = currency.getShardsPerCrystal()

  -- Title
  love.graphics.setColor(0.9, 0.85, 0.3)
  love.graphics.printf("Crystals & Shards", 0, CRYSTAL_Y, VW, "center")

  local spacing = 190
  local total_w = (#names - 1) * spacing
  local start_x = (VW - total_w) / 2

  for i, name in ipairs(names) do
    local x = start_x + (i - 1) * spacing
    local y = CRYSTAL_Y + 60
    local rgb = coin_utils.getShardRGB(name)

    -- Diamond shape for crystal
    love.graphics.setColor(rgb[1], rgb[2], rgb[3])
    love.graphics.polygon("fill",
      x, y - 18, x + 16, y, x, y + 18, x - 16, y)

    -- Crystal count (big)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(tostring(cr[name] or 0), x - 40, y + 25, 80, "center")

    -- Shard progress bar
    local bar_w = 80
    local bar_h = 14
    local bar_x = x - bar_w / 2
    local bar_y = y + 65
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 3, 3)
    local shard_count = sh[name] or 0
    local fill = math.min((shard_count / spc) * bar_w, bar_w)
    love.graphics.setColor(rgb[1] * 0.7, rgb[2] * 0.7, rgb[3] * 0.7)
    love.graphics.rectangle("fill", bar_x, bar_y, fill, bar_h, 3, 3)

    -- Shard count text
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.printf(shard_count .. "/" .. spc, x - 40, bar_y + bar_h + 2, 80, "center")
  end
end

local function drawHouseGrid()
  local houses = upgrades.getHouses()
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

      -- Color indicator circle
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

      love.graphics.setColor(0.6, 0.6, 0.6)
      love.graphics.printf("tap: color", pos.x, pos.y + HOUSE_H - 40, HOUSE_W, "center")
    else
      -- Empty slot
      local cost = upgrades.getHouseCost(idx)
      local affordable = cost and canAffordAny(cost)

      love.graphics.setColor(0.15, 0.15, 0.15)
      love.graphics.rectangle("fill", pos.x, pos.y, HOUSE_W, HOUSE_H, 10, 10)
      love.graphics.setColor(affordable and {0.3, 0.5, 0.3} or {0.3, 0.2, 0.2})
      love.graphics.rectangle("line", pos.x, pos.y, HOUSE_W, HOUSE_H, 10, 10)

      -- Pulsating "+" (green if affordable, dim red if not)
      local pulse = 0.5 + 0.5 * math.sin(anim_time * 2 + idx)
      local scale = 0.9 + 0.1 * pulse
      if affordable then
        love.graphics.setColor(0.2, 0.8, 0.3, 0.5 + 0.5 * pulse)
      else
        love.graphics.setColor(0.5, 0.2, 0.2, 0.3 + 0.2 * pulse)
      end
      local cx, cy = pos.x + HOUSE_W / 2, pos.y + HOUSE_H / 2 - 20
      local arm = 30 * scale
      love.graphics.setLineWidth(8)
      love.graphics.line(cx - arm, cy, cx + arm, cy)
      love.graphics.line(cx, cy - arm, cx, cy + arm)
      love.graphics.setLineWidth(1)

      -- Cost label
      if cost then
        love.graphics.setColor(affordable and {0.9, 0.85, 0.3} or {0.5, 0.3, 0.3})
        love.graphics.printf(cost .. " crystals", pos.x, pos.y + HOUSE_H - 45, HOUSE_W, "center")
      end
    end
  end
end

local function drawUpgradeButtons()
  love.graphics.setFont(font)
  local total_w = UPGRADE_BTN_W * 2 + UPGRADE_PAD
  local start_x = (VW - total_w) / 2

  -- Row upgrade
  local row_x = start_x
  local row_cost = upgrades.getRowCost()
  local row_maxed = row_cost == nil
  local row_affordable = row_cost and canAffordAny(row_cost)
  local row_label
  if row_maxed then
    row_label = "Rows MAX"
  else
    row_label = "Buy Row  [" .. row_cost .. "]"
  end

  if row_maxed then
    love.graphics.setColor(0.25, 0.25, 0.25)
  elseif row_affordable then
    love.graphics.setColor(0.2, 0.5, 0.2)
  else
    love.graphics.setColor(0.4, 0.2, 0.2)
  end
  love.graphics.rectangle("fill", row_x, UPGRADE_Y, UPGRADE_BTN_W, UPGRADE_BTN_H, 10, 10)
  love.graphics.setColor(1, 1, 1, (row_maxed or not row_affordable) and 0.4 or 1)
  love.graphics.printf(row_label, row_x, UPGRADE_Y + (UPGRADE_BTN_H - layout.FONT_SIZE) / 2, UPGRADE_BTN_W, "center")

  love.graphics.setColor(0.6, 0.6, 0.6)
  love.graphics.printf("Rows: " .. upgrades.getBaseRows(), row_x, UPGRADE_Y + UPGRADE_BTN_H + 10, UPGRADE_BTN_W, "center")

  -- Column upgrade
  local col_x = start_x + UPGRADE_BTN_W + UPGRADE_PAD
  local col_cost = upgrades.getColumnCost()
  local col_maxed = col_cost == nil
  local col_affordable = col_cost and canAffordAny(col_cost)
  local col_label
  if col_maxed then
    col_label = "Cols MAX"
  else
    col_label = "Buy Col  [" .. col_cost .. "]"
  end

  if col_maxed then
    love.graphics.setColor(0.25, 0.25, 0.25)
  elseif col_affordable then
    love.graphics.setColor(0.2, 0.5, 0.2)
  else
    love.graphics.setColor(0.4, 0.2, 0.2)
  end
  love.graphics.rectangle("fill", col_x, UPGRADE_Y, UPGRADE_BTN_W, UPGRADE_BTN_H, 10, 10)
  love.graphics.setColor(1, 1, 1, (col_maxed or not col_affordable) and 0.4 or 1)
  love.graphics.printf(col_label, col_x, UPGRADE_Y + (UPGRADE_BTN_H - layout.FONT_SIZE) / 2, UPGRADE_BTN_W, "center")

  love.graphics.setColor(0.6, 0.6, 0.6)
  love.graphics.printf("Cols: " .. upgrades.getBaseColumns(), col_x, UPGRADE_Y + UPGRADE_BTN_H + 10, UPGRADE_BTN_W, "center")
end

local function drawPlayButton()
  local x = (VW - PLAY_BTN_W) / 2
  love.graphics.setColor(0.2, 0.75, 0.3)
  love.graphics.rectangle("fill", x, PLAY_BTN_Y, PLAY_BTN_W, PLAY_BTN_H, 14, 14)
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(font)
  love.graphics.printf("PLAY", x, PLAY_BTN_Y + (PLAY_BTN_H - layout.FONT_SIZE) / 2, PLAY_BTN_W, "center")
end

local function drawNotification()
  if notification.timer <= 0 then return end
  local alpha = math.min(notification.timer / 0.3, 1)  -- fade out in last 0.3s
  love.graphics.setColor(1, 0.25, 0.25, alpha)
  love.graphics.setFont(font)
  love.graphics.printf(notification.message, 0, PLAY_BTN_Y - 80, VW, "center")
end

-- Picker panel layout constants
local PICKER_W, PICKER_H = 700, 550
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
  local sy = getPickerY() + 130
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
  local cr = currency.getCrystals()
  local names = coin_utils.getShardNames()
  local cost = picker.cost

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
  local titles = {
    build = "Choose Color to Build",
    change = "Change Production Color",
    buy_row = "Pay With Which Crystal?",
    buy_column = "Pay With Which Crystal?",
  }
  love.graphics.printf(titles[picker.mode] or "Choose Color", PICKER_X, py + 25, PICKER_W, "center")

  -- Cost line (if applicable)
  if cost > 0 then
    love.graphics.setColor(0.9, 0.85, 0.3)
    love.graphics.printf("Cost: " .. cost .. " crystals", PICKER_X, py + 70, PICKER_W, "center")
  end

  -- Color buttons with "Have: X" labels
  local positions = getPickerColorPositions()
  for i, name in ipairs(names) do
    local pos = positions[i]
    local rgb = coin_utils.getShardRGB(name)
    local have = cr[name] or 0
    local can_afford = cost <= 0 or have >= cost
    local cx, cy = pos.x + PICKER_BTN_SIZE / 2, pos.y + PICKER_BTN_SIZE / 2

    -- Circle (dimmed if can't afford)
    if can_afford then
      love.graphics.setColor(rgb[1], rgb[2], rgb[3])
    else
      love.graphics.setColor(rgb[1] * 0.3, rgb[2] * 0.3, rgb[3] * 0.3)
    end
    love.graphics.circle("fill", cx, cy, PICKER_BTN_SIZE / 2)

    -- Border highlight if affordable
    if can_afford and cost > 0 then
      love.graphics.setColor(1, 1, 1, 0.6)
      love.graphics.setLineWidth(3)
      love.graphics.circle("line", cx, cy, PICKER_BTN_SIZE / 2 + 2)
      love.graphics.setLineWidth(1)
    end

    -- Color name
    love.graphics.setColor(1, 1, 1, can_afford and 1 or 0.3)
    love.graphics.printf(name, pos.x - 10, pos.y + PICKER_BTN_SIZE + 8, PICKER_BTN_SIZE + 20, "center")

    -- "Have: X" count
    if cost > 0 then
      love.graphics.setColor(can_afford and {0.5, 1, 0.5} or {1, 0.3, 0.3})
      love.graphics.printf("Have: " .. have, pos.x - 10, pos.y + PICKER_BTN_SIZE + 45, PICKER_BTN_SIZE + 20, "center")
    end
  end

  -- Cancel button
  local cancel_x = PICKER_X + PICKER_W / 2 - 100
  local cancel_y = py + PICKER_H - 80
  love.graphics.setColor(0.5, 0.2, 0.2)
  love.graphics.rectangle("fill", cancel_x, cancel_y, 200, 55, 8, 8)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Cancel", cancel_x, cancel_y + 12, 200, "center")
end

function upgrades_screen.draw()
  love.graphics.clear(0.08, 0.08, 0.12)

  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(font)
  love.graphics.printf("Upgrades", 0, 30, VW, "center")

  drawCurrencyDisplay()
  drawHouseGrid()
  drawUpgradeButtons()
  drawPlayButton()
  drawNotification()
  drawColorPicker()
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

-- Unified picker click handler for all modes
local function handlePickerClick(x, y)
  if not picker.active then return false end

  local py = getPickerY()
  local names = coin_utils.getShardNames()
  local cr = currency.getCrystals()
  local cost = picker.cost
  local positions = getPickerColorPositions()

  -- Check color button clicks
  for i, name in ipairs(names) do
    local pos = positions[i]
    local cx, cy = pos.x + PICKER_BTN_SIZE / 2, pos.y + PICKER_BTN_SIZE / 2
    local dist = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
    if dist <= PICKER_BTN_SIZE / 2 then
      local have = cr[name] or 0

      -- Check affordability (skip for free actions like color change)
      if cost > 0 and have < cost then
        showNotification("Not enough " .. name .. " crystals! Need " .. cost .. ", have " .. have)
        return true  -- absorb click, keep picker open
      end

      -- Execute the action
      local success = true
      if picker.mode == "build" then
        success = upgrades.buildHouse(picker.slot, name)
      elseif picker.mode == "change" then
        upgrades.setHouseColor(picker.slot, name)
      elseif picker.mode == "buy_row" then
        success = upgrades.buyRow(name)
      elseif picker.mode == "buy_column" then
        success = upgrades.buyColumn(name)
      end

      if not success then
        showNotification("Purchase failed!")
      end
      picker.active = false
      return true
    end
  end

  -- Cancel button
  local cancel_x = PICKER_X + PICKER_W / 2 - 100
  local cancel_y = py + PICKER_H - 80
  if x >= cancel_x and x <= cancel_x + 200 and y >= cancel_y and y <= cancel_y + 55 then
    picker.active = false
    return true
  end

  -- Click outside panel = cancel
  if x < PICKER_X or x > PICKER_X + PICKER_W or y < py or y > py + PICKER_H then
    picker.active = false
    return true
  end

  return true  -- absorb click while picker is open
end

local function handleHouseClick(x, y)
  local houses = upgrades.getHouses()
  for idx = 1, upgrades.getMaxHouses() do
    local pos = house_positions[idx]
    if x >= pos.x and x <= pos.x + HOUSE_W and y >= pos.y and y <= pos.y + HOUSE_H then
      if houses[idx].built then
        picker.active = true
        picker.slot = idx
        picker.mode = "change"
        picker.cost = 0
      else
        local cost = upgrades.getHouseCost(idx)
        if not canAffordAny(cost) then
          showNotification("Not enough crystals! Need " .. cost)
        else
          picker.active = true
          picker.slot = idx
          picker.mode = "build"
          picker.cost = cost
        end
      end
      return true
    end
  end
  return false
end

local function handleUpgradeClick(x, y)
  local total_w = UPGRADE_BTN_W * 2 + UPGRADE_PAD
  local start_x = (VW - total_w) / 2

  -- Row upgrade button
  local row_x = start_x
  if x >= row_x and x <= row_x + UPGRADE_BTN_W and y >= UPGRADE_Y and y <= UPGRADE_Y + UPGRADE_BTN_H then
    local cost = upgrades.getRowCost()
    if not cost then
      showNotification("Rows already at maximum!")
    elseif not canAffordAny(cost) then
      showNotification("Not enough crystals! Need " .. cost)
    else
      picker.active = true
      picker.slot = 0
      picker.mode = "buy_row"
      picker.cost = cost
    end
    return true
  end

  -- Column upgrade button
  local col_x = start_x + UPGRADE_BTN_W + UPGRADE_PAD
  if x >= col_x and x <= col_x + UPGRADE_BTN_W and y >= UPGRADE_Y and y <= UPGRADE_Y + UPGRADE_BTN_H then
    local cost = upgrades.getColumnCost()
    if not cost then
      showNotification("Columns already at maximum!")
    elseif not canAffordAny(cost) then
      showNotification("Not enough crystals! Need " .. cost)
    else
      picker.active = true
      picker.slot = 0
      picker.mode = "buy_column"
      picker.cost = cost
    end
    return true
  end

  return false
end

local function handlePlayClick(x, y)
  local px = (VW - PLAY_BTN_W) / 2
  if x >= px and x <= px + PLAY_BTN_W and y >= PLAY_BTN_Y and y <= PLAY_BTN_Y + PLAY_BTN_H then
    screens.switch("game_2048")
    return true
  end
  return false
end

function upgrades_screen.mousepressed(x, y, button)
  if button ~= 1 then return end

  if picker.active then
    handlePickerClick(x, y)
    return
  end

  if handleHouseClick(x, y) then return end
  if handleUpgradeClick(x, y) then return end
  if handlePlayClick(x, y) then return end
end

function upgrades_screen.keypressed(key)
  if key == "escape" then
    picker.active = false
  end
  if key == "return" or key == "space" then
    if not picker.active then
      screens.switch("game_2048")
    end
  end
  if key == "\\" then
    love.event.quit()
  end
end

return upgrades_screen
