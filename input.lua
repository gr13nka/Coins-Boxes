-- input.lua
-- Input handling: hit testing, coordinate conversion

local layout = require("layout")

local input = {}

-- Layout constants
local VW, VH = layout.VW, layout.VH
local TOP_Y = layout.GRID_TOP_Y
local COLUMN_STEP = layout.COLUMN_STEP
local GRID_X_OFFSET = layout.GRID_LEFT_OFFSET

--- Refresh cached layout values (call after layout.applyMetrics)
function input.updateMetrics()
  TOP_Y = layout.GRID_TOP_Y
  COLUMN_STEP = layout.COLUMN_STEP
  GRID_X_OFFSET = layout.GRID_LEFT_OFFSET
end

--- Determine which box column was clicked (for classic mode)
-- @param x Click x coordinate (game space)
-- @param y Click y coordinate (game space)
-- @param boxes The boxes array to check column count
-- @param top_y The bottom-most y coordinate of the grid
-- @return Column index (1-based) or nil if outside grid
function input.boxAt(x, y, boxes, top_y)
  -- Snap X to nearest column (accounting for grid offset)
  local col = math.floor(((x - GRID_X_OFFSET) / COLUMN_STEP) + 0.5)
  if col < 1 or col > #boxes then return nil end

  -- Only accept clicks within the vertical bounds where boxes are drawn
  local y_min = TOP_Y - 10
  if y < y_min - 10 or y > top_y + 10 then return nil end

  return col
end

--- Determine which box column was clicked (for 2048 mode)
-- Handles multi-row layout: determines band from y, then snaps x to column
-- @param x Click x coordinate (game space)
-- @param y Click y coordinate (game space)
-- @param boxes The boxes array to check column count
-- @param top_y The bottom-most y coordinate of the grid
-- @return Column index (1-based) or nil if outside grid
function input.boxAt2048(x, y, boxes, top_y)
  if layout.MULTI_ROW then
    local cols_per_row = layout.COLS_PER_ROW
    local total_cols = #boxes

    -- Determine which band based on y (midpoint of gap as boundary)
    local band_boundary = layout.ROW2_TOP_Y - layout.COLUMN_ROW_GAP / 2
    local col_offset, max_col

    if y < band_boundary then
      -- Band 1
      col_offset = 0
      max_col = cols_per_row
      if y < TOP_Y - 20 then return nil end
    else
      -- Band 2
      col_offset = cols_per_row
      max_col = total_cols - cols_per_row
      if y < layout.ROW2_TOP_Y - 20 then return nil end
    end

    -- Snap x to nearest column (same spacing for both bands)
    local local_col = math.floor(((x - GRID_X_OFFSET) / COLUMN_STEP) + 0.5)
    if local_col < 1 or local_col > max_col then return nil end

    return col_offset + local_col
  else
    local col = math.floor(((x - GRID_X_OFFSET) / COLUMN_STEP) + 0.5)
    if col < 1 or col > #boxes then return nil end

    local y_min = TOP_Y - 10
    if y < y_min - 10 or y > top_y + 10 then return nil end

    return col
  end
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
