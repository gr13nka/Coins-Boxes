local utils = require("utils")
local game = require("game")
local layout = require("layout")
local screens = require("screens")
local animation = require("animation")

utils.debug_stuff1()

local selection = nil            -- { box = int, pack = {coin1, ...} } while carrying

-- layout constants (from layout.lua)
local VW, VH = layout.VW, layout.VH
local TOP_Y = layout.GRID_TOP_Y
local COIN_R = layout.COIN_R
local ROW_STEP = layout.ROW_STEP
local COLUMN_STEP = layout.COLUMN_STEP
local GRID_X_OFFSET = layout.GRID_LEFT_OFFSET

-- Game Window
local canvas                     -- where we render the game
local scale, ox, oy = 1, 0, 0   -- scale and offsets (for letterboxing)

local function recalcScale(w, h)
  -- preserve aspect ratio by letterboxing
  local sx, sy = w / VW, h / VH
  scale = math.min(sx, sy)
  local drawW, drawH = math.floor(VW * scale + 0.5), math.floor(VH * scale + 0.5)
  ox = math.floor((w - drawW) / 2)
  oy = math.floor((h - drawH) / 2)
end


local function window_stuff()
  love.graphics.setDefaultFilter("nearest", "nearest")
  canvas = love.graphics.newCanvas(VW, VH)
  canvas:setFilter("nearest","nearest")

  -- Apply window scale from layout
  local windowW = math.floor(VW * layout.WINDOW_SCALE)
  local windowH = math.floor(VH * layout.WINDOW_SCALE)
  love.window.setMode(windowW, windowH, {resizable = true, minwidth = 270, minheight = 600})

  local w, h = love.graphics.getDimensions()
  recalcScale(w, h)
end

function loading_snds()
  bgnd_music = love.audio.newSource("bgnd_music/storm-clouds-purpple-cat(chosic.com).mp3", "stream")
  love.audio.play(bgnd_music)

  pick_up_snd = love.audio.newSource("sfx/chip-lay-2.ogg", "static")
  merge_snd = love.audio.newSource("sfx/chips-handle-1.ogg", "static")
  add_snd = love.audio.newSource("sfx/chips-collide-2.ogg", "static")
end

--------------------------------------------------------------------------------
-- Game Screen (wrapped for screen system)
--------------------------------------------------------------------------------
game_screen = {}

function game_screen.enter()
  game.init()
  selection = nil
end

function game_screen.update(dt)
  merge_timer = game.update(dt)
  animation.update(dt)
end

function game_screen.draw()
  draw_hint()
  draw_points()

  if merge_timer > 0 then
    love.graphics.setColor(0, 1, 0)
    love.graphics.printf("Merged!", 0, layout.MERGED_MSG_Y, VW, "center")
  end

  draw_all_boxes()
  draw_all_coins()
  draw_merge_button()
  draw_add_coins_button()
end

