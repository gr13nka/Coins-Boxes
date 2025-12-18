-- layout.lua
-- Central configuration for all UI element positions and sizes

local layout = {
    -- Canvas dimensions (virtual resolution)
    VW = 1080,
    VH = 2400,

    -- Window scale (0.5 = half size window, 1.0 = full size)
    -- Adjust this if the window is too large for your screen
    WINDOW_SCALE = 0.5,

    -- Coin/box sizing
    COIN_R = 60,
    ROW_STEP = 130,     -- vertical spacing (unchanged)
    COLUMN_STEP = 180,  -- fits 5 columns in 1080px

    -- Grid positioning (centered vertically)
    GRID_TOP_Y = 500,
    GRID_LEFT_OFFSET = 0,  -- columns at 180, 360, 540, 720, 900 (centered)

    -- Button area (bottom of screen)
    BUTTON_AREA_Y = 1900,
    BUTTON_WIDTH = 350,
    BUTTON_HEIGHT = 100,
    BUTTON_SPACING = 60,

    -- Text/UI positioning
    HINT_X = 60,
    HINT_Y = 150,
    POINTS_X = 400,   -- centered horizontally
    POINTS_Y = 300,

    -- Merged message position
    MERGED_MSG_Y = 420,

    -- Font size
    FONT_SIZE = 36,
}

return layout
