-- arena_screen.lua
-- Merge Arena screen: 7x8 grid with boxes/sealed items, dispenser, stash,
-- orders panel, drag-and-drop, generator tapping, and tutorial system.

local screens = require("screens")
local layout = require("layout")
local resources = require("resources")
local bags = require("bags")
local tab_bar = require("tab_bar")
local arena = require("arena")
local arena_chains = require("arena_chains")
local arena_orders = require("arena_orders")
local drops = require("drops")
local effects = require("effects")
local particles = require("particles")
local popups = require("popups")

local yandex = require("yandex")

local arena_screen = {}

local VW, VH = layout.VW, layout.VH
local font

-- Grid layout constants
local GRID_COLS, GRID_ROWS = 7, 8
local CELL_SIZE = 140
local CELL_GAP = 4
local GRID_WIDTH = GRID_COLS * CELL_SIZE + (GRID_COLS - 1) * CELL_GAP  -- 1004
local GRID_HEIGHT = GRID_ROWS * CELL_SIZE + (GRID_ROWS - 1) * CELL_GAP -- 1148
local GRID_X = math.floor((VW - GRID_WIDTH) / 2)

-- Resources bar (top)
local RESOURCES_H = 90

-- Resource pill geometry (shared between drawResources and fly-to-bar targeting)
local PILL_W, PILL_H, PILL_GAP = 300, 56, 30
local PILL_START_X = math.floor((VW - (3 * PILL_W + 2 * PILL_GAP)) / 2)
local PILL_Y = math.floor((RESOURCES_H - PILL_H) / 2)

-- Header row: dispenser circle (left) + compact orders strip (right)
local HEADER_Y = 95
local HEADER_H = 155
local HEADER_BOTTOM = HEADER_Y + HEADER_H  -- 250

-- Dispenser circle (left side of header)
local DISP_SIZE = 130
local DISP_X = 25
local DISP_Y = HEADER_Y + math.floor((HEADER_H - DISP_SIZE) / 2)

-- Orders strip (right of dispenser)
local ORDERS_STRIP_X = DISP_X + DISP_SIZE + 20  -- ~175
local ORDERS_STRIP_W = VW - ORDERS_STRIP_X - 10  -- ~895
local ORDER_COMPACT_W = 200
local ORDER_COMPACT_H = HEADER_H - 10            -- ~145
local ORDER_COMPACT_GAP = 8

-- Grid (shifted down to make room for header)
local GRID_TOP_Y = 260

-- Stash / Storage
local STASH_Y = GRID_TOP_Y + GRID_HEIGHT + 12   -- 1420
local STASH_SLOT_SIZE = 100
local STASH_GAP = 6
-- Dynamic stash count from skill tree
local function getStashCount()
  return require("arena").getStashSize()
end
local function getStashLayout()
  local count = getStashCount()
  local w = count * STASH_SLOT_SIZE + (count - 1) * STASH_GAP
  local sx = math.floor((VW - w) / 2)
  return count, w, sx
end

-- Drag state
local drag = nil  -- {source, index, item, x, y, start_x, start_y}

-- Tween animation for newly placed/revealed items
local slot_tweens = {}  -- {[index] = {time, duration, style}}
local TWEEN_DURATION = 0.35
local JELLY_DURATION = 0.2   -- simple scale tween on merge

-- Chest open shake animation (D-04)
local chest_shakes = {}  -- {[idx] = {time, duration, chain_id}}

local dissolve_ghosts = {}  -- D-03: source cell ghost for dissolve draw
local gen_fly = nil  -- {src_x, src_y, dst_x, dst_y, item, time, duration, dst_idx}
local GEN_FLY_DURATION = 0.25
local discovered_items = {}  -- "chain_id:level" = true
local notifications = {}  -- array of {text, timer, max_timer, color, slide}
local NOTIF_DURATION = 2.5
local NOTIF_SLIDE_IN = 0.2
local fuel_depleted_timer = 0    -- accumulates while fuel=0, overlay shows after 3s
local fuel_overlay_shown = false -- true once overlay is visible
local fuel_overlay_dismissed = false -- true after player dismisses overlay
local AD_FUEL_REWARD = 5
local waiting_for_ad_reward = false

-- Easing: elastic out (bouncy pop)
local function easeOutElastic(t)
  if t <= 0 then return 0 end
  if t >= 1 then return 1 end
  local p = 0.35
  return math.pow(2, -10 * t) * math.sin((t - p / 4) * (2 * math.pi) / p) + 1
end

-- Easing: smooth ease-out cubic
local function easeOutCubic(t)
  t = t - 1
  return t * t * t + 1
end

local function showNotification(text, color)
  notifications[#notifications + 1] = {
    text = text,
    timer = NOTIF_DURATION,
    max_timer = NOTIF_DURATION,
    color = color or {1, 1, 1},
    slide = 0,  -- 0 = offscreen right, 1 = fully in
  }
  if #notifications > 5 then
    table.remove(notifications, 1)
  end
end

-- === COORDINATE HELPERS ===

local function cellScreenPos(index)
  local col, row = arena.toColRow(index)
  if not col then return 0, 0 end
  local x = GRID_X + (col - 1) * (CELL_SIZE + CELL_GAP)
  local y = GRID_TOP_Y + (row - 1) * (CELL_SIZE + CELL_GAP)
  return x, y
end

local function cellCenterPos(index)
  local x, y = cellScreenPos(index)
  return x + CELL_SIZE / 2, y + CELL_SIZE / 2
end

local function gridCellAt(x, y)
  if x < GRID_X or y < GRID_TOP_Y then return nil end
  local col = math.floor((x - GRID_X) / (CELL_SIZE + CELL_GAP)) + 1
  local row = math.floor((y - GRID_TOP_Y) / (CELL_SIZE + CELL_GAP)) + 1
  if col < 1 or col > GRID_COLS or row < 1 or row > GRID_ROWS then return nil end
  -- Verify inside actual cell (not in gap)
  local cx = GRID_X + (col - 1) * (CELL_SIZE + CELL_GAP)
  local cy = GRID_TOP_Y + (row - 1) * (CELL_SIZE + CELL_GAP)
  if x >= cx and x < cx + CELL_SIZE and y >= cy and y < cy + CELL_SIZE then
    return arena.toIndex(col, row)
  end
  return nil
end

local function stashSlotAt(x, y)
  if y < STASH_Y or y > STASH_Y + STASH_SLOT_SIZE then return nil end
  local count, _, stash_start_x = getStashLayout()
  if x < stash_start_x then return nil end
  local slot = math.floor((x - stash_start_x) / (STASH_SLOT_SIZE + STASH_GAP)) + 1
  if slot < 1 or slot > count then return nil end
  local sx = stash_start_x + (slot - 1) * (STASH_SLOT_SIZE + STASH_GAP)
  if x >= sx and x < sx + STASH_SLOT_SIZE then return slot end
  return nil
end

local function stashScreenPos(slot)
  local _, _, stash_start_x = getStashLayout()
  local x = stash_start_x + (slot - 1) * (STASH_SLOT_SIZE + STASH_GAP)
  return x, STASH_Y
end

local function isInDispenser(x, y)
  local cx = DISP_X + DISP_SIZE / 2
  local cy = DISP_Y + DISP_SIZE / 2
  local dx, dy = x - cx, y - cy
  return dx * dx + dy * dy <= (DISP_SIZE / 2) * (DISP_SIZE / 2)
end

-- === DRAWING HELPERS ===

-- Per-chain shape assignments
local CHAIN_SHAPES = {
  Ch = "hexagon",      -- ice crystals are hexagonal
  Cu = "square",       -- box/storage is rectangular
  He = "triangle_up",  -- fire/heat rises
  Bl = "circle",       -- spinning blender = round
  Ki = "pentagon",     -- 5 kitchen tools
  Ta = "diamond",      -- elegant/angular tableware
  Me = "octagon",      -- thick/solid like a cut of meat
  Da = "star_6",       -- 6-pointed dairy star
  Ba = "star_5",       -- classic 5-pointed star
  De = "star_4",       -- 4-pointed sugar crystal sparkle
  So = "triangle_down",-- liquid pours down
  Be = "heptagon",     -- 7-sided cup rim view
}

