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
local GRID_TOP_Y = 150

-- Dispenser area
local DISPENSER_Y = 45
local DISPENSER_SLOT_SIZE = 90
local DISPENSER_X = math.floor(VW / 2 - DISPENSER_SLOT_SIZE / 2)

-- Stash area
local STASH_Y = GRID_TOP_Y + GRID_HEIGHT + 12
local STASH_SLOT_SIZE = 110
local STASH_GAP = 6
local STASH_COUNT = 8
local STASH_WIDTH = STASH_COUNT * STASH_SLOT_SIZE + (STASH_COUNT - 1) * STASH_GAP
local STASH_X = math.floor((VW - STASH_WIDTH) / 2)

-- Orders area
local ORDERS_Y = STASH_Y + STASH_SLOT_SIZE + 15
local ORDER_CARD_H = 230
local ORDER_CARD_GAP = 10

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
  return x >= DISPENSER_X and x < DISPENSER_X + DISPENSER_SLOT_SIZE
     and y >= DISPENSER_Y and y < DISPENSER_Y + DISPENSER_SLOT_SIZE
end

-- === DRAWING HELPERS ===

local function drawItemCircle(chain_id, level, cx, cy, radius, alpha)
  alpha = alpha or 1
  local c = arena_chains.getColor(chain_id)

  -- Shadow
  love.graphics.setColor(0, 0, 0, 0.3 * alpha)
  love.graphics.circle("fill", cx + 2, cy + 2, radius)

  -- Main circle
  love.graphics.setColor(c[1], c[2], c[3], alpha)
  love.graphics.circle("fill", cx, cy, radius)

  -- Highlight
  love.graphics.setColor(1, 1, 1, 0.2 * alpha)
  love.graphics.circle("fill", cx - radius * 0.2, cy - radius * 0.25, radius * 0.35)

  -- Level number
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

local function drawFuelBar()
  love.graphics.setFont(font)
  love.graphics.setColor(1, 0.8, 0.2, 0.9)
  love.graphics.printf("Fuel: " .. resources.getFuel() .. "/" .. resources.getFuelCap(), 10, 8, 250, "left")
  love.graphics.setColor(0.3, 0.7, 1.0)
  love.graphics.printf("Level " .. arena_orders.getCurrentLevel(), VW - 200, 8, 190, "right")
  love.graphics.setColor(0.6, 0.7, 0.6)
  local completed = arena_orders.getCompletedCount()
  local total = arena_orders.getLevelOrderCount()
  love.graphics.printf("Orders: " .. completed .. "/" .. total, VW / 2 - 100, 8, 200, "center")
end

local function drawDispenser()
  local step = arena.getTutorialStep()
  local show = true
  -- Always show dispenser

  -- Slot background
  love.graphics.setColor(0.12, 0.12, 0.2, 0.9)
  love.graphics.rectangle("fill", DISPENSER_X, DISPENSER_Y, DISPENSER_SLOT_SIZE, DISPENSER_SLOT_SIZE, 8, 8)
  love.graphics.setColor(0.3, 0.5, 0.7, 0.6)
  love.graphics.rectangle("line", DISPENSER_X, DISPENSER_Y, DISPENSER_SLOT_SIZE, DISPENSER_SLOT_SIZE, 8, 8)

  -- Item (tap to pop, no dragging)
  local item = arena.getDispenserItem()
  if item then
    drawCellItem(item.chain_id, item.level, DISPENSER_X, DISPENSER_Y, DISPENSER_SLOT_SIZE, false, 1)
  else
    love.graphics.setColor(0.3, 0.3, 0.4, 0.5)
    love.graphics.printf("--", DISPENSER_X, DISPENSER_Y + 30, DISPENSER_SLOT_SIZE, "center")
  end

  -- Queue count
  local qsize = arena.getDispenserSize()
  if qsize > 1 then
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.printf("+" .. (qsize - 1), DISPENSER_X + DISPENSER_SLOT_SIZE + 8, DISPENSER_Y + 30, 60, "left")
  end
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
    love.graphics.setColor(0.08, 0.08, 0.14, 0.85)
    love.graphics.rectangle("fill", x, y, CELL_SIZE, CELL_SIZE, 6, 6)
    love.graphics.setColor(0.18, 0.18, 0.26, 0.5)
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
        love.graphics.setColor(0.25, 0.2, 0.15, 0.9)
        love.graphics.rectangle("fill", draw_x + 4, draw_y + 4, draw_size - 8, draw_size - 8, 8, 8)
        love.graphics.setColor(0.5, 0.4, 0.25, 0.7)
        love.graphics.rectangle("line", draw_x + 4, draw_y + 4, draw_size - 8, draw_size - 8, 8, 8)
        love.graphics.setColor(0.6, 0.5, 0.3, 0.6)
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

  love.graphics.setColor(0.5, 0.5, 0.6, 0.5)
  love.graphics.printf("STASH", 0, STASH_Y - 20, VW, "center")

  for slot = 1, STASH_COUNT do
    local sx, sy = stashScreenPos(slot)
    -- Background
    love.graphics.setColor(0.08, 0.08, 0.14, 0.85)
    love.graphics.rectangle("fill", sx, sy, STASH_SLOT_SIZE, STASH_SLOT_SIZE, 6, 6)
    love.graphics.setColor(0.18, 0.18, 0.26, 0.5)
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

