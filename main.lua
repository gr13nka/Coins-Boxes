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
local resources = require("resources")
local bags = require("bags")
local powerups = require("powerups")
local tab_bar = require("tab_bar")

-- Debugger is initialized in conf.lua (must run before love.load)

-- Layout constants
local VW, VH = layout.VW, layout.VH

-- Window/canvas state
local canvas
local scale, ox, oy = 1, 0, 0
local fps_font

-- Touch debounce (SDL+Emscripten fires both synthetic and real mouse events)
local last_touch_time = 0
local TOUCH_DEBOUNCE = 0.2

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
  canvas = love.graphics.newCanvas(VW, VH, {dpiscale = 1})
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
  resources.init()
  bags.init()
  powerups.init()
  local arena = require("arena")
  arena.init()
  sound.init()
  windowSetup()

  -- FPS counter font (virtual canvas coordinates)
  fps_font = love.graphics.newFont("comic shanns.otf", 24)

  -- Load assets
  love.graphics.setDefaultFilter("nearest", "nearest", 1)

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
  local fontScale = 1.2
  coinNumberFont = love.graphics.newFont("comic shanns.otf", math.floor(layout.COIN_R * fontScale))

  -- Initialize particle system
  particles.init()

  -- Initialize tab bar
  tab_bar.init({font = font})

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
  local coin_sort_screen = require("coin_sort_screen")
  local game_over_screen = require("game_over_screen")
  local arena_screen = require("arena_screen")

  coin_sort_screen.init(assets)
  game_over_screen.init(assets)
  arena_screen.init(assets)

  screens.register("coin_sort", coin_sort_screen)
  screens.register("game_over", game_over_screen)
  screens.register("arena", arena_screen)

  -- Start directly in Coin Sort mode
  screens.switch("coin_sort")
end

function love.resize(w, h)
  recalcScale(w, h)
end

function love.update(dt)
  screens.update(dt)
end

function love.draw()
  love.graphics.setCanvas(canvas)
  love.graphics.clear()
  screens.draw()

  -- FPS counter (bottom-left of virtual canvas)
  love.graphics.setFont(fps_font)
  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.rectangle("fill", 10, VH - 50, 160, 40, 6, 6)
  love.graphics.setColor(0, 1, 0, 0.8)
  love.graphics.print("FPS: " .. love.timer.getFPS(), 20, VH - 44)

  love.graphics.setCanvas()

  love.graphics.push("all")
  love.graphics.origin()
  love.graphics.setColor(1, 1, 1)
  love.graphics.translate(ox, oy)
  love.graphics.scale(scale, scale)
  love.graphics.draw(canvas, 0, 0)
  love.graphics.pop()
end

function love.keypressed(key, scancode, isrepeat)
  if key == "f1" then
    progression.reset()
    resources.init()
    bags.init()
    powerups.init()
    local arena = require("arena")
    arena.init()
    screens.switch("coin_sort")
    return
  end
  screens.keypressed(key, scancode, isrepeat)
end

function love.mousepressed(x, y, button, istouch)
  -- Debounce: SDL+Emscripten fires both synthetic (istouch=true) and real
  -- (istouch=false) mouse events for a single touch. Ignore the duplicate.
  local now = love.timer.getTime()
  if istouch then
    last_touch_time = now
  elseif now - last_touch_time < TOUCH_DEBOUNCE then
    return
  end
  local gx, gy = input.toGameCoords(x, y, ox, oy, scale)
  screens.mousepressed(gx, gy, button)
end

function love.mousereleased(x, y, button, istouch)
  local now = love.timer.getTime()
  if istouch then
    last_touch_time = now
  elseif now - last_touch_time < TOUCH_DEBOUNCE then
    return
  end
  local gx, gy = input.toGameCoords(x, y, ox, oy, scale)
  screens.mousereleased(gx, gy, button)
end

-- NOTE: love.touchpressed / love.touchreleased are intentionally NOT defined.
-- When absent, LÖVE automatically generates synthetic mouse events from touch,
-- giving us single-tap = single mousepressed. Defining touch callbacks disables
-- this, which caused double-fire issues on some mobile devices.


local love_errorhandler = love.errorhandler

function love.errorhandler(msg)
  if _G.lldebugger then
    error(msg, 2)
  end
  local trace = debug.traceback(tostring(msg), 2)
  pcall(function()
    local f = io.open("/tmp/love_crash.log", "w")
    if f then f:write(os.date() .. "\n" .. trace .. "\n"); f:close() end
  end)
  pcall(function()
    love.filesystem.write("crash.log", os.date() .. "\n" .. trace .. "\n")
  end)
  return love_errorhandler(msg)
end