-- input.lua
-- Input handling: hit testing, coordinate conversion

local layout = require("layout")

local input = {}

-- Layout constants
local VW, VH = layout.VW, layout.VH

--- Refresh cached layout values (call after layout changes)
function input.updateMetrics()
  -- No-op: we read layout globals directly now
end

--- Determine which box was clicked (for 2048 mode, 3×5 grid)
-- @param x Click x coordinate (game space)
-- @param y Click y coordinate (game space)
-- @param boxes Sparse table of boxes indexed by grid position (1-15); nil = locked
-- @param top_y Unused (kept for API compat)
-- @return Grid position (1-15) or nil if outside grid or on a locked box
function input.boxAt2048(x, y, boxes, top_y)
  -- Iterate all 15 grid slots; skip locked (nil) ones
  for i = 1, 15 do
    if boxes[i] then
      local bx, by = layout.boxPosition(i)
      if x >= bx and x < bx + layout.BOX_W and y >= by and y < by + layout.BOX_H then
        return i
      end
    end
  end
  return nil
end

--- Determine which box was clicked (classic mode, kept for compat)
function input.boxAt(x, y, boxes, top_y)
  return input.boxAt2048(x, y, boxes, top_y)
end

--- Check if point is inside a rectangular button
-- @param x Point x coordinate
-- @param y Point y coordinate
-- @param btnX Button left edge
-- @param btnY Button top edge
-- @param btnW Button width
-- @param btnH Button height
-- @return true if inside button
function input.isInsideButton(x, y, btnX, btnY, btnW, btnH)
  return x >= btnX and x <= btnX + btnW and
         y >= btnY and y <= btnY + btnH
end

--- Check if click is on SFX toggle button
-- @param x Click x coordinate (game space)
-- @param y Click y coordinate (game space)
-- @return true if on SFX toggle
function input.isOnSfxToggle(x, y)
  local size = layout.SOUND_TOGGLE_SIZE
  local margin = layout.SOUND_TOGGLE_MARGIN
  local toggleY = layout.SOUND_TOGGLE_Y
  local sfxX = VW - margin - size * 2 - margin
  return x >= sfxX and x <= sfxX + size and y >= toggleY and y <= toggleY + size
end

--- Check if click is on Music toggle button
-- @param x Click x coordinate (game space)
-- @param y Click y coordinate (game space)
-- @return true if on Music toggle
function input.isOnMusicToggle(x, y)
  local size = layout.SOUND_TOGGLE_SIZE
  local margin = layout.SOUND_TOGGLE_MARGIN
  local toggleY = layout.SOUND_TOGGLE_Y
  local musicX = VW - margin - size
  return x >= musicX and x <= musicX + size and y >= toggleY and y <= toggleY + size
end

--- Check if click is on Reset button (left of SFX toggle)
-- @param x Click x coordinate (game space)
-- @param y Click y coordinate (game space)
-- @return true if on Reset button
function input.isOnResetButton(x, y)
  local size = layout.SOUND_TOGGLE_SIZE
  local margin = layout.SOUND_TOGGLE_MARGIN
  local toggleY = layout.SOUND_TOGGLE_Y
  local resetX = VW - margin - size * 3 - margin * 2
  return x >= resetX and x <= resetX + size and y >= toggleY and y <= toggleY + size
end

--- Convert window/screen coordinates to virtual game coordinates
-- @param x Screen x coordinate
-- @param y Screen y coordinate
-- @param ox X offset (letterbox)
-- @param oy Y offset (letterbox)
-- @param scale Scale factor
-- @return Game x, Game y
function input.toGameCoords(x, y, ox, oy, scale)
  return (x - ox) / scale, (y - oy) / scale
end

return input
