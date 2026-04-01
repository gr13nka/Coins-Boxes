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
local STASH_COUNT = 8
local STASH_WIDTH = STASH_COUNT * STASH_SLOT_SIZE + (STASH_COUNT - 1) * STASH_GAP
local STASH_X = math.floor((VW - STASH_WIDTH) / 2)

-- Drag state
local drag = nil  -- {source, index, item, x, y, start_x, start_y}

-- Tween animation for newly placed/revealed items
local slot_tweens = {}  -- {[index] = {time, duration}}
local TWEEN_DURATION = 0.3

-- Notification
local notification = {text = "", timer = 0, color = {1, 1, 1}}

local function showNotification(text, color)
  notification.text = text
  notification.timer = 2.0
  notification.color = color or {1, 1, 1}
end

-- === COORDINATE HELPERS ===

local function cellScreenPos(index)
  local col, row = arena.toColRow(index)
  if not col then return 0, 0 end
  local x = GRID_X + (col - 1) * (CELL_SIZE + CELL_GAP)
  local y = GRID_TOP_Y + (row - 1) * (CELL_SIZE + CELL_GAP)
  return x, y
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
  if x < STASH_X then return nil end
  local slot = math.floor((x - STASH_X) / (STASH_SLOT_SIZE + STASH_GAP)) + 1
  if slot < 1 or slot > STASH_COUNT then return nil end
  local sx = STASH_X + (slot - 1) * (STASH_SLOT_SIZE + STASH_GAP)
  if x >= sx and x < sx + STASH_SLOT_SIZE then return slot end
  return nil
end

local function stashScreenPos(slot)
  local x = STASH_X + (slot - 1) * (STASH_SLOT_SIZE + STASH_GAP)
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

-- Draw the geometric shape for a given chain
local function drawShape(shape, cx, cy, r, mode)
  mode = mode or "fill"
  local hp = -math.pi / 2  -- half-pi, points first vertex upward
  if shape == "circle" then
    love.graphics.circle(mode, cx, cy, r)
  elseif shape == "hexagon" then
    love.graphics.polygon(mode, makeNGon(cx, cy, r, 6, hp))
  elseif shape == "square" then
    love.graphics.polygon(mode, makeNGon(cx, cy, r, 4, -math.pi * 0.75))
  elseif shape == "diamond" then
    love.graphics.polygon(mode, makeNGon(cx, cy, r, 4, hp))
  elseif shape == "triangle_up" then
    love.graphics.polygon(mode, makeNGon(cx, cy, r, 3, hp))
  elseif shape == "triangle_down" then
    love.graphics.polygon(mode, makeNGon(cx, cy, r, 3, math.pi / 2))
  elseif shape == "pentagon" then
    love.graphics.polygon(mode, makeNGon(cx, cy, r, 5, hp))
  elseif shape == "heptagon" then
    love.graphics.polygon(mode, makeNGon(cx, cy, r, 7, hp))
  elseif shape == "octagon" then
    love.graphics.polygon(mode, makeNGon(cx, cy, r, 8, hp))
  elseif shape == "star_5" then
    love.graphics.polygon(mode, makeStar(cx, cy, r, r * 0.42, 5, hp))
  elseif shape == "star_6" then
    love.graphics.polygon(mode, makeStar(cx, cy, r, r * 0.48, 6, hp))
  elseif shape == "star_4" then
    love.graphics.polygon(mode, makeStar(cx, cy, r, r * 0.38, 4, hp))
  else
    love.graphics.circle(mode, cx, cy, r)
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

