-- skill_tree_screen.lua
-- Full-screen PoE-style skill tree with pannable view and node interaction.
-- Only visible nodes (unlocked or adjacent to unlocked) are rendered.

local screens = require("screens")
local layout = require("layout")
local resources = require("resources")
local skill_tree = require("skill_tree")
local tab_bar = require("tab_bar")

local skill_tree_screen = {}

local VW, VH = layout.VW, layout.VH
local font, font_small

-- Camera state
local cam_x, cam_y = 0, 0       -- camera offset (world coords centered on screen)
local dragging = false
local drag_start_x, drag_start_y = 0, 0
local drag_cam_start_x, drag_cam_start_y = 0, 0
local drag_distance = 0          -- total pixels dragged (to distinguish tap from pan)

-- Node rendering
local NODE_SPACING = 160         -- pixels per grid unit
local NODE_RADIUS = {
  start = 45,
  small = 32,
  notable = 38,
  keystone = 44,
}

-- Colors by node type
local NODE_COLORS = {
  start    = {0.9, 0.8, 0.2},    -- gold
  small    = {0.5, 0.6, 0.7},    -- steel blue
  notable  = {0.3, 0.6, 0.9},    -- bright blue
  keystone = {0.9, 0.7, 0.1},    -- deep gold
}
local LOCKED_COLOR = {0.25, 0.25, 0.3, 0.6}
local AVAILABLE_COLOR = {0.4, 0.9, 0.4}
local CONNECTION_UNLOCKED = {0.5, 0.7, 0.3, 0.8}
local CONNECTION_LOCKED = {0.3, 0.3, 0.35, 0.4}

-- Selected node state
local selected_node_id = nil
local detail_panel_y = VH        -- slides up from bottom
local DETAIL_PANEL_HEIGHT = 320
local DETAIL_PANEL_TARGET = VH - DETAIL_PANEL_HEIGHT

-- Notification for newly unlocked node
local unlock_notification = nil
local unlock_notif_timer = 0

-- Pulse animation
local pulse_timer = 0

function skill_tree_screen.init(assets)
  font = assets.font
  font_small = assets.font_small or assets.font
end

function skill_tree_screen.enter()
  -- Center camera on start node
  cam_x = 0
  cam_y = 0
  selected_node_id = nil
  detail_panel_y = VH
  dragging = false
  pulse_timer = 0
end

function skill_tree_screen.exit()
  selected_node_id = nil
end

function skill_tree_screen.update(dt)
  pulse_timer = pulse_timer + dt

  -- Animate detail panel
  if selected_node_id then
    detail_panel_y = detail_panel_y + (DETAIL_PANEL_TARGET - detail_panel_y) * math.min(1, dt * 12)
  else
    detail_panel_y = detail_panel_y + (VH - detail_panel_y) * math.min(1, dt * 12)
  end

  -- Unlock notification timer
  if unlock_notification then
    unlock_notif_timer = unlock_notif_timer - dt
    if unlock_notif_timer <= 0 then
      unlock_notification = nil
    end
  end
end

-- Convert world coordinates to screen coordinates
local function worldToScreen(wx, wy)
  local sx = VW / 2 + (wx - cam_x) * NODE_SPACING
  local sy = VH / 2 + (wy - cam_y) * NODE_SPACING
  return sx, sy
end

-- Find which visible node was tapped (if any)
local function hitTestNode(sx, sy)
  local nodes = skill_tree.getNodes()
  local best_id = nil
  local best_dist = math.huge

  for id, node in pairs(nodes) do
    if skill_tree.isVisible(id) then
      local nx, ny = worldToScreen(node.x, node.y)
      local r = NODE_RADIUS[node.type] or 32
      local dx = sx - nx
      local dy = sy - ny
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist < r + 10 and dist < best_dist then
        best_dist = dist
        best_id = id
      end
    end
  end

  return best_id
end

