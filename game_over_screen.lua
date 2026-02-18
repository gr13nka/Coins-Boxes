-- game_over_screen.lua
-- Shows run results after game over, then transitions to upgrades screen.

local screens = require("screens")
local layout = require("layout")
local currency = require("currency")
local coin_utils = require("coin_utils")
local game_2048 = require("game_2048")
local progression = require("progression")
local upgrades = require("upgrades")
local emoji = require("emoji")

local game_over_screen = {}

local VW, VH = layout.VW, layout.VH
local font

-- Cached state from the run (snapshot on enter)
local final_score = 0
local snap_run_shards = {}
local snap_shards = {}
local snap_crystals = {}

-- Continue button
local BTN_W, BTN_H = 400, 120
local BTN_X = (VW - BTN_W) / 2
local BTN_Y = 1520

function game_over_screen.init(assets)
  font = assets.font
end

function game_over_screen.enter()
  local state = game_2048.getState()
  final_score = state.points

  -- Snapshot currency (copy tables so they don't mutate)
  local rs = currency.getRunShards()
  local sh = currency.getShards()
  local cr = currency.getCrystals()
  snap_run_shards = {}
  snap_shards = {}
  snap_crystals = {}
  for _, name in ipairs(coin_utils.getShardNames()) do
    snap_run_shards[name] = rs[name] or 0
    snap_shards[name] = sh[name] or 0
    snap_crystals[name] = cr[name] or 0
  end

  progression.onGameEnd("2048", final_score)
end

function game_over_screen.exit()
end

function game_over_screen.update(dt)
  upgrades.updateProduction(dt)
end

function game_over_screen.draw()
  love.graphics.setFont(font)

  -- Title
  love.graphics.setColor(1, 0.3, 0.3)
  love.graphics.printf("GAME OVER", 0, 200, VW, "center")

  -- Score
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Score: " .. final_score, 0, 340, VW, "center")

  -- Shard breakdown header
  love.graphics.setColor(0.8, 0.8, 0.8)
  love.graphics.printf("Shards Earned This Run", 0, 470, VW, "center")

  local names = coin_utils.getShardNames()
  local spc = currency.getShardsPerCrystal()

  -- Per-color shard rows with conversion progress
  local row_y = 550
  local row_h = 90
  for i, name in ipairs(names) do
    local y = row_y + (i - 1) * row_h
    local rgb = coin_utils.getShardRGB(name)
    local run_count = snap_run_shards[name] or 0
    local total_shards = snap_shards[name] or 0
    local total_crys = snap_crystals[name] or 0

    -- Color dot
    love.graphics.setColor(rgb[1], rgb[2], rgb[3])
    love.graphics.circle("fill", 200, y + 22, 22)

    -- Run shards earned
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("+" .. run_count, 240, y + 8, 120, "left")

    -- Shard progress bar (toward next crystal)
    local bar_x = 400
    local bar_w = 260
    local bar_h = 20
    local bar_y_pos = y + 12
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", bar_x, bar_y_pos, bar_w, bar_h, 4, 4)
    local fill = (total_shards / spc) * bar_w
    love.graphics.setColor(rgb[1], rgb[2], rgb[3])
    love.graphics.rectangle("fill", bar_x, bar_y_pos, math.min(fill, bar_w), bar_h, 4, 4)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf(total_shards .. "/" .. spc, bar_x, bar_y_pos + bar_h + 2, bar_w, "center")

    -- Crystal count emoji
    emoji.draw(name, 740, y + 22, 15)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(tostring(total_crys), 770, y + 8, 80, "left")
  end

  -- Legend
  local legend_y = row_y + #names * row_h + 20
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("25 shards = 1 crystal", 0, legend_y, VW, "center")

  -- Continue button
  love.graphics.setColor(0.2, 0.75, 0.3)
  love.graphics.rectangle("fill", BTN_X, BTN_Y, BTN_W, BTN_H, 12, 12)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Continue", BTN_X, BTN_Y + (BTN_H - layout.FONT_SIZE) / 2, BTN_W, "center")
end

function game_over_screen.mousepressed(x, y, button)
  if button ~= 1 then return end
  if x >= BTN_X and x <= BTN_X + BTN_W and y >= BTN_Y and y <= BTN_Y + BTN_H then
    screens.switch("upgrades")
  end
end

function game_over_screen.keypressed(key)
  if key == "return" or key == "space" then
    screens.switch("upgrades")
  end
  if key == "\\" then
    love.event.quit()
  end
end

return game_over_screen
