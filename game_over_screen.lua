-- game_over_screen.lua
-- Shows run results after game over, then transitions to upgrades screen.

local screens = require("screens")
local layout = require("layout")
local resources = require("resources")
local bags = require("bags")
local coin_sort = require("coin_sort")
local progression = require("progression")
local yandex = require("yandex")

local game_over_screen = {}

local VW, VH = layout.VW, layout.VH
local font

-- Cached state from the run (snapshot on enter)
local final_score = 0
local snap_fuel = 0
local snap_stars = 0
local snap_bags = 0

-- Continue button
local BTN_W, BTN_H = 400, 120
local BTN_X = (VW - BTN_W) / 2
local BTN_Y = 1200

function game_over_screen.init(assets)
  font = assets.font
end

function game_over_screen.enter()
  local state = coin_sort.getState()
  final_score = state.points

  -- Snapshot resources
  snap_fuel = resources.getFuel()
  snap_stars = resources.getStars()
  snap_bags = bags.getTotalAvailable()

  progression.onGameEnd("2048", final_score)

  -- Show interstitial ad on game over (natural break point)
  if yandex.isReady() then
    yandex.showInterstitial()
  end
end

function game_over_screen.exit()
end

function game_over_screen.update(dt)
  bags.update(dt)

  -- Poll interstitial ad result
  local r = yandex.getInterstitialResult()
  if r == "closed_shown" or r == "closed_not_shown" or r == "error" then
    yandex.resetInterstitialResult()
  end
end

function game_over_screen.draw()
  love.graphics.setFont(font)

  -- Title
  love.graphics.setColor(0.80, 0.38, 0.22)
  love.graphics.printf("GAME OVER", 0, 200, VW, "center")

  -- Score
  love.graphics.setColor(0.92, 0.88, 0.78)
  love.graphics.printf("Score: " .. final_score, 0, 340, VW, "center")

  -- Resource summary
  love.graphics.setColor(0.65, 0.68, 0.58)
  love.graphics.printf("Resources", 0, 500, VW, "center")

  local row_y = 580
  local row_h = 80

  -- Fuel
  love.graphics.setColor(0.82, 0.70, 0.30)
  love.graphics.printf("Fuel", 200, row_y, 200, "left")
  love.graphics.setColor(0.92, 0.88, 0.78)
  love.graphics.printf(snap_fuel .. " / " .. resources.getFuelCap(), 500, row_y, 300, "left")

  -- Stars
  love.graphics.setColor(0.95, 0.85, 0.25)
  love.graphics.printf("Stars", 200, row_y + row_h, 200, "left")
  love.graphics.setColor(0.92, 0.88, 0.78)
  love.graphics.printf(tostring(snap_stars), 500, row_y + row_h, 300, "left")

  -- Bags
  love.graphics.setColor(0.68, 0.55, 0.32)
  love.graphics.printf("Bags", 200, row_y + row_h * 2, 200, "left")
  love.graphics.setColor(0.92, 0.88, 0.78)
  love.graphics.printf(tostring(snap_bags), 500, row_y + row_h * 2, 300, "left")

  -- Continue button
  love.graphics.setColor(0.25, 0.65, 0.35)
  love.graphics.rectangle("fill", BTN_X, BTN_Y, BTN_W, BTN_H, 12, 12)
  love.graphics.setColor(0.92, 0.88, 0.78)
  love.graphics.printf("Continue to Arena", BTN_X, BTN_Y + (BTN_H - layout.FONT_SIZE) / 2, BTN_W, "center")
end

function game_over_screen.mousepressed(x, y, button)
  if button ~= 1 then return end
  if x >= BTN_X and x <= BTN_X + BTN_W and y >= BTN_Y and y <= BTN_Y + BTN_H then
    screens.switch("arena")
  end
end

function game_over_screen.keypressed(key)
  if key == "return" or key == "space" then
    screens.switch("arena")
  end
  if key == "\\" then
    love.event.quit()
  end
end

return game_over_screen
