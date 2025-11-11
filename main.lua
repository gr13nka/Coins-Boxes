if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
  require("lldebugger").start()
end

local selection = nil            -- { box = int, pack = {coin1, ...} } while carrying
local COLORS = {
  green = {0.2, 0.8, 0.2},
  red   = {0.9, 0.2, 0.2},
  blue  = {0.2, 0.4, 0.9},
  orange = {1.0, 0.6, 0.1},
  pink   = {1.0, 0.4, 0.7},
}
-- layout constants
local TOP_Y       = 140
local COIN_R      = 18
local ROW_STEP    = COIN_R * 2 + 8
local COLUMN_STEP = COIN_R * 2 + 24  -- a little spacing between stacks
local BOX_ROWS   = 3 -- number of coin slots per boxes

-- GamePlay Stuff
local points = 0

-- an iterator to go through all coins in all boxes bi, ci, color 
local function each_coin(boxes)
  local bi, ci = 1, 0
  return function()
    while bi <= #boxes do
      ci = ci + 1
      if ci <= #boxes[bi] then
        return bi, ci, boxes[bi][ci]
      end
      bi, ci = bi + 1, 0
    end
  end
end

function love.load()
  math.randomseed(os.time())
  -- rewrite this structures like boxes = {{"color"}, {"color","secondcolor"}, ...}

  boxes = { {}, {}, {}, {}, {} } -- just to count how many stacks you want
  colors_str = { "green", "red", "blue", "orange", "pink" }
  local colors_cnt = { green = 0, red = 0, blue = 0, orange = 0, pink = 0 }
  local box, color

  local total_coins   = #boxes * (BOX_ROWS - 1)
  local max_by_color  = #colors_str * BOX_ROWS

  if total_coins > max_by_color then
    error("Impossible constraints: too many coins for per-color limit")
  end


  for i = 1, #boxes*(BOX_ROWS - 1) do
    ::box::
    box   = math.random(#boxes)
    if #boxes[box] >= BOX_ROWS then
      -- box is full, try again
      goto box
    end
    
    ::color::
    color = colors_str[math.random(#colors_str)]
    if colors_cnt[color] >= BOX_ROWS then
      -- this color is maxed out, try again
      goto color
    end

    colors_cnt[color] = colors_cnt[color] + 1
    table.insert(boxes[box], color)
  end
end

local function print_coins(boxes)
  for i, box in ipairs(boxes) do
    for _, color in ipairs(box) do
      love.graphics.print("" .. i .. color, 1, 1 + i * 14)
      i = i + 1
    end
  end
end

local function draw_all_coins()

  local column = 1
  local row    = 1

  for i, c in ipairs(boxes) do
    for j, color in ipairs(c) do
      column = i
      row    = j
      local col = COLORS[color] or {1,1,1}
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
    for row = 1, BOX_ROWS do
      x = COLUMN_STEP * column
      y = TOP_Y + ROW_STEP * row
      love.graphics.rectangle("line", x-COIN_R-2, y-COIN_R-2, COIN_R*2+4, COIN_R*2+4, 2, 2, 8)
    end
  end 

  top_x = x
  top_y = y
end

local function pick_coin_from_box(box_index, opts)
  opts = opts or {}
  local remove = opts.remove == true -- set to true if you want to pop them from 'coins'

  local top_idx = #boxes[box_index]
  if not top_idx then return nil end

  local amount 
  local color, color_old = nil, nil
  for i = #boxes[box_index], 1, -1 do
    if color_old == nil then
      color_old = boxes[box_index][i]
      if color_old == nil then
        return nil
      end
      amount = 0
    end
    color = boxes[box_index][i]
    if color_old ~= color then
      break
    end
    amount = amount + 1
  end
  if amount == nil or amount == 0 then
    return nil
  end

  local selected_coins = {} 
  for i = top_idx, top_idx-amount + 1, -1 do
    table.insert(selected_coins, boxes[box_index][i])
    if remove then
      table.remove(boxes[box_index], i)
    end
  end 
  return selected_coins
end

local function add_coins()
  local colors = colors_str
  local colors_cnt = { green = 0, red = 0, blue = 0, orange = 0, pink = 0 }
  local total_coins = 0

  --get current color counts
  for bi, ci, color in each_coin(boxes) do
    colors_cnt[color] = colors_cnt[color] + 1
    total_coins = total_coins + 1
  end

  local max_possible  = #colors_str * BOX_ROWS
  local will_add = math.floor( ((max_possible - total_coins) / 2) + 0.5 )

  for i = 1, will_add do
    ::box::
    local box   = math.random(#boxes)
    if #boxes[box] >= BOX_ROWS then
      -- box is full, try again
      goto box
    end
    
    ::color::
    local color = colors[math.random(#colors)]
    if colors_cnt[color] >= BOX_ROWS then
      -- this color is maxed out, try again
      goto color
    end

    colors_cnt[color] = colors_cnt[color] + 1
    table.insert(boxes[box], color)
  end
 
end

local function merge()
  -- TODO make a random special reward when merging
  -- create a squares or just beautiful stones that also can merge too
  -- give points for merging
  local cur, total_same, current_color = 0, 0, ""

  for box_index, b in ipairs(boxes) do
    total_same = 0
    current_color = ""
    for _, c in ipairs(b) do
      if current_color == "" then
        current_color = c
      end   

      if c == current_color then
        total_same = total_same + 1 
      end
      
      if total_same == BOX_ROWS then
        -- remove these coins from the box 
        pick_coin_from_box(box_index, {remove = true})
      end
    end
  end
  points = points + 10
end

local function draw_merge_button()
  love.graphics.setColor(1,1,1)
  love.graphics.rectangle("line", top_x + COLUMN_STEP, TOP_Y, 100, 40)
  love.graphics.print("Merge Coins", top_x + COLUMN_STEP + 10, TOP_Y + 10)
end

local function draw_add_coins_button()
  love.graphics.setColor(1,1,1)
  love.graphics.rectangle("line", top_x + COLUMN_STEP, TOP_Y + 60, 100, 40)
  love.graphics.print("Add Coins", top_x + COLUMN_STEP + 10, TOP_Y + 70)    
end

function love.draw()
  if MERGE then
    love.graphics.setColor(0,1,0)
    love.graphics.print("Merged!", top_x + COLUMN_STEP + 10, TOP_Y + 120)
  end
  draw_all_boxes()
  draw_all_coins()
  draw_merge_button()
  draw_add_coins_button()
  print_coins(boxes)
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

function love.mousepressed(x, y, button)
  if button ~= 1 then return end
  local bx = box_at(x, y)
  local merge_button_pressed = (x >= top_x + COLUMN_STEP and x <= top_x + COLUMN_STEP + 100) and
                               (y >= TOP_Y and y <= TOP_Y + 40)
  if merge_button_pressed then
    MERGE = true
    merge()
    return
  end

  local add_coins_button_pressed = (x >= top_x + COLUMN_STEP and x <= top_x + COLUMN_STEP + 100) and
                                   (y >= TOP_Y + 60 and y <= TOP_Y + 100)
  if add_coins_button_pressed then
    add_coins()
    return
  end

  if not bx then return end

    if not selection then
      -- First click: try to pick up from this box
      pack = pick_coin_from_box(bx, {remove = true})
      if pack == nil then
        return
      end
      if #pack > 0 then
        selection = { box = bx, pack = pack }
        -- Optional: play a sound / set a highlight
        -- print(("Picked %d coin(s) of %s from box %d"):format(#pack, pack[1].color, bx))
      else
        -- print("Nothing to take from this box")
      end
    else
      -- Drop on a box
      -- check if full
      a = #boxes[bx]
      b = #selection["pack"]
      c = #boxes[bx] + #selection["pack"] > BOX_ROWS

      if #boxes[bx] + #selection["pack"] > BOX_ROWS then
        BOX_IS_FULL = true
        return
      end

      --local selected_coins = {unpack(selection.pack)}
      for i=0, #pack do
        table.insert(boxes[bx],pack[i]) 
      end
      -- Optional rule: if dropping onto same box, it's basically a no-op (already removed & readded to top)
      selection = nil
      -- Optional: play a sound / clear highlight
    end
  end

local love_errorhandler = love.errorhandler
function love.errorhandler(msg)
  if lldebugger then
    error(msg, 2)
  else
    return love_errorhandler(msg)
  end
end