-- n-gon vertices centered at (cx,cy), circumradius r, first vertex at start_angle
local function makeNGon(cx, cy, r, n, start_angle)
  local v, step = {}, 2 * math.pi / n
  for i = 0, n - 1 do
    local a = start_angle + i * step
    v[#v+1] = cx + r * math.cos(a)
    v[#v+1] = cy + r * math.sin(a)
  end
  return v
end

-- Star polygon vertices: n_points outer/inner alternating, outer radius r, inner r_inner
local function makeStar(cx, cy, r, r_inner, n_points, start_angle)
  local v, step = {}, math.pi / n_points
  for i = 0, n_points * 2 - 1 do
    local a = start_angle + i * step
    local rr = (i % 2 == 0) and r or r_inner
    v[#v+1] = cx + rr * math.cos(a)
    v[#v+1] = cy + rr * math.sin(a)
  end
  return v
end

-- Shape dispatch table: shape_name -> {type, sides, start_angle [, inner_ratio]}
local HP = -math.pi / 2
local SHAPE_DEFS = {
  hexagon = {"ngon", 6, HP}, square = {"ngon", 4, -math.pi * 0.75},
  diamond = {"ngon", 4, HP}, triangle_up = {"ngon", 3, HP},
  triangle_down = {"ngon", 3, math.pi / 2}, pentagon = {"ngon", 5, HP},
  heptagon = {"ngon", 7, HP}, octagon = {"ngon", 8, HP},
  star_5 = {"star", 5, HP, 0.42}, star_6 = {"star", 6, HP, 0.48},
  star_4 = {"star", 4, HP, 0.38},
}

local function drawShape(shape, cx, cy, r, mode)
  mode = mode or "fill"
  local def = SHAPE_DEFS[shape]
  if not def then
    love.graphics.circle(mode, cx, cy, r)
  elseif def[1] == "ngon" then
    love.graphics.polygon(mode, makeNGon(cx, cy, r, def[2], def[3]))
  else -- star
    love.graphics.polygon(mode, makeStar(cx, cy, r, r * def[4], def[2], def[3]))
  end
end

local function drawItemCircle(chain_id, level, cx, cy, radius, alpha)
  alpha = alpha or 1
  local c = arena_chains.getColor(chain_id)
  local shape = CHAIN_SHAPES[chain_id] or "circle"

  -- Shadow (same shape, offset)
  love.graphics.setColor(0, 0, 0, 0.3 * alpha)
  drawShape(shape, cx + 2, cy + 2, radius)

  -- Main shape
  love.graphics.setColor(c[1], c[2], c[3], alpha)
  drawShape(shape, cx, cy, radius)

  -- Highlight
  love.graphics.setColor(1, 1, 1, 0.2 * alpha)
  love.graphics.circle("fill", cx - radius * 0.2, cy - radius * 0.25, radius * 0.35)

  -- Level number background + text
  love.graphics.setColor(0, 0, 0, 0.5 * alpha)
  love.graphics.circle("fill", cx, cy, radius * 0.42)
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.setFont(font)
  local text = tostring(level)
  local tw = font:getWidth(text)
  local th = font:getHeight()
  love.graphics.print(text, cx - tw / 2, cy - th / 2)
end

local function drawGeneratorIcon(cx, cy, radius, alpha)
  -- Lightning bolt icon
  alpha = alpha or 1
  love.graphics.setColor(1, 0.9, 0.1, 0.9 * alpha)
  local s = radius * 0.35
  love.graphics.polygon("fill",
    cx - s * 0.3, cy - s,
    cx + s * 0.5, cy - s * 0.2,
    cx, cy + s * 0.1,
    cx + s * 0.3, cy + s * 0.1,
    cx - s * 0.5, cy + s,
    cx, cy - s * 0.1,
    cx - s * 0.3, cy - s * 0.1
  )
end

local function drawChargeBar(x, y, size, charges, max_charges)
  if not charges or not max_charges or max_charges <= 0 then return end
  local bar_w, bar_h = size * 0.7, 8
  local bar_x, bar_y = x + (size - bar_w) / 2, y + size - 20
  love.graphics.setColor(0.2, 0.2, 0.2, 0.7)
  love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 3, 3)
  local fill = charges / max_charges
  if fill > 0 then
    local r, g, b = 1, 0.9, 0.1
    if fill < 0.3 then r, g, b = 1, 0.4, 0.2 end
    love.graphics.setColor(r, g, b, 0.9)
    love.graphics.rectangle("fill", bar_x, bar_y, bar_w * fill, bar_h, 3, 3)
  end
  love.graphics.setColor(0.5, 0.5, 0.4, 0.6)
  love.graphics.rectangle("line", bar_x, bar_y, bar_w, bar_h, 3, 3)
end

local function drawCellItem(chain_id, level, x, y, size, sealed, alpha)
  alpha = alpha or 1
  local cx = x + size / 2
  local cy = y + size / 2
  local radius = size * 0.36
  local is_gen = arena_chains.isGenerator(chain_id, level)

  if sealed then
    -- Desaturated + lock overlay
    drawItemCircle(chain_id, level, cx, cy, radius, alpha * 0.6)
    -- Lock icon (simple padlock shape)
    love.graphics.setColor(0.8, 0.8, 0.8, 0.7 * alpha)
    local ls = size * 0.12
    love.graphics.rectangle("fill", cx - ls, cy + radius * 0.5, ls * 2, ls * 1.5, 2, 2)
    love.graphics.setLineWidth(2)
    love.graphics.arc("line", "open", cx, cy + radius * 0.5, ls * 0.8, math.pi, 0)
    love.graphics.setLineWidth(1)
  else
    drawItemCircle(chain_id, level, cx, cy, radius, alpha)
    if is_gen then
      drawGeneratorIcon(cx, cy - radius * 0.6, radius, alpha)
    end
  end

  -- Item name below circle
  local name = arena_chains.getItemName(chain_id, level)
  if name then
    love.graphics.setColor(0.8, 0.8, 0.8, 0.7 * alpha)
    love.graphics.printf(name, x, y + size - 26, size, "center")
  end
end

-- === MAIN DRAWING FUNCTIONS ===

-- Draw the resources (Fuel, Stars, Bags) as a horizontal pill row
local function drawResources()
  love.graphics.setFont(font)

  -- Fuel color: orange <10, red pulsing <5, normal otherwise
  local fuel = resources.getFuel()
  local fuel_color = {1, 0.75, 0.15}
  if fuel < 5 then
    local pulse = 0.6 + 0.4 * math.sin(love.timer.getTime() * 6)
    fuel_color = {1, 0.2 * pulse, 0.1 * pulse}
  elseif fuel < 10 then
    fuel_color = {1, 0.5, 0.15}
  end

  local fuel_text = fuel .. "/" .. resources.getFuelCap()
  local tokens = drops.getGenTokens()
  if tokens > 0 then
    fuel_text = fuel_text .. " +" .. tokens .. "T"
  end

  local entries = {
    {label = "Fuel",  value = fuel_text, color = fuel_color},
    {label = "Stars", value = tostring(resources.getStars()),                       color = {0.95, 0.85, 0.25}},
    {label = "Bags",  value = tostring(bags.getTotalAvailable()),                   color = {0.8, 0.6, 0.3}},
  }

  for i, entry in ipairs(entries) do
    local px = PILL_START_X + (i - 1) * (PILL_W + PILL_GAP)
    -- Pill background
    love.graphics.setColor(0.12, 0.16, 0.11, 0.9)
    love.graphics.rectangle("fill", px, PILL_Y, PILL_W, PILL_H, 10, 10)
    love.graphics.setColor(entry.color[1], entry.color[2], entry.color[3], 0.5)
    love.graphics.rectangle("line", px, PILL_Y, PILL_W, PILL_H, 10, 10)
    -- Label
    love.graphics.setColor(entry.color[1], entry.color[2], entry.color[3], 0.8)
    love.graphics.printf(entry.label, px + 8, PILL_Y + 6, PILL_W / 2 - 8, "left")
    -- Value
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(entry.value, px + PILL_W / 2, PILL_Y + 6, PILL_W / 2 - 8, "right")
  end

  -- Level info (top-right corner)
  love.graphics.setColor(0.45, 0.75, 0.50, 0.8)
  love.graphics.printf("Lv " .. arena_orders.getCurrentLevel(), VW - 110, 8, 100, "right")
end

local function drawDispenser()
  local cx, cy, r = DISP_X + DISP_SIZE / 2, DISP_Y + DISP_SIZE / 2, DISP_SIZE / 2
  love.graphics.setColor(0.18, 0.30, 0.20, 0.9)
  love.graphics.circle("fill", cx, cy, r)
  love.graphics.setColor(0.30, 0.50, 0.30, 0.7)
  love.graphics.setLineWidth(3)
  love.graphics.circle("line", cx, cy, r)
  love.graphics.setLineWidth(1)
  local item = arena.getDispenserItem()
  if item then
    local item_size = DISP_SIZE * 0.72
    local ix = cx - item_size / 2
    local iy = cy - item_size / 2
    if item.state == "chest" then
      -- Chest in dispenser, colored by chain type
      local chest_color = arena_chains.getColor(item.chain_id or "Ch")
      love.graphics.setColor(chest_color[1], chest_color[2], chest_color[3], 0.95)
      love.graphics.rectangle("fill", ix + 4, iy + 4, item_size - 8, item_size - 8, 8, 8)
      love.graphics.setColor(chest_color[1] + 0.25, chest_color[2] + 0.25, chest_color[3] + 0.25, 0.9)
      love.graphics.rectangle("line", ix + 4, iy + 4, item_size - 8, item_size - 8, 8, 8)
      love.graphics.setColor(1, 1, 1, 0.9)
      love.graphics.printf(item.chain_id or "?", ix, iy + item_size * 0.3, item_size, "center")
    else
      drawCellItem(item.chain_id, item.level, ix, iy, item_size, false, 1)
    end
  else
    love.graphics.setColor(0.4, 0.4, 0.55, 0.7)
    love.graphics.printf("--", DISP_X, cy - 14, DISP_SIZE, "center")
  end

  -- Queue count badge (top-right of circle)
  local qsize = arena.getDispenserSize()
  if qsize > 1 then
    local bx = DISP_X + DISP_SIZE - 30
    local by = DISP_Y + 2
    love.graphics.setColor(0.15, 0.5, 0.85, 0.95)
    love.graphics.circle("fill", bx + 15, by + 15, 18)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("+" .. (qsize - 1), bx, by + 4, 30, "center")
  end

  -- "Tap" hint label below circle
  love.graphics.setColor(0.5, 0.6, 0.7, 0.5)
  love.graphics.printf("Dispenser", DISP_X - 10, DISP_Y + DISP_SIZE + 4, DISP_SIZE + 20, "center")
end

-- Compute which grid cells hold items needed for visible orders (green highlight)
local function getOrderHighlightedCells()
  local needed = {}  -- "chain_id:level" -> count still needed
  local visible = arena_orders.getVisibleOrders()
  for _, order in ipairs(visible) do
    for _, req in ipairs(order.requirements) do
      local key = req.chain_id .. ":" .. req.level
      needed[key] = (needed[key] or 0) + req.count
    end
  end
  local highlighted = {}
  local grid_data = arena.getGrid()
  for i = 1, arena.getGridSize() do
    local cell = grid_data[i]
    if cell and not cell.state then
      local key = cell.chain_id .. ":" .. cell.level
      if needed[key] and needed[key] > 0 then
        highlighted[i] = true
        needed[key] = needed[key] - 1
      end
    end
  end
  return highlighted
end

local function drawGrid()
  local grid_data = arena.getGrid()
  local highlighted = getOrderHighlightedCells()

  for i = 1, arena.getGridSize() do
    local x, y = cellScreenPos(i)
    local cell = grid_data[i]

    -- Slot background
    love.graphics.setColor(0.10, 0.14, 0.10, 0.85)
    love.graphics.rectangle("fill", x, y, CELL_SIZE, CELL_SIZE, 6, 6)
    love.graphics.setColor(0.22, 0.32, 0.20, 0.5)
    love.graphics.rectangle("line", x, y, CELL_SIZE, CELL_SIZE, 6, 6)

    -- Dissolve ghost: draw fading item on empty cell (D-03)
    local ghost = dissolve_ghosts[i]
    if ghost and slot_tweens[i] and slot_tweens[i].style == "dissolve_out" then
      local tw = slot_tweens[i]
      local t = math.min(tw.time / tw.duration, 1)
      local ease = t * t
      local g_alpha = 1 - ease
      local g_mult = 1 + ease * 0.5
      -- Temporarily brighten via drawCellItem alpha (glow approximated by passing high alpha)
      drawCellItem(ghost.chain_id, ghost.level, x, y, CELL_SIZE, false, g_alpha)
    end

    -- Skip if being dragged or fly-animated
    if drag and drag.source == "grid" and drag.index == i then
      -- Don't draw, it's being dragged
    elseif gen_fly and gen_fly.dst_idx == i then
      -- Don't draw, item is flying to this cell
    elseif cell then
      -- Apply pop-in tween (elastic bounce or jelly squeeze)
      local tw = slot_tweens[i]
      local draw_x, draw_y, draw_size = x, y, CELL_SIZE
      local draw_w, draw_h = CELL_SIZE, CELL_SIZE
      local tween_alpha = 1
      local color_mult = 1
      if tw then
        local t = math.min(tw.time / tw.duration, 1)
        if tw.style == "dissolve_out" then
          -- Glow + fade out (D-03: Arena items dissolve, don't explode)
          local ease = t * t  -- accelerating fade
          tween_alpha = 1 - ease
          color_mult = 1 + ease * 0.5  -- brighten colors up to 50%
        elseif tw.style == "jelly" then
          -- Simple ease-out scale from 0.7 to 1.0
          local ease = 1 - (1 - t) * (1 - t)
          local s = 0.7 + 0.3 * ease
          draw_w = CELL_SIZE * s
          draw_h = CELL_SIZE * s
          draw_size = draw_w
          draw_x = x + (CELL_SIZE - draw_w) / 2
          draw_y = y + (CELL_SIZE - draw_h) / 2
          tween_alpha = 1
        else
          local scale = easeOutElastic(t)
          draw_w = CELL_SIZE * scale
          draw_h = draw_w
          draw_size = draw_w
          draw_x = x + (CELL_SIZE - draw_w) / 2
          draw_y = y + (CELL_SIZE - draw_h) / 2
          tween_alpha = easeOutCubic(math.min(t * 3, 1))
        end
      end
      -- Chest shake offset (D-04)
      if chest_shakes[i] then
        draw_x = draw_x + (math.random() * 6 - 3)
        draw_y = draw_y + (math.random() * 6 - 3)
      end
      -- Normalize: use draw_w for item sizing
      if not draw_size then draw_size = math.min(draw_w, draw_h) end

      if cell.state == "box" then
        -- Closed box
        love.graphics.setColor(0.22, 0.28, 0.18, 0.9)
        love.graphics.rectangle("fill", draw_x + 4, draw_y + 4, draw_size - 8, draw_size - 8, 8, 8)
        love.graphics.setColor(0.35, 0.45, 0.28, 0.7)
        love.graphics.rectangle("line", draw_x + 4, draw_y + 4, draw_size - 8, draw_size - 8, 8, 8)
        love.graphics.setColor(0.42, 0.55, 0.32, 0.6)
        love.graphics.printf("?", draw_x, draw_y + draw_size / 2 - 14, draw_size, "center")
      elseif cell.state == "chest" then
        -- Tappable chest, colored by generator chain type
        local chest_color = arena_chains.getColor(cell.chain_id or "Ch")
        local pulse = 0.85 + 0.15 * math.sin(love.timer.getTime() * 3)
        love.graphics.setColor(chest_color[1] * pulse, chest_color[2] * pulse, chest_color[3] * pulse, 0.95)
        love.graphics.rectangle("fill", draw_x + 4, draw_y + 4, draw_size - 8, draw_size - 8, 10, 10)
        love.graphics.setColor(chest_color[1] + 0.25, chest_color[2] + 0.25, chest_color[3] + 0.25, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", draw_x + 4, draw_y + 4, draw_size - 8, draw_size - 8, 10, 10)
        love.graphics.setLineWidth(1)
        -- Chain abbreviation + charges
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.printf(cell.chain_id or "?", draw_x, draw_y + draw_size * 0.25, draw_size, "center")
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.printf("x" .. (cell.charges or 0), draw_x, draw_y + draw_size * 0.55, draw_size, "center")
      elseif cell.state == "sealed" then
        drawCellItem(cell.chain_id, cell.level, draw_x, draw_y, draw_size, true, tween_alpha)
      else
        -- Generator pulse: gentle scale + glow ring for charged generators (D-09)
        local is_gen = arena.isGeneratorCell(i) and not arena.isGeneratorLocked(i)
        if is_gen then
          local ch = arena.getGeneratorCharges(i)
          if ch and ch > 0 then
            local pulse_t = math.sin(love.timer.getTime() * 2.5 + i * 0.3)
            local gen_scale = 1.0 + pulse_t * 0.03
            -- Glow ring behind item
            local glow_a = 0.15 + 0.1 * pulse_t
            local cc = arena_chains.getColor(cell.chain_id)
            love.graphics.setColor(cc[1], cc[2], cc[3], glow_a)
            love.graphics.rectangle("fill", draw_x - 3, draw_y - 3, draw_w + 6, draw_h + 6, 12, 12)
            draw_size = draw_size * gen_scale
            draw_x = x + (CELL_SIZE - draw_size) / 2
            draw_y = y + (CELL_SIZE - draw_size) / 2
          end
        end
        -- Normal item (or generator)
        drawCellItem(cell.chain_id, cell.level, draw_x, draw_y, draw_size, false, tween_alpha)
        -- Green border if needed for an order
        if highlighted[i] then
          love.graphics.setColor(0.2, 0.9, 0.2, 0.35)
          love.graphics.setLineWidth(3)
          love.graphics.rectangle("line", draw_x + 2, draw_y + 2, draw_size - 4, draw_size - 4, 6, 6)
          love.graphics.setLineWidth(1)
        end
        -- Generator overlays: locked, charge bar, depleted
        if arena.isGeneratorCell(i) then
          if arena.isGeneratorLocked(i) then
            -- Locked generator overlay
            love.graphics.setColor(0.1, 0.1, 0.1, 0.55)
            love.graphics.rectangle("fill", draw_x, draw_y, draw_size, draw_size, 6, 6)
            -- Lock icon
            local lx, ly = draw_x + draw_size / 2, draw_y + draw_size / 2
            local ls = draw_size * 0.15
            love.graphics.setColor(0.7, 0.7, 0.7, 0.8)
            love.graphics.rectangle("fill", lx - ls, ly, ls * 2, ls * 1.5, 3, 3)
            love.graphics.setLineWidth(2)
            love.graphics.arc("line", "open", lx, ly, ls * 0.8, math.pi, 0)
            love.graphics.setLineWidth(1)
          else
            local ch, max_ch = arena.getGeneratorCharges(i)
            if ch and max_ch then
              drawChargeBar(draw_x, draw_y, draw_size, ch, max_ch)
              if ch <= 0 then
                -- Dimmed overlay
                love.graphics.setColor(0.15, 0.15, 0.15, 0.45)
                love.graphics.rectangle("fill", draw_x, draw_y, draw_size, draw_size, 6, 6)
                -- Recharge countdown
                local timer, total = arena.getRechargeProgress(i)
                if timer and total then
                  local remaining = math.ceil(total - timer)
                  local mins = math.floor(remaining / 60)
                  local secs = remaining % 60
                  love.graphics.setColor(0.9, 0.9, 0.9, 0.8)
                  love.graphics.printf(string.format("%d:%02d", mins, secs), draw_x, draw_y + draw_size / 2 - 12, draw_size, "center")
                end
              end
            end
          end
        end
      end
    end
  end

  -- Merge highlight when dragging
  if drag then
    for i = 1, arena.getGridSize() do
      local can_merge = false
      if drag.source == "grid" then
        can_merge = arena.canMerge(drag.index, i)
      elseif drag.source == "stash" then
        can_merge = arena.isEmpty(i)
      end
      if can_merge then
        local hx, hy = cellScreenPos(i)
        love.graphics.setColor(0.2, 0.8, 0.2, 0.15)
        love.graphics.rectangle("fill", hx, hy, CELL_SIZE, CELL_SIZE, 6, 6)
      end
    end
  end
end

local function drawStash()
  local step = arena.getTutorialStep()
  if step ~= "done" and type(step) == "number" and step < 15 then return end

  love.graphics.setColor(0.45, 0.55, 0.40, 0.5)
  love.graphics.printf("Storage", 0, STASH_Y - 22, VW, "center")

  for slot = 1, getStashCount() do
    local sx, sy = stashScreenPos(slot)
    -- Background
    love.graphics.setColor(0.10, 0.14, 0.10, 0.85)
    love.graphics.rectangle("fill", sx, sy, STASH_SLOT_SIZE, STASH_SLOT_SIZE, 6, 6)
    love.graphics.setColor(0.22, 0.32, 0.20, 0.5)
    love.graphics.rectangle("line", sx, sy, STASH_SLOT_SIZE, STASH_SLOT_SIZE, 6, 6)

    -- Item (skip if being dragged)
    if drag and drag.source == "stash" and drag.index == slot then
      -- Being dragged
    else
      local item = arena.getStashSlot(slot)
      if item then
        drawCellItem(item.chain_id, item.level, sx, sy, STASH_SLOT_SIZE, false, 1)
      end
    end
  end
end

-- Compact horizontal orders strip shown in the header row (right of dispenser)
local function drawOrdersStrip()
  local step = arena.getTutorialStep()
  if step ~= "done" and type(step) == "number" and step < 13 then return end

  local visible = arena_orders.getVisibleOrders()

  if #visible == 0 then
    love.graphics.setColor(0.5, 0.8, 0.5, 0.8)
    local mid_y = HEADER_Y + math.floor(HEADER_H / 2) - 14
    love.graphics.printf("All orders complete!", ORDERS_STRIP_X, mid_y, ORDERS_STRIP_W, "center")
    return
  end

  -- Count items on board once for all orders
  local on_board_counts = {}
  local grid_data = arena.getGrid()
  for gi = 1, arena.getGridSize() do
    local cell = grid_data[gi]
    if cell and not cell.state then
      local key = cell.chain_id .. ":" .. cell.level
      on_board_counts[key] = (on_board_counts[key] or 0) + 1
    end
  end

  local icon_size = 70  -- item circle size inside compact card

  for i, order in ipairs(visible) do
    local ox = ORDERS_STRIP_X + (i - 1) * (ORDER_COMPACT_W + ORDER_COMPACT_GAP)
    local oy = HEADER_Y + math.floor((HEADER_H - ORDER_COMPACT_H) / 2)
    local can_complete = arena.canCompleteOrder(order.id)

    -- Pulsing glow behind completable orders (D-09)
    if can_complete then
      local glow_t = 0.5 + 0.5 * math.sin(love.timer.getTime() * 3)
      love.graphics.setColor(0.3, 0.9, 0.4, 0.3 * glow_t)
      love.graphics.rectangle("fill", ox - 3, oy - 3, ORDER_COMPACT_W + 6, ORDER_COMPACT_H + 6, 10, 10)
      love.graphics.setColor(0.3, 0.9, 0.4, 0.6 * glow_t)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", ox - 3, oy - 3, ORDER_COMPACT_W + 6, ORDER_COMPACT_H + 6, 10, 10)
      love.graphics.setLineWidth(1)
    end
    -- Card background
    love.graphics.setColor(can_complete and {0.10, 0.25, 0.12, 0.92} or {0.12, 0.16, 0.12, 0.88})
    love.graphics.rectangle("fill", ox, oy, ORDER_COMPACT_W, ORDER_COMPACT_H, 8, 8)
    love.graphics.setColor(can_complete and {0.35, 0.75, 0.40, 0.7} or {0.25, 0.35, 0.24, 0.5})
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", ox, oy, ORDER_COMPACT_W, ORDER_COMPACT_H, 8, 8)
    love.graphics.setLineWidth(1)

    -- Character name (top)
    love.graphics.setColor(0.72, 0.78, 0.65, 0.9)
    love.graphics.printf(order.character, ox + 6, oy + 5, ORDER_COMPACT_W - 12, "left")

    -- XP reward (top-right)
    love.graphics.setColor(0.72, 0.78, 0.45, 0.85)
    love.graphics.printf("+" .. order.xp_reward .. "XP", ox + 4, oy + 5, ORDER_COMPACT_W - 8, "right")

    -- Item icons in a row (center area)
    local reqs = order.requirements
    local icon_gap = 6
    local icons_total_w = #reqs * icon_size + (#reqs - 1) * icon_gap
    local icons_start_x = ox + math.floor((ORDER_COMPACT_W - icons_total_w) / 2)
    local icons_y = oy + 30

    for j, req in ipairs(reqs) do
      local ix = icons_start_x + (j - 1) * (icon_size + icon_gap)
      local key = req.chain_id .. ":" .. req.level
      local on_board = on_board_counts[key] or 0
      local have_enough = on_board >= req.count

      -- Draw item icon
      drawCellItem(req.chain_id, req.level, ix, icons_y, icon_size, false, have_enough and 1 or 0.55)

      -- Count badge below icon
      love.graphics.setColor(have_enough and {0.2, 0.9, 0.2} or {0.75, 0.75, 0.75})
      love.graphics.printf(on_board .. "/" .. req.count, ix, icons_y + icon_size - 2, icon_size, "center")
    end

    -- COMPLETE overlay button (shown when completable)
    if can_complete then
      local btn_y = oy + ORDER_COMPACT_H - 38
      love.graphics.setColor(0.20, 0.55, 0.25, 0.95)
      love.graphics.rectangle("fill", ox + 6, btn_y, ORDER_COMPACT_W - 12, 32, 6, 6)
      love.graphics.setColor(0.92, 0.88, 0.78)
      love.graphics.printf("COMPLETE", ox + 6, btn_y + 6, ORDER_COMPACT_W - 12, "center")
    end
  end

end

local function drawDragged()
  if not drag then return end
  local size = CELL_SIZE
  if drag.source == "stash" then size = STASH_SLOT_SIZE end
  drawCellItem(drag.item.chain_id, drag.item.level,
    drag.x - size / 2, drag.y - size / 2, size, false, 0.85)
end

-- === TUTORIAL ===

local TUTORIAL_TOOLTIPS = {
  [1]  = "Drag the Ice Block to the grid",
  [2]  = "Drag another Ice Block onto the first one",
  [3]  = "Merge the two Ice Blocks!",
  [4]  = "Merge to make Bucket of Ice",
  [5]  = "Merge the Ice Cubes!",
  [6]  = "Drag Bucket of Ice onto the sealed one",
  [7]  = "Unseal it!",
  [8]  = "Tap the Fridge generator!",
  [9]  = "",
  [10] = "Drag the Egg to the grid",
  [11] = "Drag another Egg over",
  [12] = "Drag Egg onto the sealed Egg above",
  [13] = "Complete the order!",
  [14] = "",
  [15] = "Use the stash for extra storage",
  [16] = "Tap the Fridge generator again",
  [17] = "",
  [18] = "",
}

local function drawFuelDepletionOverlay()
  if not fuel_overlay_shown then return end

  -- Dimmed background
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, VW, VH)

  -- Panel
  local pw, ph = 700, 400
  local px = (VW - pw) / 2
  local py = (VH - ph) / 2

  love.graphics.setColor(0.12, 0.16, 0.12, 0.95)
  love.graphics.rectangle("fill", px, py, pw, ph, 16, 16)
  love.graphics.setColor(1, 0.4, 0.2, 0.8)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", px, py, pw, ph, 16, 16)
  love.graphics.setLineWidth(1)

  -- Title
  love.graphics.setColor(1, 0.4, 0.2, 1)
  love.graphics.printf("Out of Fuel!", px, py + 40, pw, "center")

  -- Message
  love.graphics.setColor(0.85, 0.85, 0.85, 0.9)
  love.graphics.printf("Merge coins to power your generators", px, py + 100, pw, "center")

  -- Stats
  love.graphics.setColor(0.95, 0.85, 0.25, 0.9)
  love.graphics.printf("Stars: " .. resources.getStars(), px, py + 160, pw, "center")
  love.graphics.setColor(0.8, 0.6, 0.3, 0.9)
  love.graphics.printf("Bags: " .. bags.getTotalAvailable(), px, py + 200, pw, "center")

  -- Watch Ad for Fuel button (only when Yandex SDK available)
  local bw, bh = 400, 70
  local ad_btn_y = py + 250
  if yandex.isReady() and not waiting_for_ad_reward then
    local bx = px + (pw - bw) / 2
    love.graphics.setColor(0.6, 0.2, 0.7, 0.9)
    love.graphics.rectangle("fill", bx, ad_btn_y, bw, bh, 12, 12)
    love.graphics.setColor(0.8, 0.4, 0.9, 0.8)
    love.graphics.rectangle("line", bx, ad_btn_y, bw, bh, 12, 12)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Watch Ad for +" .. AD_FUEL_REWARD .. " Fuel", bx, ad_btn_y + 18, bw, "center")
  end

  -- Go to Coin Sort button
  local bx = px + (pw - bw) / 2
  local by = py + ph - 110
  love.graphics.setColor(0.2, 0.6, 0.3, 0.9)
  love.graphics.rectangle("fill", bx, by, bw, bh, 12, 12)
  love.graphics.setColor(0.3, 0.8, 0.4, 0.8)
  love.graphics.rectangle("line", bx, by, bw, bh, 12, 12)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.printf("Go to Coin Sort", bx, by + 18, bw, "center")

  -- Dismiss hint
  love.graphics.setColor(0.6, 0.6, 0.6, 0.5)
  love.graphics.printf("(tap to dismiss)", px, py + ph - 30, pw, "center")
end

local function drawTutorial()
  local step = arena.getTutorialStep()
  if step == "done" or type(step) ~= "number" then return end

  local tooltip = TUTORIAL_TOOLTIPS[step]
  if tooltip and tooltip ~= "" then
    -- Draw tooltip below header row
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 40, HEADER_BOTTOM + 4, VW - 80, 32, 6, 6)
    love.graphics.setColor(1, 1, 0.7)
    love.graphics.printf(tooltip, 0, HEADER_BOTTOM + 10, VW, "center")
  end

  -- Highlight specific cells during certain steps
  if step == 6 or step == 7 then
    -- Highlight sealed Ch3 cells
    local grid_data = arena.getGrid()
    for i = 1, arena.getGridSize() do
      local cell = grid_data[i]
      if cell and cell.state == "sealed" and cell.chain_id == "Ch" and cell.level == 3 then
        local hx, hy = cellScreenPos(i)
        love.graphics.setColor(1, 1, 0.3, 0.2 + 0.1 * math.sin(love.timer.getTime() * 4))
        love.graphics.rectangle("fill", hx, hy, CELL_SIZE, CELL_SIZE, 6, 6)
        love.graphics.setColor(1, 1, 0.3, 0.7)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", hx, hy, CELL_SIZE, CELL_SIZE, 6, 6)
        love.graphics.setLineWidth(1)
      end
    end
  elseif step == 8 or step == 9 or step == 16 or step == 17 then
    -- Highlight generators
    local grid_data = arena.getGrid()
    for i = 1, arena.getGridSize() do
      if arena.isGeneratorCell(i) then
        local hx, hy = cellScreenPos(i)
        love.graphics.setColor(0.3, 1, 0.3, 0.15 + 0.1 * math.sin(love.timer.getTime() * 4))
        love.graphics.rectangle("fill", hx, hy, CELL_SIZE, CELL_SIZE, 6, 6)
      end
    end
  elseif step == 10 or step == 11 or step == 12 then
    -- Highlight sealed Da1 cells
    local grid_data = arena.getGrid()
    for i = 1, arena.getGridSize() do
      local cell = grid_data[i]
      if cell and cell.state == "sealed" and cell.chain_id == "Da" and cell.level == 1 then
        local hx, hy = cellScreenPos(i)
        love.graphics.setColor(1, 1, 0.3, 0.2 + 0.1 * math.sin(love.timer.getTime() * 4))
        love.graphics.rectangle("fill", hx, hy, CELL_SIZE, CELL_SIZE, 6, 6)
      end
    end
  end
end

local function advanceTutorial(event, data)
  local step = arena.getTutorialStep()
  if step == "done" or type(step) ~= "number" then return end

  if step == 1 then
    -- After placing first Ch1 on grid
    if event == "place_from_dispenser" then
      arena.pushDispenser("Ch", 1)
      arena.setTutorialStep(2)
    end
  elseif step == 2 then
    -- After placing second Ch1 (or merging)
    if event == "merge" and data and data.chain_id == "Ch" and data.level == 2 then
      arena.pushDispenser("Ch", 2)
      arena.setTutorialStep(4)
    elseif event == "place_from_dispenser" then
      arena.setTutorialStep(3)
    end
  elseif step == 3 then
    -- Waiting for Ch1+Ch1 merge
    if event == "merge" and data and data.chain_id == "Ch" and data.level == 2 then
      arena.pushDispenser("Ch", 2)
      arena.setTutorialStep(4)
    end
  elseif step == 4 then
    -- After placing Ch2 or merging
    if event == "merge" and data and data.chain_id == "Ch" and data.level == 3 then
      arena.setTutorialStep(6)
    elseif event == "place_from_dispenser" then
      arena.setTutorialStep(5)
    end
  elseif step == 5 then
    -- Waiting for Ch2+Ch2 merge
    if event == "merge" and data and data.chain_id == "Ch" and data.level == 3 then
      arena.setTutorialStep(6)
    end
  elseif step == 6 or step == 7 then
    -- Prompt: drag Ch3 onto sealed Ch3
    if event == "merge" and data and data.chain_id == "Ch" and data.level == 4 and data.was_sealed then
      arena.setTutorialStep(8)
    end
  elseif step == 8 or step == 9 then
    -- Prompt: tap generator
    if event == "tap_generator" then
      arena.pushDispenser("Da", 1)
      arena.setTutorialStep(10)
    end
  elseif step == 10 then
    if event == "place_from_dispenser" then
      arena.pushDispenser("Da", 1)
      arena.setTutorialStep(11)
    end
  elseif step == 11 then
    if event == "merge" and data and data.chain_id == "Da" and data.level == 2 then
      arena.setTutorialStep(13)
    elseif event == "place_from_dispenser" then
      arena.setTutorialStep(12)
    end
  elseif step == 12 then
    if event == "merge" and data and data.chain_id == "Da" and data.level == 2 then
      arena.setTutorialStep(13)
    end
  elseif step == 13 or step == 14 then
    if event == "complete_order" then
      arena.setTutorialStep(15)
    end
  elseif step == 15 then
    -- Show stash, advance after any action
    if event == "any" then
      arena.setTutorialStep(16)
    end
  elseif step == 16 or step == 17 then
    if event == "tap_generator" then
      arena.setTutorialStep("done")
    end
  end
end

-- === SCREEN INTERFACE ===

function arena_screen.init(assets)
  font = assets.font
end

function arena_screen.enter()
  drag = nil
  slot_tweens = {}
  chest_shakes = {}
  dissolve_ghosts = {}
  gen_fly = nil
  fuel_depleted_timer = 0
  fuel_overlay_shown = false
  fuel_overlay_dismissed = false

  -- Build discovered items from existing grid + stash (avoid false "New" notifications)
  discovered_items = {}
  local grid_data = arena.getGrid()
  for i = 1, arena.getGridSize() do
    local cell = grid_data[i]
    if cell and cell.chain_id and cell.level then
      discovered_items[cell.chain_id .. ":" .. cell.level] = true
    end
  end
  for slot = 1, arena.getStashSize() do
    local item = arena.getStashSlot(slot)
    if item then
      discovered_items[item.chain_id .. ":" .. item.level] = true
    end
  end

  -- Resource bar targets for fly-to-bar (D-05)
  -- Derived from pill geometry constants, not hardcoded pixel values
  local fuel_cx = PILL_START_X + PILL_W / 2
  local stars_cx = PILL_START_X + (PILL_W + PILL_GAP) + PILL_W / 2
  local pill_cy = PILL_Y + PILL_H / 2
  effects.setResourceBarTargets(fuel_cx, pill_cy, stars_cx, pill_cy)

  -- Transfer shelf items from Coin Sort to dispenser
  local shelf_items = drops.transferShelf()
  if #shelf_items > 0 then
    arena.pushDispenserMultiple(shelf_items)
    showNotification(#shelf_items .. " item(s) from Coin Sort!", {0.3, 0.9, 0.5})
  end

  -- On first enter with tutorial step 1, seed dispenser with first Ch1
  local step = arena.getTutorialStep()
  if step == 1 and arena.getDispenserSize() == 0 then
    arena.pushDispenser("Ch", 1)
  end
end

function arena_screen.exit()
end

function arena_screen.update(dt)
  bags.update(dt)
  arena.update(dt)

  -- Update notification queue
  local ni = 1
  while ni <= #notifications do
    notifications[ni].timer = notifications[ni].timer - dt
    notifications[ni].slide = (notifications[ni].slide or 0) + dt
    if notifications[ni].timer <= 0 then
      table.remove(notifications, ni)
    else
      ni = ni + 1
    end
  end

  -- Update slot tweens
  for slot, tw in pairs(slot_tweens) do
    tw.time = tw.time + dt
    if tw.time >= tw.duration then
      slot_tweens[slot] = nil
      dissolve_ghosts[slot] = nil  -- clean up dissolve ghost when tween expires
    end
  end

  -- Update chest shakes (D-04)
  for idx, cs in pairs(chest_shakes) do
    cs.time = cs.time + dt
    if cs.time >= cs.duration then
      -- Shake done: spawn chain-colored particles and execute chest tap
      local chain_color = arena_chains.getColor(cs.chain_id or "Ch")
      local cx, cy = cellCenterPos(idx)
      particles.spawnMergeExplosion(cx, cy, chain_color)
      -- Execute deferred chest tap
      local result = arena.tapChest(idx)
      if result then
        slot_tweens[result.drop_index] = {time = 0, duration = TWEEN_DURATION}
        local item_name = arena_chains.getItemName(result.drop_chain_id, result.drop_level) or "item"
        if result.charges_remaining > 0 then
          showNotification("Chest: " .. item_name .. "! (" .. result.charges_remaining .. " left)", {1, 0.85, 0.3})
        else
          showNotification("Chest: " .. item_name .. "! (chest empty)", {1, 0.85, 0.3})
        end
      end
      chest_shakes[idx] = nil
    end
  end

  -- Update effects (fly-to-bar, flash, burst)
  effects.update(dt)

  -- Update generator fly animation
  if gen_fly then
    gen_fly.time = gen_fly.time + dt
    if gen_fly.time >= gen_fly.duration then
      -- Fly complete, item is now in cell (no pop-in)
      gen_fly = nil
    end
  end

  -- Update drag position from mouse (desktop)
  -- Fuel depletion overlay timer
  if resources.getFuel() < 1 and arena.isTutorialDone() then
    fuel_depleted_timer = fuel_depleted_timer + dt
    if fuel_depleted_timer >= 3 and not fuel_overlay_dismissed then
      fuel_overlay_shown = true
    end
  else
    fuel_depleted_timer = 0
    fuel_overlay_shown = false
    fuel_overlay_dismissed = false
  end

  -- Poll rewarded ad result
  if waiting_for_ad_reward then
    local r = yandex.getRewardedResult()
    if r == "closed_rewarded" then
      resources.addFuel(AD_FUEL_REWARD)
      showNotification("+" .. AD_FUEL_REWARD .. " Fuel from ad!", {0.6, 0.2, 0.7})
      fuel_overlay_shown = false
      fuel_overlay_dismissed = true
      yandex.resetRewardedResult()
      waiting_for_ad_reward = false
    elseif r == "closed_no_reward" or r == "error" then
      yandex.resetRewardedResult()
      waiting_for_ad_reward = false
    end
  end

  if drag and love.mouse.isDown(1) then
    local mx, my = love.mouse.getPosition()
    local ww, wh = love.graphics.getDimensions()
    local sc = math.min(ww / VW, wh / VH)
    local oox = (ww - VW * sc) / 2
    local ooy = (wh - VH * sc) / 2
    drag.x = (mx - oox) / sc
    drag.y = (my - ooy) / sc
  end
end

function arena_screen.draw()
  love.graphics.setFont(font)

  -- Background
  love.graphics.setColor(0.18, 0.22, 0.16)
  love.graphics.rectangle("fill", 0, 0, VW, VH)

  drawResources()
  drawDispenser()
  drawOrdersStrip()
  drawGrid()
  -- Generator fly animation (drawn above grid)
  if gen_fly then
    local t = math.min(gen_fly.time / gen_fly.duration, 1)
    local fx = gen_fly.src_x + (gen_fly.dst_x - gen_fly.src_x) * t
    local fy = gen_fly.src_y + (gen_fly.dst_y - gen_fly.src_y) * t
    -- Arc: jump up then land (parabola peaking at t=0.3 for a pop-out feel)
    local arc = -4 * 80 * t * (1 - t)  -- peaks at ~80px upward at midpoint
    fy = fy + arc
    drawCellItem(gen_fly.item.chain_id, gen_fly.item.level, fx, fy, CELL_SIZE, false, 1)
  end
  drawStash()
  drawDragged()
  drawTutorial()
  effects.draw()  -- fly-to-bar icons + burst particles

  -- Notification stack (newest at bottom, oldest at top) with slide + fade
  for ni, notif in ipairs(notifications) do
    -- Slide in from right
    local slide_t = math.min(notif.slide / NOTIF_SLIDE_IN, 1)
    local slide_ease = easeOutCubic(slide_t)
    local offset_x = (1 - slide_ease) * 400  -- slides 400px from right

    -- Fade out in last 0.5s
    local alpha = notif.timer < 0.5 and (notif.timer / 0.5) or 1
    -- Scale pop on entry
    local scale_y = slide_t < 1 and (0.6 + 0.4 * easeOutElastic(slide_t)) or 1

    local ny = GRID_TOP_Y - 35 - (#notifications - ni) * 38
    local bar_h = 32 * scale_y
    local bar_y = ny + (32 - bar_h) / 2

    love.graphics.setColor(0, 0, 0, alpha * 0.65)
    love.graphics.rectangle("fill", 40 + offset_x, bar_y, VW - 80, bar_h, 8, 8)
    -- Colored accent line on left
    love.graphics.setColor(notif.color[1], notif.color[2], notif.color[3], alpha * 0.8)
    love.graphics.rectangle("fill", 40 + offset_x, bar_y, 4, bar_h, 2, 2)
    -- Text
    love.graphics.setColor(notif.color[1], notif.color[2], notif.color[3], alpha)
    love.graphics.printf(notif.text, offset_x, ny + 5, VW, "center")
  end

  -- Overlay flash (D-06: drawn above content, below tab bar)
  effects.drawFlash()

  -- Fuel depletion overlay (drawn above everything except tab bar)
  drawFuelDepletionOverlay()

  -- Popup overlays (above HUD, below tab bar per UI-SPEC z-order)
  popups.drawToasts()
  popups.drawModal()

  -- Tab bar
  tab_bar.draw("arena")
end

function arena_screen.mousepressed(x, y, button)
  if button ~= 1 then return end

  -- Popup input priority (per UI-SPEC interaction contract)
  if popups.isInputBlocked() then
    popups.handleModalTap(x, y)
    return
  end
  if popups.handleToastTap(x, y) then
    return
  end

  -- Fuel depletion overlay intercepts clicks
  if fuel_overlay_shown then
    local pw, ph = 700, 400
    local px = (VW - pw) / 2
    local py = (VH - ph) / 2
    local bw, bh = 400, 70
    local bx = px + (pw - bw) / 2
    -- "Watch Ad for Fuel" button
    local ad_btn_y = py + 250
    if yandex.isReady() and not waiting_for_ad_reward
       and x >= bx and x <= bx + bw and y >= ad_btn_y and y <= ad_btn_y + bh then
      yandex.showRewarded()
      waiting_for_ad_reward = true
      return
    end
    -- "Go to Coin Sort" button
    local by = py + ph - 110
    if x >= bx and x <= bx + bw and y >= by and y <= by + bh then
      screens.switch("coin_sort")
      return
    end
    -- Dismiss on any click
    fuel_overlay_shown = false
    fuel_overlay_dismissed = true
    return
  end

  -- Tab bar
  local tab = tab_bar.mousepressed(x, y)
  if tab and tab ~= "arena" then
    screens.switch(tab)
    return
  end

  -- Order complete buttons (compact strip in header)
  local step = arena.getTutorialStep()
  local show_orders = step == "done" or (type(step) == "number" and step >= 13)
  if show_orders then
    local visible = arena_orders.getVisibleOrders()
    for i, order in ipairs(visible) do
      if arena.canCompleteOrder(order.id) then
        local ox = ORDERS_STRIP_X + (i - 1) * (ORDER_COMPACT_W + ORDER_COMPACT_GAP)
        local oy = HEADER_Y + math.floor((HEADER_H - ORDER_COMPACT_H) / 2)
        local btn_y = oy + ORDER_COMPACT_H - 38
        if x >= ox + 6 and x <= ox + ORDER_COMPACT_W - 6 and y >= btn_y and y <= btn_y + 32 then
          local reward = arena.completeOrder(order.id)
          if reward then
            -- Order completion toast (D-05)
            local body_parts = {}
            if reward.bag_reward and reward.bag_reward > 0 then
              table.insert(body_parts, "+" .. reward.bag_reward .. " Bags")
            end
            if reward.star_reward and reward.star_reward > 0 then
              table.insert(body_parts, "+" .. reward.star_reward .. " Stars")
            end
            popups.push({
              tier = "toast",
              title = "Order Delivered!",
              body = table.concat(body_parts, " "),
              rewards = {},
            })
            -- Fly-to-bar for star gain (D-04: resource gains use fly-to-bar only)
            if reward.star_reward and reward.star_reward > 0 then
              local card_cx = ox + ORDER_COMPACT_W / 2
              local card_cy = oy + ORDER_COMPACT_H / 2
              local num_icons = math.min(reward.star_reward, 5)
              for fi = 1, num_icons do
                effects.spawnResourceFly(card_cx, card_cy + fi * 10, "star")
              end
            end
            -- Drop notifications as toast popups (D-05)
            if reward.drops then
              for _, d in ipairs(reward.drops) do
                if d.type == "hammer" then
                  popups.push({tier = "toast", title = "Hammer!", body = "+1 Hammer charge", rewards = {}})
                elseif d.type == "auto_sort" then
                  popups.push({tier = "toast", title = "Auto Sort!", body = "+1 Auto Sort charge", rewards = {}})
                elseif d.type == "bag_bundle" then
                  popups.push({tier = "toast", title = "+" .. (d.amount or 1) .. " Bags", body = "Bag Bundle!", rewards = {}})
                elseif d.type == "double_merge" then
                  popups.push({tier = "toast", title = "Double Merge!", body = "Next merge produces double coins", rewards = {}})
                elseif d.type == "star_burst" then
                  popups.push({tier = "toast", title = "+" .. (d.amount or 2) .. " Stars", body = "Star Burst!", rewards = {}})
                end
              end
            end
            advanceTutorial("complete_order", nil)
            local level_result = arena.checkLevelComplete()
            if level_result then
              -- Level up celebration popup (D-07: celebration tier)
              local reward_list = {}
              if level_result.bag_reward and level_result.bag_reward > 0 then
                table.insert(reward_list, {icon_type = "bag", amount = level_result.bag_reward})
              end
              if level_result.star_reward and level_result.star_reward > 0 then
                table.insert(reward_list, {icon_type = "star", amount = level_result.star_reward})
              end
              popups.push({
                tier = "celebration",
                title = "Level Up!",
                body = "Level " .. (level_result.new_level or "?"),
                rewards = reward_list,
              })
              -- Level drop toast
              if level_result.level_drop then
                local ld = level_result.level_drop
                if ld.type == "hammer" then
                  popups.push({tier = "toast", title = "Level Bonus: Hammer!", body = "+1 charge", rewards = {}})
                elseif ld.type == "auto_sort" then
                  popups.push({tier = "toast", title = "Level Bonus: Auto Sort!", body = "+1 charge", rewards = {}})
                elseif ld.type == "bag_bundle" then
                  popups.push({tier = "toast", title = "Level Bonus: +" .. (ld.amount or 1) .. " Bags", body = "Bag Bundle!", rewards = {}})
                end
              end
            end
          end
          return
        end
      end
    end
  end

  -- Dispenser tap-to-pop
  if isInDispenser(x, y) then
    local result = arena.popDispenserToGrid()
    if result then
      slot_tweens[result.index] = {time = 0, duration = TWEEN_DURATION}
      advanceTutorial("place_from_dispenser", result)
    end
    return
  end

  -- Grid interaction
  local cell_idx = gridCellAt(x, y)
  if cell_idx then
    local cell = arena.getCell(cell_idx)
    if cell and (not cell.state or cell.state == "chest") then
      -- Normal item, generator, or chest - start drag (chest only for tap detection)
      drag = {
        source = "grid",
        index = cell_idx,
        item = cell.state == "chest" and {state = "chest"} or {chain_id = cell.chain_id, level = cell.level},
        x = x, y = y,
        start_x = x, start_y = y,
      }
      return
    end
  end

  -- Stash drag
  local show_stash = step == "done" or (type(step) == "number" and step >= 15)
  if show_stash then
    local stash_slot = stashSlotAt(x, y)
    if stash_slot then
      local item = arena.getStashSlot(stash_slot)
      if item then
        drag = {
          source = "stash",
          index = stash_slot,
          item = {chain_id = item.chain_id, level = item.level},
          x = x, y = y,
          start_x = x, start_y = y,
        }
        return
      end
    end
  end

  -- Advance tutorial on misc taps
  advanceTutorial("any", nil)
end

function arena_screen.mousereleased(x, y, button)
  if button ~= 1 then return end
  if not drag then return end

  local moved_dist = math.abs(x - drag.start_x) + math.abs(y - drag.start_y)
  local was_tap = moved_dist < 20

  -- Chest tap (free, no fuel) — shake then pop (D-04)
  if was_tap and drag.source == "grid" and arena.isChestCell(drag.index) then
    if arena.countEmpty() == 0 then
      showNotification("No empty space!", {1, 0.5, 0.2})
    elseif not chest_shakes[drag.index] then
      local cell = arena.getCell(drag.index)
      chest_shakes[drag.index] = {time = 0, duration = 0.2, chain_id = cell and cell.chain_id or "Ch"}
    end
    drag = nil
    return
  end

  -- Generator tap
  if was_tap and drag.source == "grid" and arena.isGeneratorCell(drag.index) then
    local result = arena.tapGenerator(drag.index)
    if result then
      -- Start fly animation from generator to drop cell
      local sx, sy = cellScreenPos(drag.index)
      local dx, dy = cellScreenPos(result.drop_index)
      gen_fly = {
        src_x = sx, src_y = sy,
        dst_x = dx, dst_y = dy,
        item = {chain_id = result.drop_chain_id, level = result.drop_level},
        time = 0, duration = GEN_FLY_DURATION,
        dst_idx = result.drop_index,
      }
      -- Pop-in tween starts after fly completes (handled in update)
      advanceTutorial("tap_generator", result)
    else
      if arena.isGeneratorLocked(drag.index) then
        showNotification("Locked! Unlock in the Skill Tree", {0.6, 0.6, 0.7})
      elseif arena.isGeneratorDepleted(drag.index) then
        showNotification("Generator depleted! Wait or merge to recharge", {0.7, 0.7, 0.3})
      elseif resources.getFuel() < 1 then
        showNotification("Not enough fuel!", {1, 0.3, 0.3})
      elseif arena.countEmpty() == 0 then
        showNotification("No empty space!", {1, 0.5, 0.2})
      end
    end
    drag = nil
    return
  end

  -- Drop target: grid cell
  local target_cell = gridCellAt(x, y)
  if target_cell then
    if drag.source == "grid" then
      if target_cell == drag.index then
        -- Dropped on self, cancel
      elseif arena.canMerge(drag.index, target_cell) then
        -- Capture source item before merge clears it (for dissolve ghost D-03)
        local src_chain = drag.item.chain_id
        local src_level = drag.item.level
        local result = arena.executeMerge(drag.index, target_cell)
        if result then
          -- Source dissolves out (D-03: Arena items glow/dissolve, don't explode)
          dissolve_ghosts[drag.index] = {chain_id = src_chain, level = src_level}
          slot_tweens[drag.index] = {time = 0, duration = 0.25, style = "dissolve_out"}
          -- Result pops in with jelly
          slot_tweens[result.index] = {time = 0, duration = JELLY_DURATION, style = "jelly"}
          for _, rev_idx in ipairs(result.revealed) do
            slot_tweens[rev_idx] = {time = 0, duration = TWEEN_DURATION}
          end
          -- Chain-colored burst at merge point (subtle, 6 particles)
          local chain_color = arena_chains.getColor(result.chain_id or "Ch")
          local cx, cy = cellCenterPos(result.index)
          effects.spawnBurst(cx, cy, 6, chain_color)
          -- Only notify on first discovery of this item type
          local key = result.chain_id .. ":" .. result.level
          if not discovered_items[key] then
            discovered_items[key] = true
            local name = arena_chains.getItemName(result.chain_id, result.level) or "item"
            if result.is_generator then
              showNotification("New: " .. name .. "!", {0.3, 1.0, 0.5})
            else
              showNotification("New: " .. name .. "!", {0.3, 0.95, 0.3})
            end
          end
          -- Still notify locked generators (important info)
          if result.is_generator and result.is_locked then
            local name = arena_chains.getItemName(result.chain_id, result.level) or "item"
            showNotification(name .. " locked! Unlock in Skill Tree", {0.6, 0.6, 0.7})
          end
          advanceTutorial("merge", result)
        end
      elseif arena.isEmpty(target_cell) then
        arena.moveItem(drag.index, target_cell)
      else
        showNotification("Can't place here!", {1, 0.3, 0.3})
      end
    elseif drag.source == "stash" then
      if arena.isEmpty(target_cell) then
        arena.moveFromStash(drag.index, target_cell)
        slot_tweens[target_cell] = {time = 0, duration = TWEEN_DURATION}
      end
    end
    drag = nil
    return
  end

  -- Drop target: stash slot
  local step = arena.getTutorialStep()
  local show_stash = step == "done" or (type(step) == "number" and step >= 15)
  if show_stash then
    local target_stash = stashSlotAt(x, y)
    if target_stash then
      if drag.source == "grid" then
        if arena.moveToStash(drag.index, target_stash) then
          advanceTutorial("any", nil)
        end
      elseif drag.source == "stash" and target_stash ~= drag.index then
        arena.moveStashToStash(drag.index, target_stash)
      end
      drag = nil
      return
    end
  end

  -- Dropped on invalid area — cancel
  drag = nil
end

function arena_screen.touchmoved(id, x, y)
  if drag then
    drag.x = x
    drag.y = y
  end
end

function arena_screen.keypressed(key)
  if key == "\\" then
    love.event.quit()
  end
  if key == "escape" then
    screens.switch("coin_sort")
  end
end

return arena_screen
