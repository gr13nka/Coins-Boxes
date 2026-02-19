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

    -- UI band layout (percentage of VH=1920):
    -- 10% resources (0-192), 7% counter (192-326), 70% grid (326-1670),
    -- 7% buttons (1670-1804), 6% powerups (1804-1920)

    -- Grid positioning
    GRID_TOP_Y = 326,       -- 17% mark: after resources + counter bands
    GRID_LEFT_OFFSET = 0,

    -- Button area
    BUTTON_AREA_Y = 1670,   -- 87% mark: start of button band
    BUTTON_WIDTH = 350,
    BUTTON_HEIGHT = 100,
    BUTTON_SPACING = 60,

    -- Text/UI positioning
    HINT_X = 60,
    HINT_Y = 150,
    POINTS_X = 400,
    POINTS_Y = 240,

    -- Merged message position (in counter band)
    MERGED_MSG_Y = 290,

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

    -- Coin style: true = per-color fruit images, false = single ball.png with color tinting
    USE_FRUIT_IMAGES = false,

    -- Two-layer depth mode (poker-chip stacking)
    TWO_LAYER = false,              -- active flag, set by applyMetrics
    TWO_LAYER_THRESHOLD = 8,        -- rows >= this triggers 2-layer
    LAYER_OFFSET_X = 0,             -- horizontal offset between back/front
    LAYER_OFFSET_Y = 0,             -- vertical offset between back/front

    -- Multi-row column layout (wraps columns into 2 visual rows)
    MULTI_ROW = false,              -- active flag, set by applyMetrics
    MULTI_ROW_THRESHOLD = 6,        -- columns >= this triggers 2 rows
    COLS_PER_ROW = 0,               -- columns in top visual row (floor half)
    ROW1_BASE_Y = 326,              -- centered base Y for top row columns
    ROW2_BASE_Y = 0,                -- centered base Y for bottom row columns
    BAND_BOUNDARY_Y = 0,            -- Y boundary between top/bottom row bands
    COLUMN_ROW_GAP = 80,            -- pixel gap between the two row bands
}

-- Calculate column step for a given number of columns
function layout.getColumnStep(num_columns)
  return math.floor(layout.VW / (num_columns + 1))
end

-- Compute all grid sizing from column/row count (progressive scaling)
function layout.getGridMetrics(cols, rows)
    -- Multi-row: wrap columns into 2 rows when > 5 columns
    -- Bottom row gets the extra column when uneven
    local multi_row = cols >= layout.MULTI_ROW_THRESHOLD
    local cols_per_row = multi_row and math.floor(cols / 2) or cols

    -- Column step based on cols_per_row (not total) so coins stay large
    local column_step = math.floor(layout.VW / (cols_per_row + 1))

    -- Coin radius: fits within column. 1.5x bigger cap for 4 or fewer columns.
    local base_cap = cols_per_row <= 4 and 99 or 66
    local coin_r = math.min(base_cap, math.floor(column_step * 0.50))

    -- Available grid height: from GRID_TOP_Y to BUTTON_AREA_Y
    local grid_height = layout.BUTTON_AREA_Y - layout.GRID_TOP_Y

    -- In multi-row mode, split height into 2 bands for row_step computation
    local band_height = grid_height
    if multi_row then
        band_height = math.floor((grid_height - layout.COLUMN_ROW_GAP) / 2)
    end

    -- Two-layer mode: at 8+ rows, pair slots into visual rows (halves height)
    -- Disabled in multi-row mode to keep coins straight within boxes
    local two_layer = not multi_row and rows >= layout.TWO_LAYER_THRESHOLD
    local display_rows = two_layer and math.ceil(rows / 2) or rows

    -- Row step: distribute evenly based on display rows, uses band_height in multi-row
    -- Capped at coin_r/2 for tight chip-stack overlap
    local row_step = math.min(math.floor(coin_r * 0.5), math.floor(band_height / (display_rows + 0.5)))

    -- Overlap: coins visually overlap when row_step < coin diameter
    local overlapping = row_step < coin_r * 2

    -- Layer offsets for depth effect (back coin up-left, front coin down-right)
    local layer_offset_x = two_layer and math.floor(coin_r * 0.35) or 0
    local layer_offset_y = two_layer and math.floor(coin_r * 0.2) or 0

    -- Center trays within the 70% grid area
    -- Tray height matches drawTray: ROW_STEP * rows
    local tray_visual_h = row_step * rows
    local row1_base_y, row2_base_y, band_boundary_y

    if multi_row then
        local total_visual_h = tray_visual_h * 2 + layout.COLUMN_ROW_GAP
        local center_offset = math.max(0, math.floor((grid_height - total_visual_h) / 2))
        local row1_tray_top = layout.GRID_TOP_Y + center_offset
        row1_base_y = row1_tray_top - row_step * 0.5
        local row2_tray_top = row1_tray_top + tray_visual_h + layout.COLUMN_ROW_GAP
        row2_base_y = row2_tray_top - row_step * 0.5
        band_boundary_y = row1_tray_top + tray_visual_h + layout.COLUMN_ROW_GAP / 2
    else
        local center_offset = math.max(0, math.floor((grid_height - tray_visual_h) / 2))
        local tray_top = layout.GRID_TOP_Y + center_offset
        row1_base_y = tray_top - row_step * 0.5
        row2_base_y = 0
        band_boundary_y = 0
    end

    return {
        column_step = column_step,
        coin_r = coin_r,
        row_step = row_step,
        overlapping = overlapping,
        two_layer = two_layer,
        layer_offset_x = layer_offset_x,
        layer_offset_y = layer_offset_y,
        multi_row = multi_row,
        cols_per_row = cols_per_row,
        row1_base_y = row1_base_y,
        row2_base_y = row2_base_y,
        band_boundary_y = band_boundary_y,
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
    layout.MULTI_ROW = metrics.multi_row
    layout.COLS_PER_ROW = metrics.cols_per_row
    layout.ROW1_BASE_Y = metrics.row1_base_y
    layout.ROW2_BASE_Y = metrics.row2_base_y
    layout.BAND_BOUNDARY_Y = metrics.band_boundary_y
end

-- Get (x, base_y) for a column, accounting for multi-row wrapping and centering
-- In multi-row mode, columns beyond COLS_PER_ROW wrap to the bottom row band
function layout.columnPosition(column)
    local local_col, base_y
    if layout.MULTI_ROW and column > layout.COLS_PER_ROW then
        local_col = column - layout.COLS_PER_ROW
        base_y = layout.ROW2_BASE_Y
    else
        local_col = column
        base_y = layout.ROW1_BASE_Y
    end
    local x = layout.GRID_LEFT_OFFSET + layout.COLUMN_STEP * local_col
    return x, base_y
end

-- Map (column, slot) to screen position, accounting for multi-row and two-layer mode
-- Returns x, y, layer (0=back, 1=front; always 0 in normal mode)
function layout.slotPosition(column, slot)
    local col_x, col_top_y = layout.columnPosition(column)
    if layout.TWO_LAYER then
        local visual_row = math.ceil(slot / 2)
        local layer = (slot - 1) % 2  -- 0=back, 1=front
        local base_y = col_top_y + layout.ROW_STEP * visual_row
        if layer == 0 then
            return col_x - layout.LAYER_OFFSET_X, base_y - layout.LAYER_OFFSET_Y, 0
        else
            return col_x + layout.LAYER_OFFSET_X, base_y + layout.LAYER_OFFSET_Y, 1
        end
    else
        return col_x, col_top_y + layout.ROW_STEP * slot, 0
    end
end

return layout
