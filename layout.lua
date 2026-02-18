-- layout.lua
-- Central configuration for all UI element positions and sizes

local layout = {
    -- Canvas dimensions (virtual resolution)
    VW = 1080,
    VH = 1920,

    -- Window scale (0.5 = half size window, 1.0 = full size)
    -- Adjust this if the window is too large for your screen
    WINDOW_SCALE = 0.5,

    -- Coin/box sizing
    COIN_R = 60,
    ROW_STEP = 130,     -- vertical spacing (unchanged)
    COLUMN_STEP = 216,  -- fits 4 columns in 1080px

    -- Grid positioning (centered vertically)
    GRID_TOP_Y = 400,
    GRID_LEFT_OFFSET = 0,  -- columns at 180, 360, 540, 720, 900 (centered)

    -- Button area (bottom of screen)
    BUTTON_AREA_Y = 1520,
    BUTTON_WIDTH = 350,
    BUTTON_HEIGHT = 100,
    BUTTON_SPACING = 60,

    -- Text/UI positioning
    HINT_X = 60,
    HINT_Y = 150,
    POINTS_X = 400,   -- centered horizontally
    POINTS_Y = 240,

    -- Merged message position
    MERGED_MSG_Y = 340,

    -- Font size
    FONT_SIZE = 36,

    -- Sound toggle buttons (top-right corner)
    -- Increased size for better touch targets on mobile
    SOUND_TOGGLE_SIZE = 80,
    SOUND_TOGGLE_MARGIN = 20,
    SOUND_TOGGLE_Y = 50,

    -- Safe area margins for notched phones
    SAFE_AREA_TOP = 80,     -- Status bar + notch area
    SAFE_AREA_BOTTOM = 60,  -- Home indicator area

    -- Two-layer depth mode (poker-chip stacking)
    TWO_LAYER = false,              -- active flag, set by applyMetrics
    TWO_LAYER_THRESHOLD = 8,        -- rows >= this triggers 2-layer
    LAYER_OFFSET_X = 0,             -- horizontal offset between back/front
    LAYER_OFFSET_Y = 0,             -- vertical offset between back/front
}

-- Calculate column step for a given number of columns
function layout.getColumnStep(num_columns)
  return math.floor(layout.VW / (num_columns + 1))
end

-- Compute all grid sizing from column/row count (progressive scaling)
function layout.getGridMetrics(cols, rows)
    local column_step = math.floor(layout.VW / (cols + 1))

    -- Coin radius: fits within column, capped at 60
    local coin_r = math.min(60, math.floor(column_step * 0.45))

    -- Available grid height: from GRID_TOP_Y to BUTTON_AREA_Y minus margin
    local grid_height = layout.BUTTON_AREA_Y - layout.GRID_TOP_Y - 80

    -- Two-layer mode: at 8+ rows, pair slots into visual rows (halves height)
    local two_layer = rows >= layout.TWO_LAYER_THRESHOLD
    local display_rows = two_layer and math.ceil(rows / 2) or rows

    -- Row step: distribute evenly based on display rows, cap at 130
    local row_step = math.min(130, math.floor(grid_height / (display_rows + 0.5)))

    -- Overlap: coins visually overlap when row_step < coin diameter
    local overlapping = row_step < coin_r * 2

    -- Layer offsets for depth effect (back coin up-left, front coin down-right)
    local layer_offset_x = two_layer and math.floor(coin_r * 0.35) or 0
    local layer_offset_y = two_layer and math.floor(coin_r * 0.2) or 0

    return {
        column_step = column_step,
        coin_r = coin_r,
        row_step = row_step,
        overlapping = overlapping,
        two_layer = two_layer,
        layer_offset_x = layer_offset_x,
        layer_offset_y = layer_offset_y,
    }
end

-- Write computed metrics back to layout globals
function layout.applyMetrics(metrics)
    layout.COLUMN_STEP = metrics.column_step
    layout.COIN_R = metrics.coin_r
    layout.ROW_STEP = metrics.row_step
    layout.TWO_LAYER = metrics.two_layer
    layout.LAYER_OFFSET_X = metrics.layer_offset_x
    layout.LAYER_OFFSET_Y = metrics.layer_offset_y
end

-- Map (column, slot) to screen position, accounting for two-layer mode
-- Returns x, y, layer (0=back, 1=front; always 0 in normal mode)
function layout.slotPosition(column, slot)
    local base_x = layout.GRID_LEFT_OFFSET + layout.COLUMN_STEP * column
    if layout.TWO_LAYER then
        local visual_row = math.ceil(slot / 2)
        local layer = (slot - 1) % 2  -- 0=back, 1=front
        local base_y = layout.GRID_TOP_Y + layout.ROW_STEP * visual_row
        if layer == 0 then
            return base_x - layout.LAYER_OFFSET_X, base_y - layout.LAYER_OFFSET_Y, 0
        else
            return base_x + layout.LAYER_OFFSET_X, base_y + layout.LAYER_OFFSET_Y, 1
        end
    else
        return base_x, layout.GRID_TOP_Y + layout.ROW_STEP * slot, 0
    end
end

return layout
