-- main.lua
-- Entry point: LÖVE callbacks, window setup, asset loading, screen registration

local utils = require("utils")
local layout = require("layout")
local screens = require("screens")
local graphics = require("graphics")
local sound = require("sound")
local progression = require("progression")
local particles = require("particles")
local input = require("input")
local mobile = require("mobile")
local currency = require("currency")
local upgrades = require("upgrades")
local powerups = require("powerups")
local emoji = require("emoji")

utils.debug_stuff1()

-- Layout constants
local VW, VH = layout.VW, layout.VH

-- Window/canvas state
local canvas
local scale, ox, oy = 1, 0, 0

-- Fonts (shared across screens)
local font
local coinNumberFont

--- Calculate scale and offsets for letterboxing
local function recalcScale(w, h)
  local sx, sy = w / VW, h / VH
  scale = math.min(sx, sy)
  local drawW, drawH = math.floor(VW * scale + 0.5), math.floor(VH * scale + 0.5)
  ox = math.floor((w - drawW) / 2)
  oy = math.floor((h - drawH) / 2)
end

--- Setup window and canvas
local function windowSetup()
  love.graphics.setDefaultFilter("nearest", "nearest")
  canvas = love.graphics.newCanvas(VW, VH)
  canvas:setFilter("nearest", "nearest")

  -- Apply mobile settings if on mobile device
  if mobile.isMobile() then
    love.window.setFullscreen(true)
  else
    -- Apply window scale from layout for desktop
    local windowW = math.floor(VW * layout.WINDOW_SCALE)
    local windowH = math.floor(VH * layout.WINDOW_SCALE)
    love.window.setMode(windowW, windowH, {resizable = true, minwidth = 270, minheight = 600})
  end

  local w, h = love.graphics.getDimensions()
  recalcScale(w, h)
end

function love.load()
  math.randomseed(os.time())

  -- Initialize core systems
  progression.init(true)  -- true = enable persistence
  currency.init()
  upgrades.init()
  powerups.init()
  sound.init()
  windowSetup()

  -- Load assets
  love.graphics.setDefaultFilter("nearest", "nearest", 1)

  local coin_utils = require("coin_utils")
  coin_utils.loadImages()

  local ballImage = love.graphics.newImage("assets/ball.png")
  graphics.init(ballImage)

  -- Button images
  local addButtonImage = love.graphics.newImage("assets/add_button.png")
  local addButtonPressedImage = love.graphics.newImage("assets/add_button_pressed.png")
  local mergeButtonImage = love.graphics.newImage("assets/merge_button.png")
  local mergeButtonPressedImage = love.graphics.newImage("assets/merge_button_pressed.png")

  -- Fonts
  font = love.graphics.newFont("comic shanns.otf", layout.FONT_SIZE)
  love.graphics.setFont(font)
  local fontScale = layout.USE_FRUIT_IMAGES and 0.7 or 1.2
  coinNumberFont = love.graphics.newFont("comic shanns.otf", math.floor(layout.COIN_R * fontScale))

  -- Initialize particle system
  particles.init()

  -- Initialize emoji icons for currency display
  emoji.init()

  -- Prepare assets bundle for screens
  local assets = {
    font = font,
    coinNumberFont = coinNumberFont,
    addButtonImage = addButtonImage,
    addButtonPressedImage = addButtonPressedImage,
    mergeButtonImage = mergeButtonImage,
    mergeButtonPressedImage = mergeButtonPressedImage,
  }

  -- Load and register game screens
  local game_screen = require("game_screen")
  local game_2048_screen = require("game_2048_screen")
  local game_dev_screen = require("game_dev_screen")
  local game_over_screen = require("game_over_screen")
  local upgrades_screen = require("upgrades_screen")

  game_screen.init(assets)
  game_2048_screen.init(assets)
  game_dev_screen.init(assets)
  game_over_screen.init(assets)
  upgrades_screen.init(assets)

  screens.register("game", game_screen)
  screens.register("game_2048", game_2048_screen)
  screens.register("game_dev", game_dev_screen)
  screens.register("game_over", game_over_screen)
  screens.register("upgrades", upgrades_screen)

  -- Start directly in 2048 mode
  screens.switch("game_2048")
end

function love.resize(w, h)
  recalcScale(w, h)
end

function love.update(dt)
  screens.update(dt)
end

function love.draw()
  -- Render to canvas
  love.graphics.setCanvas(canvas)
  love.graphics.clear()
  screens.draw()
  love.graphics.setCanvas()

  -- Blit canvas to window with letterboxing
  love.graphics.push("all")
  love.graphics.origin()
  love.graphics.translate(ox, oy)
  love.graphics.scale(scale, scale)
  love.graphics.draw(canvas, 0, 0)
  love.graphics.pop()
end

function love.keypressed(key, scancode, isrepeat)
  if key == "f1" then
    progression.reset()
    currency.init()
    upgrades.init()
    powerups.init()
    screens.switch("game_2048")
    return
  end
  screens.keypressed(key, scancode, isrepeat)
end

function love.mousepressed(x, y, button)
  local gx, gy = input.toGameCoords(x, y, ox, oy, scale)
  screens.mousepressed(gx, gy, button)
end

function love.mousereleased(x, y, button)
  local gx, gy = input.toGameCoords(x, y, ox, oy, scale)
  screens.mousereleased(gx, gy, button)
end

-- Touch input callbacks for mobile
function love.touchpressed(id, x, y, dx, dy, pressure)
  local gx, gy = input.toGameCoords(x, y, ox, oy, scale)
  screens.touchpressed(id, gx, gy, pressure)
end

function love.touchreleased(id, x, y, dx, dy, pressure)
  local gx, gy = input.toGameCoords(x, y, ox, oy, scale)
  screens.touchreleased(id, gx, gy)
end

function love.touchmoved(id, x, y, dx, dy, pressure)
  local gx, gy = input.toGameCoords(x, y, ox, oy, scale)
  screens.touchmoved(id, gx, gy)
end

utils.debug_stuff2()