local function drawConnection(n1, n2, both_unlocked)
  local x1, y1 = worldToScreen(n1.x, n1.y)
  local x2, y2 = worldToScreen(n2.x, n2.y)

  if both_unlocked then
    love.graphics.setColor(CONNECTION_UNLOCKED)
    love.graphics.setLineWidth(4)
  else
    love.graphics.setColor(CONNECTION_LOCKED)
    love.graphics.setLineWidth(2)
  end

  love.graphics.line(x1, y1, x2, y2)
end

local function drawNode(id, node)
  local sx, sy = worldToScreen(node.x, node.y)
  local r = NODE_RADIUS[node.type] or 32
  local is_unlocked = skill_tree.isUnlocked(id)
  local can_unlock = skill_tree.canUnlock(id)
  local base_color = NODE_COLORS[node.type] or NODE_COLORS.small

  -- Skip drawing if off screen (with margin)
  if sx < -100 or sx > VW + 100 or sy < -100 or sy > VH + 100 then
    return
  end

  if is_unlocked then
    -- Bright filled circle
    love.graphics.setColor(base_color[1], base_color[2], base_color[3], 1.0)
    love.graphics.circle("fill", sx, sy, r)
    -- Bright border
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", sx, sy, r)
  elseif can_unlock then
    -- Available: pulsing border
    local pulse = 0.5 + 0.5 * math.sin(pulse_timer * 3)
    love.graphics.setColor(base_color[1] * 0.4, base_color[2] * 0.4, base_color[3] * 0.4, 0.7)
    love.graphics.circle("fill", sx, sy, r)
    love.graphics.setColor(AVAILABLE_COLOR[1], AVAILABLE_COLOR[2], AVAILABLE_COLOR[3], 0.5 + pulse * 0.5)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", sx, sy, r + 2)
  elseif node.coming_soon then
    -- Coming soon: special styling
    love.graphics.setColor(0.3, 0.15, 0.3, 0.5)
    love.graphics.circle("fill", sx, sy, r)
    love.graphics.setColor(0.6, 0.3, 0.6, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", sx, sy, r)
  else
    -- Visible but locked (adjacent to unlocked)
    love.graphics.setColor(LOCKED_COLOR)
    love.graphics.circle("fill", sx, sy, r)
    love.graphics.setColor(0.4, 0.4, 0.45, 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", sx, sy, r)
  end

  -- Selected highlight
  if id == selected_node_id then
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.setLineWidth(4)
    love.graphics.circle("line", sx, sy, r + 5)
  end

  -- Node cost label (inside node for locked nodes)
  if not is_unlocked and not node.coming_soon then
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setFont(font_small or font)
    love.graphics.printf(node.cost .. "", sx - r, sy - 8, r * 2, "center")
  elseif is_unlocked then
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setFont(font_small or font)
    love.graphics.printf("*", sx - r, sy - 10, r * 2, "center")
  end

  -- Node name (below node for unlocked/available)
  if is_unlocked or can_unlock then
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.setFont(font_small or font)
    local name = node.name
    if #name > 12 then name = name:sub(1, 11) .. "." end
    love.graphics.printf(name, sx - 70, sy + r + 4, 140, "center")
  end
end

local function drawDetailPanel()
  if detail_panel_y >= VH - 5 then return end

  local node = skill_tree.getNode(selected_node_id)
  if not node then return end

  local py = detail_panel_y

  -- Background
  love.graphics.setColor(0.1, 0.12, 0.15, 0.95)
  love.graphics.rectangle("fill", 0, py, VW, DETAIL_PANEL_HEIGHT + 40, 20, 20)

  -- Top border
  local base_color = NODE_COLORS[node.type] or NODE_COLORS.small
  love.graphics.setColor(base_color[1], base_color[2], base_color[3], 0.8)
  love.graphics.setLineWidth(3)
  love.graphics.line(40, py + 2, VW - 40, py + 2)

  -- Type label
  love.graphics.setFont(font_small or font)
  love.graphics.setColor(base_color[1], base_color[2], base_color[3], 0.7)
  local type_label = node.type:upper()
  if node.coming_soon then type_label = "COMING SOON" end
  love.graphics.printf(type_label, 40, py + 12, VW - 80, "left")

  -- Name
  love.graphics.setFont(font)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.printf(node.name, 40, py + 40, VW - 80, "left")

  -- Description
  love.graphics.setFont(font_small or font)
  love.graphics.setColor(0.8, 0.8, 0.8, 0.9)
  love.graphics.printf(node.desc, 40, py + 85, VW - 80, "left")

  -- Cost / Status
  local is_unlocked = skill_tree.isUnlocked(selected_node_id)
  local can_unlock = skill_tree.canUnlock(selected_node_id)

  if is_unlocked then
    love.graphics.setColor(0.3, 0.9, 0.3, 0.9)
    love.graphics.setFont(font)
    love.graphics.printf("UNLOCKED", 40, py + 150, VW - 80, "center")
  elseif node.coming_soon then
    love.graphics.setColor(0.6, 0.3, 0.6, 0.8)
    love.graphics.setFont(font)
    love.graphics.printf("Coming Soon", 40, py + 150, VW - 80, "center")
  else
    -- Show cost
    local stars = resources.getStars()
    local affordable = stars >= node.cost

    love.graphics.setColor(1, 0.9, 0.2, 1)
    love.graphics.setFont(font)
    love.graphics.printf(node.cost .. " Stars", 40, py + 140, VW - 80, "center")

    love.graphics.setFont(font_small or font)
    love.graphics.setColor(0.7, 0.7, 0.7, 0.8)
    love.graphics.printf("You have: " .. stars .. " Stars", 40, py + 180, VW - 80, "center")

    if can_unlock then
      local btn_w, btn_h = 300, 70
      local btn_x = (VW - btn_w) / 2
      local btn_y = py + 220

      local pulse = 0.8 + 0.2 * math.sin(pulse_timer * 4)
      love.graphics.setColor(0.2 * pulse, 0.7 * pulse, 0.3 * pulse, 1)
      love.graphics.rectangle("fill", btn_x, btn_y, btn_w, btn_h, 12, 12)
      love.graphics.setColor(0.3, 1, 0.4, 0.8)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", btn_x, btn_y, btn_w, btn_h, 12, 12)

      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.setFont(font)
      love.graphics.printf("UNLOCK", btn_x, btn_y + 15, btn_w, "center")
    elseif not affordable then
      love.graphics.setColor(0.7, 0.3, 0.3, 0.7)
      love.graphics.setFont(font_small or font)
      love.graphics.printf("Not enough Stars", 40, py + 220, VW - 80, "center")
    else
      love.graphics.setColor(0.6, 0.6, 0.3, 0.7)
      love.graphics.setFont(font_small or font)
      love.graphics.printf("Unlock adjacent nodes first", 40, py + 220, VW - 80, "center")
    end
  end
end

function skill_tree_screen.draw()
  -- Background
  love.graphics.setColor(0.08, 0.08, 0.12, 1)
  love.graphics.rectangle("fill", 0, 0, VW, VH)

  -- Subtle grid dots
  love.graphics.setColor(0.12, 0.12, 0.18, 0.5)
  for gx = -5, 5 do
    for gy = -10, 2 do
      local sx, sy = worldToScreen(gx, gy)
      if sx > -10 and sx < VW + 10 and sy > -10 and sy < VH + 10 then
        love.graphics.circle("fill", sx, sy, 2)
      end
    end
  end

  local nodes = skill_tree.getNodes()
  local unlocked_set = skill_tree.getUnlocked()

  -- Draw connections (only between visible nodes)
  local drawn_connections = {}
  for id, node in pairs(nodes) do
    if skill_tree.isVisible(id) then
      for _, conn_id in ipairs(node.connections) do
        if skill_tree.isVisible(conn_id) then
          local key = id < conn_id and (id .. "-" .. conn_id) or (conn_id .. "-" .. id)
          if not drawn_connections[key] and nodes[conn_id] then
            drawn_connections[key] = true
            local both_unlocked = unlocked_set[id] and unlocked_set[conn_id]
            drawConnection(node, nodes[conn_id], both_unlocked)
          end
        end
      end
    end
  end

  -- Draw visible nodes
  love.graphics.setLineWidth(1)
  for id, node in pairs(nodes) do
    if skill_tree.isVisible(id) then
      drawNode(id, node)
    end
  end

  -- === TOP BAR ===
  love.graphics.setColor(0.06, 0.06, 0.1, 0.9)
  love.graphics.rectangle("fill", 0, 0, VW, 80)

  -- Title
  love.graphics.setFont(font)
  love.graphics.setColor(0.9, 0.8, 0.2, 1)
  love.graphics.printf("UPGRADES", 20, 22, 300, "left")

  -- Stars count
  love.graphics.setColor(1, 0.9, 0.2, 1)
  local stars_text = resources.getStars() .. " Stars"
  love.graphics.printf(stars_text, VW - 300, 22, 280, "right")

  -- === TAB BAR ===
  tab_bar.draw("skill_tree")

  -- Detail panel
  drawDetailPanel()

  -- Unlock notification
  if unlock_notification then
    local alpha = math.min(1, unlock_notif_timer)
    love.graphics.setColor(0.1, 0.15, 0.1, 0.9 * alpha)
    love.graphics.rectangle("fill", 40, 120, VW - 80, 80, 12, 12)
    love.graphics.setColor(0.3, 1.0, 0.4, alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 40, 120, VW - 80, 80, 12, 12)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.setFont(font)
    love.graphics.printf("Unlocked: " .. unlock_notification, 60, 140, VW - 120, "center")
  end
end

function skill_tree_screen.mousepressed(x, y, button)
  if button ~= 1 then return end

  -- Check detail panel unlock button
  if selected_node_id and detail_panel_y < VH - 10 then
    local node = skill_tree.getNode(selected_node_id)
    if node and skill_tree.canUnlock(selected_node_id) then
      local btn_w, btn_h = 300, 70
      local btn_x = (VW - btn_w) / 2
      local btn_y = detail_panel_y + 220
      if x >= btn_x and x <= btn_x + btn_w and y >= btn_y and y <= btn_y + btn_h then
        if skill_tree.unlock(selected_node_id) then
          unlock_notification = node.name
          unlock_notif_timer = 2.5
        end
        return
      end
    end

    -- Tap outside panel dismisses it
    if y < detail_panel_y then
      -- Start dragging instead
    else
      return
    end
  end

  -- Tab bar
  local tab = tab_bar.mousepressed(x, y)
  if tab and tab ~= "skill_tree" then
    screens.switch(tab)
    return
  end

  -- Start drag
  dragging = true
  drag_start_x = x
  drag_start_y = y
  drag_cam_start_x = cam_x
  drag_cam_start_y = cam_y
  drag_distance = 0
end

function skill_tree_screen.mousereleased(x, y, button)
  if button ~= 1 then return end

  local was_dragging = dragging
  dragging = false

  -- If we didn't drag far, treat as a tap
  if was_dragging and drag_distance < 15 then
    local node_id = hitTestNode(x, y)
    if node_id then
      if selected_node_id == node_id then
        selected_node_id = nil
      else
        selected_node_id = node_id
      end
    else
      selected_node_id = nil
    end
  end
end

function skill_tree_screen.keypressed(key)
  if key == "escape" then
    if selected_node_id then
      selected_node_id = nil
    else
      screens.switch("coin_sort")
    end
  end
end

function skill_tree_screen.mousemoved(x, y)
  if not dragging then return end

  local dx = x - drag_start_x
  local dy = y - drag_start_y
  drag_distance = math.sqrt(dx * dx + dy * dy)

  cam_x = drag_cam_start_x - dx / NODE_SPACING
  cam_y = drag_cam_start_y - dy / NODE_SPACING
end

return skill_tree_screen
