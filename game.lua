local game = {}

local utils = require("utils")

local Non_Active_Colors = {
  gray = {0.5, 0.5, 0.5},
  light_blue = {0.2, 0.8, 0.8},
  light_green = {0.6, 1.0, 0.2},
}

local COLORS = {
  green = {0.2, 0.8, 0.2},
  red   = {0.9, 0.2, 0.2},
  blue  = {0.2, 0.4, 0.9},
  orange = {1.0, 0.6, 0.1},
  pink   = {1.0, 0.4, 0.7},
}

-- Timers
local merge_timer = 0
-- GamePlay Stuff
local points = 0
local points_per_coin = 10

local BOX_ROWS   = 3 -- number of coin slots per boxes
function game.getState()
  return {
    boxes           = boxes,
    box_rows        = BOX_ROWS,
    COLORS          = COLORS,
    non_active      = Non_Active_Colors,
    colors_str      = colors_str,
    selection       = selection,
    points          = points,
    points_per_coin = points_per_coin,
    merge_timer     = merge_timer,
    BOX_ROWS        = BOX_ROWS,
  }
end
function game.init()
 
  boxes              = { {}, {}, {}, {}, {} } -- just to count how many stacks you want
  colors_str         = { "green", "red", "blue", "orange", "pink" }
  local colors_cnt   = { green = 0, red = 0, blue = 0, orange = 0, pink = 0 }
  local box, color

  local total_coins  = #boxes * (BOX_ROWS - 1)
  local max_by_color = #colors_str * BOX_ROWS

  if total_coins > max_by_color then
    error("Impossible constraints: too many coins for per-color limit")
  end


  for i = 1, #boxes * (BOX_ROWS - 1) do
    ::box::
    box = math.random(#boxes)
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

function game.pick_coin_from_box(box_index, opts)
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

function game.add_coins()
  local colors = colors_str
  local colors_cnt = { green = 0, red = 0, blue = 0, orange = 0, pink = 0 }
  local total_coins = 0

  -- initialize colors count with 0
  for _, color in ipairs(colors) do
    colors_cnt[color] = 0
  end
  --get current color counts
  for bi, ci, color in utils.each_coin(boxes) do
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

function game.update(dt)
  if merge_timer > 0 then
        merge_timer = merge_timer - dt
  end
  return merge_timer
end

function game.merge()
  -- TODO make a random special reward when merging
  -- create a squares or just beautiful stones that also can merge too
  -- give points for merging
  local combo, total_same, current_color, merged = 0, 0, "", false

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
        combo = combo + 1
        -- remove these coins from the box 
        game.pick_coin_from_box(box_index, {remove = true})
        points = points + points_per_coin*combo*BOX_ROWS
        merged = true
      end
    end
  end
  if merged then
    merge_timer = 2
  end
end

return game