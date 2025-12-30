-- screens.lua
-- Screen management system for Coins-Boxes

local layout = require("layout")
local progression = require("progression")

local screens = {}

-- Current active screen
local current_screen = nil

-- Screen registry
local registry = {}

-- Common layout values
local VW, VH = layout.VW, layout.VH

--------------------------------------------------------------------------------
-- Screen Manager API
--------------------------------------------------------------------------------

function screens.register(name, screen)
    registry[name] = screen
end

function screens.switch(name)
    if registry[name] then
        if current_screen and current_screen.exit then
            current_screen.exit()
        end
        current_screen = registry[name]
        if current_screen.enter then
            current_screen.enter()
        end
    else
        error("Screen not found: " .. name)
    end
end

function screens.update(dt)
    if current_screen and current_screen.update then
        current_screen.update(dt)
    end
end

function screens.draw()
    if current_screen and current_screen.draw then
        current_screen.draw()
    end
end

function screens.mousepressed(x, y, button)
    if current_screen and current_screen.mousepressed then
        current_screen.mousepressed(x, y, button)
    end
end

function screens.mousereleased(x, y, button)
    if current_screen and current_screen.mousereleased then
        current_screen.mousereleased(x, y, button)
    end
end

function screens.keypressed(key, scancode, isrepeat)
    if current_screen and current_screen.keypressed then
        current_screen.keypressed(key, scancode, isrepeat)
    end
end

-- Touch input delegation (for mobile)
function screens.touchpressed(id, x, y, pressure)
    if current_screen and current_screen.touchpressed then
        current_screen.touchpressed(id, x, y, pressure)
    elseif current_screen and current_screen.mousepressed then
        -- Fallback: treat touch as mouse click
        current_screen.mousepressed(x, y, 1)
    end
end

function screens.touchreleased(id, x, y)
    if current_screen and current_screen.touchreleased then
        current_screen.touchreleased(id, x, y)
    elseif current_screen and current_screen.mousereleased then
        -- Fallback: treat touch release as mouse release
        current_screen.mousereleased(x, y, 1)
    end
end

function screens.touchmoved(id, x, y)
    if current_screen and current_screen.touchmoved then
        current_screen.touchmoved(id, x, y)
    end
end

function screens.getCurrent()
    return current_screen
end

--------------------------------------------------------------------------------
-- Mode Selection Screen
--------------------------------------------------------------------------------

local mode_select = {}

local buttons = {}
local selected_button = nil

function mode_select.enter()
    -- Define menu buttons with unlock checks
    buttons = {
        {
            label = "Classic Mode",
            x = (VW - 400) / 2,
            y = 800,
            width = 400,
            height = 120,
            unlock_key = "classic",  -- progression unlock key
            action = function()
                screens.switch("game")
            end
        },
        {
            label = "2048 Mode",
            x = (VW - 400) / 2,
            y = 1000,
            width = 400,
            height = 120,
            unlock_key = "mode_2048",  -- progression unlock key
            action = function()
                screens.switch("game_2048")
            end
        },
        {
            label = "Dev Test Mode",
            x = (VW - 400) / 2,
            y = 1200,
            width = 400,
            height = 120,
            action = function()
                screens.switch("game_dev")
            end
        },
    }

    -- Check unlock status for each button
    for _, btn in ipairs(buttons) do
        if btn.unlock_key then
            btn.locked = not progression.isUnlocked("modes", btn.unlock_key)
        end
    end
end

function mode_select.exit()
    -- cleanup if needed
end

function mode_select.update(dt)
    -- animations could go here
end

-- Draw a lock icon
local function drawLockIcon(x, y, size)
    local s = size
    -- Lock body (rectangle)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.rectangle("fill", x + s*0.25, y + s*0.4, s*0.5, s*0.5, 4, 4)
    -- Lock shackle (arc)
    love.graphics.setLineWidth(s * 0.12)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.arc("line", "open", x + s*0.5, y + s*0.4, s*0.2, math.pi, 0)
    love.graphics.setLineWidth(1)
end

function mode_select.draw()
    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Coins & Boxes", 0, 400, VW, "center")

    -- Subtitle
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("Select Game Mode", 0, 550, VW, "center")

    -- Draw buttons
    for _, btn in ipairs(buttons) do
        local is_disabled = btn.disabled or btn.locked

        if is_disabled then
            love.graphics.setColor(0.4, 0.4, 0.4)
        else
            love.graphics.setColor(1, 1, 1)
        end

        love.graphics.rectangle("line", btn.x, btn.y, btn.width, btn.height, 8, 8)

        -- Button text (centered)
        local text_y = btn.y + (btn.height - layout.FONT_SIZE) / 2
        love.graphics.printf(btn.label, btn.x, text_y, btn.width, "center")

        -- Draw lock icon if locked
        if btn.locked then
            local icon_size = 60
            local icon_x = btn.x + btn.width - icon_size - 20
            local icon_y = btn.y + (btn.height - icon_size) / 2
            drawLockIcon(icon_x, icon_y, icon_size)

            -- Show unlock progress if available
            local current, required = progression.getUnlockProgress("modes", btn.unlock_key)
            if current and required then
                love.graphics.setColor(0.5, 0.5, 0.5)
                local progress_text = string.format("(%d/%d)", current, required)
                love.graphics.printf(progress_text, btn.x, btn.y + btn.height + 10, btn.width, "center")
            end
        end
    end

    -- Stats display
    love.graphics.setColor(0.6, 0.6, 0.6)
    local merges = progression.getStat("total_merges")
    local points = progression.getStat("total_points")
    love.graphics.printf(string.format("Total Merges: %d  |  Total Points: %d", merges, points),
        0, 1500, VW, "center")

    -- Footer hint
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("Press \\ to quit", 0, 2200, VW, "center")
end

function mode_select.mousepressed(x, y, button)
    if button ~= 1 then return end

    for _, btn in ipairs(buttons) do
        local in_x = x >= btn.x and x <= btn.x + btn.width
        local in_y = y >= btn.y and y <= btn.y + btn.height

        if in_x and in_y then
            -- Check if disabled or locked
            if btn.disabled then
                return  -- Button is disabled, do nothing
            end

            if btn.locked then
                -- Could play a "locked" sound or show feedback here
                return
            end

            -- Button is enabled and unlocked
            if btn.action then
                btn.action()
                return
            end
        end
    end
end

function mode_select.keypressed(key, scancode, isrepeat)
    if key == "\\" then
        love.event.quit()
    end
end

-- Register the mode selection screen
screens.register("mode_select", mode_select)

return screens