-- Draw the three resources (Fuel, Metal, Components) as a horizontal pill row
local function drawResources()
  love.graphics.setFont(font)
  local pill_w = 300
  local pill_h = 56
  local gap = 30
  local total_w = 3 * pill_w + 2 * gap
  local start_x = math.floor((VW - total_w) / 2)
  local py = math.floor((RESOURCES_H - pill_h) / 2)

  local entries = {
    {label = "Fuel",       value = resources.getFuel() .. "/" .. resources.getFuelCap(), color = {1, 0.75, 0.15}},
    {label = "Metal",      value = tostring(resources.getMetal()),                       color = {0.55, 0.75, 0.9}},
    {label = "Components", value = tostring(resources.getComponents()),                  color = {0.4, 0.9, 0.55}},
  }

  for i, entry in ipairs(entries) do
    local px = start_x + (i - 1) * (pill_w + gap)
    -- Pill background
    love.graphics.setColor(0.12, 0.16, 0.11, 0.9)
    love.graphics.rectangle("fill", px, py, pill_w, pill_h, 10, 10)
    love.graphics.setColor(entry.color[1], entry.color[2], entry.color[3], 0.5)
    love.graphics.rectangle("line", px, py, pill_w, pill_h, 10, 10)
    -- Label
    love.graphics.setColor(entry.color[1], entry.color[2], entry.color[3], 0.8)
    love.graphics.printf(entry.label, px + 8, py + 6, pill_w / 2 - 8, "left")
    -- Value
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(entry.value, px + pill_w / 2, py + 6, pill_w / 2 - 8, "right")
  end

  -- Level info (top-right corner)
  love.graphics.setColor(0.45, 0.75, 0.50, 0.8)
  love.graphics.printf("Lv " .. arena_orders.getCurrentLevel(), VW - 110, 8, 100, "right")
end

-- Draw the dispenser as a circle on the left side of the header row
local function drawDispenser()
  local cx = DISP_X + DISP_SIZE / 2
  local cy = DISP_Y + DISP_SIZE / 2
  local r = DISP_SIZE / 2

  -- Outer ring
  love.graphics.setColor(0.18, 0.30, 0.20, 0.9)
  love.graphics.circle("fill", cx, cy, r)
  love.graphics.setColor(0.30, 0.50, 0.30, 0.7)
  love.graphics.setLineWidth(3)
  love.graphics.circle("line", cx, cy, r)
  love.graphics.setLineWidth(1)

  -- Item inside circle
  local item = arena.getDispenserItem()
  if item then
    -- Draw item centered in circle
    local item_size = DISP_SIZE * 0.72
    local ix = cx - item_size / 2
    local iy = cy - item_size / 2
    drawCellItem(item.chain_id, item.level, ix, iy, item_size, false, 1)
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

    -- Skip if being dragged
    if drag and drag.source == "grid" and drag.index == i then
      -- Don't draw, it's being dragged
    elseif cell then
      -- Apply pop-in tween
      local tw = slot_tweens[i]
      local draw_x, draw_y, draw_size = x, y, CELL_SIZE
      if tw then
        local t = tw.time / tw.duration
        local scale = t < 0.6 and (t / 0.6 * 1.15) or (1.15 - (t - 0.6) / 0.4 * 0.15)
        draw_size = CELL_SIZE * scale
        draw_x = x + (CELL_SIZE - draw_size) / 2
        draw_y = y + (CELL_SIZE - draw_size) / 2
      end

      if cell.state == "box" then
        -- Closed box
        love.graphics.setColor(0.22, 0.28, 0.18, 0.9)
        love.graphics.rectangle("fill", draw_x + 4, draw_y + 4, draw_size - 8, draw_size - 8, 8, 8)
        love.graphics.setColor(0.35, 0.45, 0.28, 0.7)
        love.graphics.rectangle("line", draw_x + 4, draw_y + 4, draw_size - 8, draw_size - 8, 8, 8)
        love.graphics.setColor(0.42, 0.55, 0.32, 0.6)
        love.graphics.printf("?", draw_x, draw_y + draw_size / 2 - 14, draw_size, "center")
      elseif cell.state == "sealed" then
        drawCellItem(cell.chain_id, cell.level, draw_x, draw_y, draw_size, true, 1)
      else
        -- Normal item (or generator)
        drawCellItem(cell.chain_id, cell.level, draw_x, draw_y, draw_size, false, 1)
        -- Green border if needed for an order
        if highlighted[i] then
          love.graphics.setColor(0.2, 0.9, 0.2, 0.35)
          love.graphics.setLineWidth(3)
          love.graphics.rectangle("line", draw_x + 2, draw_y + 2, draw_size - 4, draw_size - 4, 6, 6)
          love.graphics.setLineWidth(1)
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

  for slot = 1, STASH_COUNT do
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
  elseif step == 6 then
    -- Prompt: drag Ch3 onto sealed Ch3
    if event == "merge" and data and data.chain_id == "Ch" and data.level == 4 and data.was_sealed then
      arena.setTutorialStep(8)
    end
  elseif step == 7 then
    -- Same as 6 (waiting for unseal)
    if event == "merge" and data and data.chain_id == "Ch" and data.level == 4 and data.was_sealed then
      arena.setTutorialStep(8)
    end
  elseif step == 8 then
    -- Prompt: tap generator
    if event == "tap_generator" then
      arena.pushDispenser("Da", 1)
      arena.setTutorialStep(10)
    end
  elseif step == 9 then
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
  elseif step == 13 then
    if event == "complete_order" then
      arena.setTutorialStep(15)
    end
  elseif step == 14 then
    if event == "complete_order" then
      arena.setTutorialStep(15)
    end
  elseif step == 15 then
    -- Show stash, advance after any action
    if event == "any" then
      arena.setTutorialStep(16)
    end
  elseif step == 16 then
    if event == "tap_generator" then
      arena.setTutorialStep("done")
    end
  elseif step == 17 then
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

  if notification.timer > 0 then
    notification.timer = notification.timer - dt
  end

  -- Update slot tweens
  for slot, tw in pairs(slot_tweens) do
    tw.time = tw.time + dt
    if tw.time >= tw.duration then
      slot_tweens[slot] = nil
    end
  end

  -- Update drag position from mouse (desktop)
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
  drawStash()
  drawDragged()
  drawTutorial()

  -- Notification
  if notification.timer > 0 then
    local alpha = math.min(notification.timer, 1)
    love.graphics.setColor(0, 0, 0, alpha * 0.6)
    love.graphics.rectangle("fill", 40, GRID_TOP_Y - 35, VW - 80, 30, 6, 6)
    love.graphics.setColor(notification.color[1], notification.color[2], notification.color[3], alpha)
    love.graphics.printf(notification.text, 0, GRID_TOP_Y - 32, VW, "center")
  end

  -- Tab bar
  tab_bar.draw("arena")
