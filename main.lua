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
local fps_font

-- Touch debounce (SDL+Emscripten fires both synthetic and real mouse events)
local last_touch_time = 0
local TOUCH_DEBOUNCE = 0.2

-- Draw-only throttle for web/mobile (update runs at full rate, canvas re-renders at 30fps)
local render_accumulator = 0
local RENDER_INTERVAL = 1 / 30
local needs_render = false

-- Custom render FPS tracking (love.timer.getFPS() reports browser loop rate, not render rate)
local render_frame_count = 0
local render_fps_timer = 0
local render_fps = 0

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
  currency.init()
  upgrades.init()
  powerups.init()
  sound.init()
  windowSetup()

  -- FPS counter font (virtual canvas coordinates)
  fps_font = love.graphics.newFont("comic shanns.otf", 24)

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
  local game_over_screen = require("game_over_screen")
  local upgrades_screen = require("upgrades_screen")

  game_screen.init(assets)
  game_2048_screen.init(assets)
  game_over_screen.init(assets)
  upgrades_screen.init(assets)

  screens.register("game", game_screen)
  screens.register("game_2048", game_2048_screen)
  screens.register("game_over", game_over_screen)
  screens.register("upgrades", upgrades_screen)

  -- Start directly in 2048 mode
  screens.switch("game_2048")
end

function love.resize(w, h)
  recalcScale(w, h)
end

function love.update(dt)
  -- Always update game logic at full rate (cheap math, ~0.1ms)
  screens.update(dt)

  if mobile.isLowPerformance() then
    -- Gate canvas re-renders to 30fps (the expensive GPU part)
    render_accumulator = render_accumulator + dt
    if render_accumulator >= RENDER_INTERVAL then
      needs_render = true
      render_accumulator = render_accumulator - RENDER_INTERVAL
    else
      needs_render = false
    end

    -- Track render FPS (once per second)
    render_fps_timer = render_fps_timer + dt
    if render_fps_timer >= 1 then
      render_fps = render_frame_count
      render_frame_count = 0
      render_fps_timer = render_fps_timer - 1
    end
  end
end

function love.draw()
  local is_low_perf = mobile.isLowPerformance()

  -- Re-render canvas at 30fps on web/mobile, or every frame on desktop
  if needs_render or not is_low_perf then
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    screens.draw()

    -- FPS counter (bottom-left of virtual canvas)
    local displayed_fps = is_low_perf and render_fps or love.timer.getFPS()
    love.graphics.setFont(fps_font)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 10, VH - 50, 160, 40, 6, 6)
    love.graphics.setColor(0, 1, 0, 0.8)
    love.graphics.print("FPS: " .. displayed_fps, 20, VH - 44)

    love.graphics.setCanvas()
    render_frame_count = render_frame_count + 1
  end

  -- Always blit cached canvas (cheap single draw call)
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
    currency.init()
    upgrades.init()
    powerups.init()
    screens.switch("game_2048")
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

utils.debug_stuff2()