local function drawOrders()
  local step = arena.getTutorialStep()
  if step ~= "done" and type(step) == "number" and step < 13 then return end

  local visible = arena_orders.getVisibleOrders()
  if #visible == 0 then
    love.graphics.setColor(0.5, 0.8, 0.5)
    love.graphics.printf("All orders complete!", 0, ORDERS_Y + 20, VW, "center")
    return
  end

  local card_w = math.floor((VW - 30 - (#visible - 1) * ORDER_CARD_GAP) / #visible)

  for i, order in ipairs(visible) do
    local ox = 15 + (i - 1) * (card_w + ORDER_CARD_GAP)
    local oy = ORDERS_Y

    local can_complete = arena.canCompleteOrder(order.id)

    -- Card background
    if can_complete then
      love.graphics.setColor(0.08, 0.22, 0.08, 0.9)
    else
      love.graphics.setColor(0.08, 0.08, 0.13, 0.85)
    end
    love.graphics.rectangle("fill", ox, oy, card_w, ORDER_CARD_H, 8, 8)
    love.graphics.setColor(can_complete and {0.3, 0.8, 0.3, 0.7} or {0.2, 0.2, 0.3, 0.5})
    love.graphics.rectangle("line", ox, oy, card_w, ORDER_CARD_H, 8, 8)

    -- Character name
    love.graphics.setColor(0.7, 0.8, 0.9)
    love.graphics.printf(order.character, ox + 6, oy + 4, card_w - 12, "left")

    -- XP reward
    love.graphics.setColor(0.4, 0.7, 1.0)
    love.graphics.printf("+" .. order.xp_reward .. " XP", ox + 6, oy + 4, card_w - 12, "right")

    -- Requirements
    local req_y = oy + 30
    for _, req in ipairs(order.requirements) do
      local c = arena_chains.getColor(req.chain_id)
      local name = arena_chains.getItemName(req.chain_id, req.level) or "?"

      -- Count on board
      local on_board = 0
      local grid_data = arena.getGrid()
      for gi = 1, arena.getGridSize() do
        local cell = grid_data[gi]
        if cell and not cell.state and cell.chain_id == req.chain_id and cell.level == req.level then
          on_board = on_board + 1
        end
      end
      local have_enough = on_board >= req.count

      -- Colored dot
      love.graphics.setColor(c[1], c[2], c[3])
      love.graphics.circle("fill", ox + 16, req_y + 12, 6)

      -- Text
      if have_enough then
        love.graphics.setColor(0.3, 0.95, 0.3)
      else
        love.graphics.setColor(0.85, 0.85, 0.85)
      end
      local label = name
      if req.count > 1 then label = req.count .. "x " .. name end
      love.graphics.printf(label .. " " .. on_board .. "/" .. req.count,
        ox + 28, req_y + 2, card_w - 40, "left")
      req_y = req_y + 28
    end

    -- Item rewards preview
    if order.item_rewards and #order.item_rewards > 0 then
      req_y = req_y + 4
      love.graphics.setColor(0.6, 0.6, 0.5, 0.6)
      love.graphics.printf("Rewards:", ox + 6, req_y, card_w - 12, "left")
      req_y = req_y + 20
      local reward_text = {}
      for _, rw in ipairs(order.item_rewards) do
        local rname = arena_chains.getItemName(rw.chain_id, rw.level) or "?"
        reward_text[#reward_text + 1] = rname
      end
      love.graphics.setColor(0.7, 0.7, 0.5, 0.7)
      love.graphics.printf(table.concat(reward_text, ", "), ox + 6, req_y, card_w - 12, "left")
    end

    -- Complete button
    if can_complete then
      local btn_y = oy + ORDER_CARD_H - 44
      local btn_w = card_w - 16
      love.graphics.setColor(0.15, 0.55, 0.2)
      love.graphics.rectangle("fill", ox + 8, btn_y, btn_w, 36, 6, 6)
      love.graphics.setColor(1, 1, 1)
      love.graphics.printf("COMPLETE", ox + 8, btn_y + 6, btn_w, "center")
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
    -- Draw tooltip above dispenser
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 40, DISPENSER_Y + DISPENSER_SLOT_SIZE + 4, VW - 80, 32, 6, 6)
    love.graphics.setColor(1, 1, 0.7)
    love.graphics.printf(tooltip, 0, DISPENSER_Y + DISPENSER_SLOT_SIZE + 10, VW, "center")
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
  love.graphics.setColor(0.06, 0.06, 0.1)
  love.graphics.rectangle("fill", 0, 0, VW, VH)

  drawFuelBar()
  drawDispenser()
  drawGrid()
  drawStash()
  drawOrders()
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

  -- Order complete buttons
  local step = arena.getTutorialStep()
  local show_orders = step == "done" or (type(step) == "number" and step >= 13)
  if show_orders then
    local visible = arena_orders.getVisibleOrders()
    local card_w = math.floor((VW - 30 - (#visible - 1) * ORDER_CARD_GAP) / math.max(1, #visible))
    for i, order in ipairs(visible) do
      if arena.canCompleteOrder(order.id) then
        local ox = 15 + (i - 1) * (card_w + ORDER_CARD_GAP)
        local btn_y = ORDERS_Y + ORDER_CARD_H - 44
        local btn_w = card_w - 16
        if x >= ox + 8 and x <= ox + 8 + btn_w and y >= btn_y and y <= btn_y + 36 then
          local reward = arena.completeOrder(order.id)
          if reward then
            showNotification("Order complete! +" .. (reward.xp_reward or 0) .. " XP", {0.3, 0.95, 0.3})
            advanceTutorial("complete_order", nil)
            -- Check level completion
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
    screens.switch("game_2048")
  end
end

return arena_screen