end

function arena_screen.mousepressed(x, y, button)
  if button ~= 1 then return end

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
            showNotification("Order complete! +" .. (reward.xp_reward or 0) .. " XP", {0.3, 0.95, 0.3})
            advanceTutorial("complete_order", nil)
            local level_result = arena.checkLevelComplete()
            if level_result then
              showNotification("Level " .. level_result.new_level .. " unlocked!", {0.4, 0.8, 1.0})
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
    if cell and not cell.state then
      -- Normal item or generator - start drag
      drag = {
        source = "grid",
        index = cell_idx,
        item = {chain_id = cell.chain_id, level = cell.level},
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

  -- Generator tap
  if was_tap and drag.source == "grid" and arena.isGeneratorCell(drag.index) then
    local result = arena.tapGenerator(drag.index)
    if result then
      slot_tweens[result.drop_index] = {time = 0, duration = TWEEN_DURATION}
      showNotification("Produced " .. (arena_chains.getItemName(result.drop_chain_id, result.drop_level) or "item") .. "!", {0.3, 0.8, 1.0})
      advanceTutorial("tap_generator", result)
    else
      if resources.getFuel() < 1 then
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
        local result = arena.executeMerge(drag.index, target_cell)
        if result then
          slot_tweens[result.index] = {time = 0, duration = TWEEN_DURATION}
          for _, rev_idx in ipairs(result.revealed) do
            slot_tweens[rev_idx] = {time = 0, duration = TWEEN_DURATION}
          end
          local name = arena_chains.getItemName(result.chain_id, result.level) or "item"
          if result.is_generator then
            showNotification("Created " .. name .. "!", {0.3, 1.0, 0.5})
          elseif result.was_sealed then
            showNotification("Unsealed! " .. name, {0.3, 0.95, 0.3})
          else
            showNotification("Merged: " .. name, {0.3, 0.95, 0.3})
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
