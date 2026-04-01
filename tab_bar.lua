-- tab_bar.lua
-- Bottom tab bar UI component for switching between Coin Sort and Arena screens.
-- Drawn by both coin_sort_screen and arena_screen.

local layout = require("layout")

local tab_bar = {}

local VW = layout.VW
local VH = layout.VH
local TAB_HEIGHT = 80
local TAB_Y = VH - TAB_HEIGHT

local font

local TABS = {
  { id = "coin_sort", label = "Coin Sort" },
  { id = "arena",     label = "Arena" },
}

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
  love.graphics.setColor(0.08, 0.08, 0.12, 0.95)
  love.graphics.rectangle("fill", 0, TAB_Y, VW, TAB_HEIGHT)

  -- Top border line
  love.graphics.setColor(0.25, 0.25, 0.3)
  love.graphics.setLineWidth(2)
  love.graphics.line(0, TAB_Y, VW, TAB_Y)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(font)

  for i, tab in ipairs(TABS) do
    local x = (i - 1) * tab_w
    local is_active = tab.id == active_tab

    if is_active then
      -- Active tab highlight
      love.graphics.setColor(0.2, 0.5, 0.8, 0.3)
      love.graphics.rectangle("fill", x, TAB_Y, tab_w, TAB_HEIGHT)

      -- Active indicator bar
      love.graphics.setColor(0.3, 0.7, 1.0)
      love.graphics.rectangle("fill", x + 20, TAB_Y, tab_w - 40, 3, 2, 2)

      -- Active text
      love.graphics.setColor(1, 1, 1)
    else
      -- Inactive text
      love.graphics.setColor(0.5, 0.5, 0.55)
    end

    love.graphics.printf(tab.label, x, TAB_Y + (TAB_HEIGHT - layout.FONT_SIZE) / 2, tab_w, "center")
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
