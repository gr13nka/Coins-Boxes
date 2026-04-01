-- layout.lua
-- Central configuration for all UI element positions and sizes
-- Fixed 3×5 grid: 15 boxes arranged in 3 rows of 5, each box holds 10 coins

local layout = {
    -- Canvas dimensions (virtual resolution)
    VW = 1080,
    VH = 1920,

    -- Window scale (0.5 = half size window, 1.0 = full size)
    WINDOW_SCALE = 0.5,

    -- Box grid: 3 rows of 5 boxes
    BOXES_PER_ROW = 5,
    BOX_ROWS_COUNT = 3,   -- rows of boxes in the grid
    SLOTS_PER_BOX = 10,   -- coin slots per box

    -- Derived grid values (set by computeBoxGrid)
    BOX_W = 0,            -- width of a single box
    BOX_H = 0,            -- height of a single box
    COIN_R = 40,          -- coin radius
    ROW_STEP = 0,         -- vertical spacing between coins in a box
    COLUMN_STEP = 0,      -- horizontal spacing between box centers
    GRID_X = 0,           -- left edge of the grid
    GRID_Y = 0,           -- top edge of the grid
    BOX_GAP_X = 20,       -- horizontal gap between boxes
    BOX_GAP_Y = 20,       -- vertical gap between box rows

    -- UI band layout
    GRID_TOP_Y = 280,     -- top of grid area (after HUD)
    GRID_LEFT_OFFSET = 0, -- kept for backward compat (unused)

    -- Button area
    BUTTON_AREA_Y = 1536,
    BUTTON_WIDTH = 350,
    BUTTON_HEIGHT = 100,
    BUTTON_SPACING = 60,

    -- Text/UI positioning
    HINT_X = 60,
    HINT_Y = 150,
    POINTS_X = 400,
    POINTS_Y = 240,
    MERGED_MSG_Y = 250,

    -- Font size
    FONT_SIZE = 36,

    -- Sound toggle buttons
    SOUND_TOGGLE_SIZE = 80,
    SOUND_TOGGLE_MARGIN = 20,
    SOUND_TOGGLE_Y = 50,

    -- Safe area margins
    SAFE_AREA_TOP = 80,
    SAFE_AREA_BOTTOM = 60,

    -- Coin style
    USE_FRUIT_IMAGES = false,

    -- Legacy flags (kept as false for any code that checks them)
    TWO_LAYER = false,
    MULTI_ROW = false,
}

--- Compute all box grid dimensions from available space.
-- Call once at startup or when entering the coin sort screen.
function layout.computeBoxGrid()
    local VW = layout.VW
    local grid_area_w = VW - 60  -- 30px margin each side
    local grid_area_h = layout.BUTTON_AREA_Y - layout.GRID_TOP_Y - 20

    -- Box dimensions
    local total_gap_x = (layout.BOXES_PER_ROW - 1) * layout.BOX_GAP_X
    local total_gap_y = (layout.BOX_ROWS_COUNT - 1) * layout.BOX_GAP_Y
    layout.BOX_W = math.floor((grid_area_w - total_gap_x) / layout.BOXES_PER_ROW)
    layout.BOX_H = math.floor((grid_area_h - total_gap_y) / layout.BOX_ROWS_COUNT)

    -- Row step: vertical spacing between coin centers within a box
    layout.ROW_STEP = math.floor(layout.BOX_H / (layout.SLOTS_PER_BOX + 0.5))

    -- Coin sizing: big relative to box width (coins nearly fill the box)
    -- Use the smaller of width-based and row-based limits
    local r_from_width = math.floor(layout.BOX_W * 0.46)
    local r_from_rows = math.floor(layout.ROW_STEP * 0.50)
    layout.COIN_R = math.min(r_from_width, r_from_rows)

    -- Column step: horizontal spacing between box centers
    layout.COLUMN_STEP = layout.BOX_W + layout.BOX_GAP_X

    -- Grid origin (centered horizontally)
    local total_grid_w = layout.BOXES_PER_ROW * layout.BOX_W + total_gap_x
    layout.GRID_X = math.floor((VW - total_grid_w) / 2)
    layout.GRID_Y = layout.GRID_TOP_Y
end

--- Get the top-left corner of a box by its 1-based index (1-15).
-- Boxes are arranged: row 1 = boxes 1-5, row 2 = boxes 6-10, row 3 = boxes 11-15.
-- @return x, y (top-left corner of the box)
function layout.boxPosition(box_index)
    local grid_col = (box_index - 1) % layout.BOXES_PER_ROW  -- 0-4
    local grid_row = math.floor((box_index - 1) / layout.BOXES_PER_ROW)  -- 0-2
    local x = layout.GRID_X + grid_col * (layout.BOX_W + layout.BOX_GAP_X)
    local y = layout.GRID_Y + grid_row * (layout.BOX_H + layout.BOX_GAP_Y)
    return x, y
end

--- Get the center X and base Y for a box column (backward-compat API for animation.lua).
-- "column" here is box_index (1-15).
-- Returns center_x, base_y where base_y is the top of the coin area.
function layout.columnPosition(column)
    local bx, by = layout.boxPosition(column)
    local center_x = bx + layout.BOX_W / 2
    return center_x, by
end

--- Get screen position for a coin in (column, slot).
-- column = box_index (1-15), slot = coin position within box (1-10).
-- Returns x, y (center of coin), layer (always 0).
function layout.slotPosition(column, slot)
    local center_x, box_top_y = layout.columnPosition(column)
    local y = box_top_y + layout.ROW_STEP * slot
    return center_x, y, 0
end

return layout