function game_screen.keypressed(key, scancode, isrepeat)
  if key == "\\" then
    love.event.quit()
  end
  if key == "a" then
    BOX_ROWS = BOX_ROWS + 1
  end
  if key == "b" then
    name, color = next(Non_Active_Colors)
    if not name then return end
    COLORS[name] = color
    colors_str[#colors_str + 1] = name
    Non_Active_Colors[name] = nil
    table.insert(boxes, {})
  end
end

function game_screen.mousepressed(x, y, button)
  if button ~= 1 then return end
  local bx = box_at(x, y)
  local merge_button_pressed = (x >= BUTTON_X and x <= BUTTON_X + layout.BUTTON_WIDTH) and
                               (y >= MERGE_BUTTON_Y and y <= MERGE_BUTTON_Y + layout.BUTTON_HEIGHT)
  if merge_button_pressed then
    game.merge()
    merge_snd:play()
    return
  end

  local add_coins_button_pressed = (x >= BUTTON_X and x <= BUTTON_X + layout.BUTTON_WIDTH) and
                                   (y >= ADD_BUTTON_Y and y <= ADD_BUTTON_Y + layout.BUTTON_HEIGHT)
  if add_coins_button_pressed then
    game.add_coins()
    add_snd:play()
    return
  end

  if not bx then return end

  if not selection then
    pack = game.pick_coin_from_box(bx, {remove = true})
    if pack == nil then
      return
    end
    if #pack > 0 then
      selection = { box = bx, pack = pack }
      pick_up_snd:play()
    end
  else
    if #game.getState().boxes[bx] + #selection["pack"] > game.getState().BOX_ROWS then
      BOX_IS_FULL = true
      return
    end
    for i=0, #pack do
      table.insert(boxes[bx],pack[i])
    end
    love.audio.play(pick_up_snd)
    selection = nil
  end
end

function love.load()
  loading_snds()
  math.randomseed(os.time())
  window_stuff()

  -- background scroll
  bgImage = love.graphics.newImage("assets/color_background_5.png")
  bgImage:setWrap("repeat", "repeat")   -- important for tiling

  -- coin sprite
  ballImage = love.graphics.newImage("assets/ball.png")

  bgScrollX, bgScrollY = 0, 0           -- scroll offsets
  bgScrollSpeedX = 10                   -- pixels per second (texture space)
  bgScrollSpeedY = 5

  --fonts
  love.graphics.setDefaultFilter("nearest", "nearest", 1) -- affects images, fonts, canvases
  font = love.graphics.newFont("comic shanns.otf", layout.FONT_SIZE)
  love.graphics.setFont(font)

  -- Register and start with mode selection screen
  screens.register("game", game_screen)
  screens.switch("mode_select")
end

local function draw_all_coins()
  local column = 1
  local row    = 1

  -- Get sprite dimensions for scaling
  local imgW, imgH = ballImage:getDimensions()
  local spriteScale = (COIN_R * 2) / imgW

  for i, c in ipairs(boxes) do
    for j, color in ipairs(c) do
      column = i
      row    = j
      local col = game.getState().COLORS[color] or {1,1,1}
      love.graphics.setColor(col)

      local x = GRID_X_OFFSET + COLUMN_STEP * column
      local y = TOP_Y + ROW_STEP * row
      -- Draw sprite centered at (x, y), tinted by current color
      love.graphics.draw(ballImage, x, y, 0, spriteScale, spriteScale, imgW/2, imgH/2)
    end
  end
end

local function draw_all_boxes()
  local color = {1,1,1}
  love.graphics.setColor(color)
  local x, y
  for column = 1, #boxes do
    for row = 1, game.getState().BOX_ROWS do
      x = GRID_X_OFFSET + COLUMN_STEP * column
      y = TOP_Y + ROW_STEP * row
      love.graphics.rectangle("line", x-COIN_R-2, y-COIN_R-2, COIN_R*2+4, COIN_R*2+4, 2, 2, 8)
    end
  end

  top_x = x
  top_y = y
end


-- Button positions (centered horizontally, at bottom)
local BUTTON_X = (layout.VW - layout.BUTTON_WIDTH) / 2
local MERGE_BUTTON_Y = layout.BUTTON_AREA_Y
local ADD_BUTTON_Y = layout.BUTTON_AREA_Y + layout.BUTTON_HEIGHT + layout.BUTTON_SPACING

local function draw_merge_button()
  love.graphics.setColor(1,1,1)
  love.graphics.rectangle("line", BUTTON_X, MERGE_BUTTON_Y, layout.BUTTON_WIDTH, layout.BUTTON_HEIGHT)
  love.graphics.print("Merge Coins", BUTTON_X + 70, MERGE_BUTTON_Y + 30)
end

local function draw_add_coins_button()
  love.graphics.setColor(1,1,1)
  love.graphics.rectangle("line", BUTTON_X, ADD_BUTTON_Y, layout.BUTTON_WIDTH, layout.BUTTON_HEIGHT)
  love.graphics.print("Add Coins", BUTTON_X + 90, ADD_BUTTON_Y + 30)
end

local function draw_points()
  love.graphics.setColor(1,1,1)
  love.graphics.printf("Points: " .. game.getState().points, 0, layout.POINTS_Y, VW, "center")
end

local function draw_hint()
  love.graphics.setColor(1,1,1)
  love.graphics.printf("Points = Combo * amount of coins in stack!", 0, layout.HINT_Y, VW, "center")
end


function love.resize(w, h)
  recalcScale(w, h)
end

-- Convert window/screen coords to virtual game coords
local function toGame(x, y)
  return (x - ox) / scale, (y - oy) / scale
end

function love.update(dt)
  screens.update(dt)
end

function love.draw()
  love.graphics.setCanvas(canvas)
  love.graphics.clear()

  -- Delegate drawing to current screen
  screens.draw()

  -- Canvas stuff
  love.graphics.setCanvas()

  -- Blit the canvas to the actual window with letterboxing
  love.graphics.push("all")
  love.graphics.origin()
  love.graphics.translate(ox, oy)
  love.graphics.scale(scale, scale)
  love.graphics.draw(canvas, 0, 0)
  love.graphics.pop()
end

-- ========= Hit testing: which box did we click? =========
-- Your columns are centered at x = GRID_X_OFFSET + COLUMN_STEP * column (1-based).
-- We'll snap clicks to the nearest column and also gate by the vertical box area.
local function box_at(x, y)
  -- snap X to nearest column (accounting for grid offset)
  local col = math.floor(((x - GRID_X_OFFSET) / COLUMN_STEP) + 0.5)
  if col < 1 or col > #boxes then return nil end

  -- only accept clicks within the vertical bounds where boxes are drawn
  local y_min = TOP_Y - 10
  if y < y_min-10 or y > top_y+10 then return nil end

  return col
end

function love.keypressed(key, scancode, isrepeat)
  if key == "\\" then
    love.event.quit()
  end
  if key == "a" then
    BOX_ROWS = BOX_ROWS + 1
  end
  if key == "b" then
    name, color = next(Non_Active_Colors)
    if not name then return end
    COLORS[name] = color          -- copy to COLORS
    colors_str[#colors_str + 1] = name  -- add to colors_str
    Non_Active_Colors[name] = nil -- remove from Non_Active_Colors
    table.insert(boxes, {})
  end
end

function love.mousepressed(x, y, button)
  x, y = toGame(x, y)
  if button ~= 1 then return end
  local bx = box_at(x, y)
  local merge_button_pressed = (x >= BUTTON_X and x <= BUTTON_X + layout.BUTTON_WIDTH) and
                               (y >= MERGE_BUTTON_Y and y <= MERGE_BUTTON_Y + layout.BUTTON_HEIGHT)
  if merge_button_pressed then
    game.merge()
    merge_snd:play()
    return
  end

  local add_coins_button_pressed = (x >= BUTTON_X and x <= BUTTON_X + layout.BUTTON_WIDTH) and
                                   (y >= ADD_BUTTON_Y and y <= ADD_BUTTON_Y + layout.BUTTON_HEIGHT)
  if add_coins_button_pressed then
    game.add_coins()
    add_snd:play()
    return
  end

  if not bx then return end

    if not selection then
      -- First click: try to pick up from this box
      pack = game.pick_coin_from_box(bx, {remove = true})
      if pack == nil then
        return
      end
      if #pack > 0 then
        selection = { box = bx, pack = pack }
        pick_up_snd:play()
        -- Optional: play a sound / set a highlight
        -- print(("Picked %d coin(s) of %s from box %d"):format(#pack, pack[1].color, bx))
      else
        -- print("Nothing to take from this box")
      end
    else
      -- Drop on a box
      -- check if full
      if #game.getState().boxes[bx] + #selection["pack"] > game.getState().BOX_ROWS then
        BOX_IS_FULL = true
        return
      end

      --local selected_coins = {unpack(selection.pack)}
      for i=0, #pack do
        table.insert(boxes[bx],pack[i]) 
      end
      love.audio.play(pick_up_snd)
      -- Optional rule: if dropping onto same box, it's basically a no-op (already removed & readded to top)
      selection = nil
      -- Optional: play a sound / clear highlight
    end
  end

utils.debug_stuff2()
