if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
  require("lldebugger").start()
end

local selection = nil            -- { box = int, pack = {coin1, ...} } while carrying
local next_order = 1             -- preserves stack order inside each box

-- Call this once when creating coins so each coin has an 'order'
local function init_coin_orders()
  for _, c in ipairs(coins) do
    if not c.order then
      c.order = next_order
      next_order = next_order + 1
    end
  end
end

-- utility
local function sort_coins()
  table.sort(coins, function(a, b)
  if a.box ~= b.box then return a.box < b.box end
    return a.order < b.order        -- stable-ish ordering inside the box
  end)
end

function love.load()
  math.randomseed(os.time())

  boxes = { {}, {}, {}, {} } -- just to count how many stacks you want
  coins = {}                   -- make this a proper array of coins

  local colors = { "green", "red", "blue" }

  for i = 1, 10 do
    table.insert(coins, {
      color = colors[math.random(#colors)],
      box   = math.random(#boxes),
    })
  end
  init_coin_orders()
  sort_coins()
end


local function print_coins(coins, x)
  for i, coin in ipairs(coins) do
    love.graphics.print("" .. i .. coin.color .. coin.box, x, 1 + i * 14)
  end
end

local COLORS = {
  green = {0.2, 0.8, 0.2},
  red   = {0.9, 0.2, 0.2},
  blue  = {0.2, 0.4, 0.9},
}
-- layout constants
local TOP_Y       = 140
local COIN_R      = 18
local ROW_STEP    = COIN_R * 2 + 8
local COLUMN_STEP = COIN_R * 2 + 24  -- a little spacing between stacks
local BOX_ROWS   = 6 -- number of coin slots per boxes
local function draw_all_coins()

  local column = 1
  local row    = 1

  for i, c in ipairs(coins) do
    column = c.box
    local col = COLORS[c.color] or {1,1,1}
    love.graphics.setColor(col)

    local x = COLUMN_STEP * column
    local y = TOP_Y + ROW_STEP * row
    love.graphics.circle("fill", x, y, COIN_R)

    local nextCoin = coins[i + 1]
    if nextCoin and nextCoin.box ~= c.box then
      column = nextCoin.box
      row = 1
    else
      row = row + 1
    end
  end
end

local function draw_all_boxes()
  local column = 1
  local row    = 1

  local col = {1,1,1}
  love.graphics.setColor(col)

  for i = 1, #boxes do
    for j = 1, BOX_ROWS, 1 do
      local x = COLUMN_STEP * column
      local y = TOP_Y + ROW_STEP * row
      love.graphics.rectangle("line", x-COIN_R-2, y-COIN_R-2, COIN_R*2+4, COIN_R*2+4, 2, 2, 8)
      row = row + 1
    end
    row = 1
    column = column + 1
  end 
end

local function check_coin_pack(selected_coin) 
  if not selected_coin then return 0 end
  -- check if a clicked coin is the only one of its color in the pack
  local color = selected_coin.color
  local box = selected_coin.box
  local amount = 0
  
  for i = #coins, 1, -1 do
    local c = coins[i]
    if c.box == box then
      if c.color == color then
        amount = amount + 1
      else
        break
      end
    elseif amount > 0 then
      -- We've already started counting this box's top pack and left the box block
      break
    end
  end

  return amount  
end

local function get_top_coin_in_box(box_index)
  for i = #coins, 1, -1 do
    if coins[i].box == box_index then
      return i
    end
  end
  return nil
end

local function pick_coin_from_box(box_index, opts)
  opts = opts or {}
  local remove = opts.remove == true -- set to true if you want to pop them from 'coins'

  local top_idx = nil

  top_idx = get_top_coin_in_box(box_index)
  if not top_idx then return nil end

  local top_coin = coins[top_idx]

  local amount = check_coin_pack(top_coin)
  if amount == 0 then return nil end

  local selected_coins = {} 
  for i = top_idx, top_idx-amount + 1, -1 do
    table.insert(selected_coins, coins[i])
    if remove then
      table.remove(coins, i)
    end
  end 
  return selected_coins
end

local function box_is_full(box_index, pack)
  -- Ensure all coins in 'pack' can fit into box at 'box_index'
  local count_in_box = 0
  for _, c in ipairs(coins) do
    if c.box == box_index then
      count_in_box = count_in_box + 1
    end
  end
  if count_in_box + #pack > BOX_ROWS then
    -- error("Cannot drop pack: box " .. box_index .. " would overflow")
    return true
  end

  return false
end

local function drop_pack_on(box_index, pack)
  
  -- Update box and assign fresh 'order' values so they go to the top of target box
  for _, c in ipairs(pack) do
    c.box = box_index
    c.order = next_order
    next_order = next_order + 1
    table.insert(coins, c)
  end
  sort_coins()
end

function love.draw()
  draw_all_boxes()
  draw_all_coins()
  print_coins(coins, 1)
end
-- ========= Hit testing: which box did we click? =========
-- Your columns are centered at x = COLUMN_STEP * column (1-based).
-- We’ll snap clicks to the nearest column and also gate by the vertical box area.
local BOX_ROWS = 6  -- you draw 6 cells per box column
local function box_at(x, y)
  -- snap X to nearest column
  local col = math.floor((x / COLUMN_STEP) + 0.5)
  if col < 1 or col > #boxes then return nil end

  -- only accept clicks within the vertical bounds where boxes are drawn
  local y_min = TOP_Y - (COIN_R + 4)
  local y_max = TOP_Y + ROW_STEP * (BOX_ROWS - 1) + (COIN_R + 4)
  if y < y_min or y > y_max then return nil end

  return col
end

function love.mousepressed(x, y, button)
  if button ~= 1 then return end
  local bx = box_at(x, y)
  if not bx then return end

    if not selection then
      -- First click: try to pick up from this box
      local pack = pick_coin_from_box(bx, {remove = true})
      if #pack > 0 then
        selection = { box = bx, pack = pack }
        -- Optional: play a sound / set a highlight
        -- print(("Picked %d coin(s) of %s from box %d"):format(#pack, pack[1].color, bx))
      else
        -- print("Nothing to take from this box")
      end
    else
      if box_is_full(bx, selection.pack) then
        BOX_IS_FULL = true
        return
      end
      -- Second click: drop onto target
      drop_pack_on(bx, selection.pack)
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
