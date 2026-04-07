-- tab_bar.lua
-- Bottom tab bar UI component for switching between Coin Sort and Arena screens.
-- Drawn by both coin_sort_screen and arena_screen.

local layout = require("layout")
local drops = require("drops")

local tab_bar = {}

local VW = layout.VW
local VH = layout.VH
local TAB_HEIGHT = 80
local TAB_Y = VH - TAB_HEIGHT

local font

local TABS = {
  { id = "coin_sort", label = "Coin Sort" },
  { id = "arena",     label = "Arena" },
  { id = "skill_tree", label = "Upgrades" },
}

-- Sliding highlight state (D-08)
local highlight_x = 0        -- current animated x position of highlight bar
local highlight_target = 0   -- target x for active tab
local highlight_initialized = false
local HIGHLIGHT_SPEED = 12   -- lerp speed (higher = snappier)

function tab_bar.init(assets)
  font = assets.font
end

-- Returns the Y position where tab bar starts (screens should not draw below this)
function tab_bar.getTopY()
  return TAB_Y
end

function tab_bar.getHeight()
  return TAB_HEIGHT
end

function tab_bar.draw(active_tab)
  local tab_w = VW / #TABS

  -- Background
  love.graphics.setColor(0.10, 0.14, 0.10, 0.95)
  love.graphics.rectangle("fill", 0, TAB_Y, VW, TAB_HEIGHT)

  -- Top border line
  love.graphics.setColor(0.25, 0.35, 0.22)
  love.graphics.setLineWidth(2)
  love.graphics.line(0, TAB_Y, VW, TAB_Y)
  love.graphics.setLineWidth(1)

  -- Sliding highlight bar (D-08)
  -- Calculate target position for active tab
  for i, tab in ipairs(TABS) do
    if tab.id == active_tab then
      highlight_target = (i - 1) * tab_w
    end
  end

  -- Initialize to target on first frame (no slide from 0,0)
  if not highlight_initialized then
    highlight_x = highlight_target
    highlight_initialized = true
  end

  -- Smooth lerp toward target
  local dt = love.timer.getDelta()
  highlight_x = highlight_x + (highlight_target - highlight_x) * math.min(1, HIGHLIGHT_SPEED * dt)

  -- Draw sliding indicator bar
  love.graphics.setColor(0.35, 0.75, 0.45)
  love.graphics.rectangle("fill", highlight_x + 20, TAB_Y, tab_w - 40, 3, 2, 2)

  love.graphics.setFont(font)

  for i, tab in ipairs(TABS) do
    local x = (i - 1) * tab_w
    local is_active = tab.id == active_tab

    if is_active then
      -- Active tab background highlight (static, subtle)
      love.graphics.setColor(0.20, 0.45, 0.25, 0.3)
      love.graphics.rectangle("fill", x, TAB_Y, tab_w, TAB_HEIGHT)

      -- Active text
      love.graphics.setColor(0.92, 0.88, 0.78)
    else
      -- Inactive text
      love.graphics.setColor(0.50, 0.55, 0.45)
    end

    love.graphics.printf(tab.label, x, TAB_Y + (TAB_HEIGHT - layout.FONT_SIZE) / 2, tab_w, "center")

    -- Badge: show pending rewards from the other mode
    if not is_active then
      local badge_count = 0
      if tab.id == "arena" then
        badge_count = drops.getPendingArenaCount()
      elseif tab.id == "coin_sort" then
        badge_count = drops.getPendingCSCount()
      end
      if badge_count > 0 then
        local badge_r = 18
        local bx = x + tab_w - 40
        local by = TAB_Y + 16
        love.graphics.setColor(0.85, 0.25, 0.2, 0.95)
        love.graphics.circle("fill", bx, by, badge_r)
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.printf(tostring(badge_count), bx - badge_r, by - badge_r / 2, badge_r * 2, "center")
      end
    end
  end
end

-- Hit test: returns tab id string if a tab was clicked, nil otherwise.
-- Does NOT switch screens — caller decides what to do.
function tab_bar.mousepressed(x, y)
  if y < TAB_Y or y > TAB_Y + TAB_HEIGHT then
    return nil
  end

  local tab_w = VW / #TABS
  for i, tab in ipairs(TABS) do
    local tx = (i - 1) * tab_w
    if x >= tx and x < tx + tab_w then
      return tab.id
    end
  end

  return nil
end

return tab_bar
