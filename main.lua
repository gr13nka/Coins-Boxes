local utils = require("utils")
local game = require("game")

utils.debug_stuff1()



local selection = nil            -- { box = int, pack = {coin1, ...} } while carrying

-- layout constants
local TOP_Y       = 140
local COIN_R      = 38
local ROW_STEP    = COIN_R * 2 + 8 -- 44
local COLUMN_STEP = COIN_R * 2 + 24  -- 60


-- Game Window
local VW, VH = 1600, 900       -- virtual (design) resolution
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

function love.load()
  game.init()

  loading_snds()
  math.randomseed(os.time())
  window_stuff()

  -- background scroll 
  bgImage = love.graphics.newImage("assets/color_background_5.png")
  bgImage:setWrap("repeat", "repeat")   -- important for tiling

  bgScrollX, bgScrollY = 0, 0           -- scroll offsets
  bgScrollSpeedX = 10                   -- pixels per second (texture space)
  bgScrollSpeedY = 5

  --fonts
  love.graphics.setDefaultFilter("nearest", "nearest", 1) -- affects images, fonts, canvases
  font = love.graphics.newFont("comic shanns.otf", 20) -- "mono" hinting is crisper
  love.graphics.setFont(font)
  -- rewrite this structures like boxes = {{"color"}, {"color","secondcolor"}, ...}
end

local function draw_all_coins()

  local column = 1
  local row    = 1

  for i, c in ipairs(boxes) do
    for j, color in ipairs(c) do
      column = i
      row    = j
      local col = game.getState().COLORS[color] or {1,1,1}
      love.graphics.setColor(col)

      local x = COLUMN_STEP * column
      local y = TOP_Y + ROW_STEP * row
      love.graphics.circle("fill", x, y, COIN_R)
    end
  end
end

local function draw_all_boxes()
  local color = {1,1,1}
  love.graphics.setColor(color)
  local x, y
  for column = 1, #boxes do
    for row = 1, game.getState().BOX_ROWS do
      x = COLUMN_STEP * column
      y = TOP_Y + ROW_STEP * row
      love.graphics.rectangle("line", x-COIN_R-2, y-COIN_R-2, COIN_R*2+4, COIN_R*2+4, 2, 2, 8)
      -- love.graphics.rectangle("line", x, y, COIN_R*2+4, COIN_R*2+4, 2, 2, 8)
    end
  end 

  top_x = x
  top_y = y
end


local function draw_merge_button()
  love.graphics.setColor(1,1,1)
  love.graphics.rectangle("line", top_x + COLUMN_STEP, TOP_Y, 134, 40)
  love.graphics.print("Merge Coins", top_x + COLUMN_STEP + 10, TOP_Y + 10)
end

local function draw_add_coins_button()
  love.graphics.setColor(1,1,1)
  love.graphics.rectangle("line", top_x + COLUMN_STEP, TOP_Y + 60, 134, 40)
  love.graphics.print("Add Coins", top_x + COLUMN_STEP + 10, TOP_Y + 70)    
end

local function draw_add_box_row()
  love.graphics.setColor(1,1,1)
  love.graphics.rectangle("line", top_x + COLUMN_STEP, TOP_Y + 60, 134, 40)
  love.graphics.print("Add Box Row " .. box_row_price, top_x + COLUMN_STEP + 10 + 134, TOP_Y + 70)    
end

local function draw_add_box_row()
  love.graphics.setColor(1,1,1)
  love.graphics.rectangle("line", top_x + COLUMN_STEP, TOP_Y + 60, 134, 40)
  love.graphics.print("Add new Box " .. new_box_price, top_x + COLUMN_STEP + 10 + 134, TOP_Y + 10)    
end

local function draw_points()
  love.graphics.setColor(1,1,1)
  love.graphics.print("Points: " .. game.getState().points, love.graphics.getWidth() / 3, TOP_Y/2)    
end

local function draw_hint()
  love.graphics.setColor(1,1,1)
  love.graphics.print("Points = Combo * amount of coins in stack!", love.graphics.getWidth() / 5, TOP_Y/3)    
end


function love.resize(w, h)
  recalcScale(w, h)
end

-- Convert window/screen coords to virtual game coords
local function toGame(x, y)
  return (x - ox) / scale, (y - oy) / scale
end

function love.update(dt)
  merge_timer = game.update(dt)
end

function love.draw()
  love.graphics.setCanvas(canvas)
  love.graphics.clear()  
  
  draw_hint()
  draw_points()

  if merge_timer > 0 then
    love.graphics.setColor(0, 1, 0)
    love.graphics.print("Merged!", top_x + COLUMN_STEP + 10, TOP_Y + 120)
  end

  draw_all_boxes()
  draw_all_coins()
  draw_merge_button()
  draw_add_coins_button()

  -- Canvas stuff
  love.graphics.setCanvas()

  -- 2) Blit the canvas to the actual window with letterboxing
  love.graphics.push("all")
  love.graphics.origin()
  love.graphics.translate(ox, oy)
  love.graphics.scale(scale, scale)
  love.graphics.draw(canvas, 0, 0)
  love.graphics.pop()
end

-- ========= Hit testing: which box did we click? =========
-- Your columns are centered at x = COLUMN_STEP * column (1-based).
-- We’ll snap clicks to the nearest column and also gate by the vertical box area.
local function box_at(x, y)
  -- snap X to nearest column
  local col = math.floor((x / COLUMN_STEP) + 0.5)
  if col < 1 or col > #boxes then return nil end

  -- only accept clicks within the vertical bounds where boxes are drawn
  local y_min = TOP_Y - 10
  if y < y_min-10 or y > top_y+10 then return nil end

  return col
end

function love.keypressed(key, scancode, isrepeat)
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
  local merge_button_pressed = (x >= top_x + COLUMN_STEP and x <= top_x + COLUMN_STEP + 100) and
                               (y >= TOP_Y and y <= TOP_Y + 40)
  if merge_button_pressed then
    game.merge()
    merge_snd:play()
    return
  end

  local add_coins_button_pressed = (x >= top_x + COLUMN_STEP and x <= top_x + COLUMN_STEP + 100) and
                                   (y >= TOP_Y + 60 and y <= TOP_Y + 100)
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
