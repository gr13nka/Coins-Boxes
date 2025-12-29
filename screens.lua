-- screens.lua
-- Screen management system for Coins-Boxes

local layout = require("layout")

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
    -- Define menu buttons
    buttons = {
        {
            label = "Classic Mode",
            x = (VW - 400) / 2,
            y = 800,
            width = 400,
            height = 120,
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
            action = function()
                screens.switch("game_2048")
            end
        },
        {
            label = "Coming Soon...",
            x = (VW - 400) / 2,
            y = 1200,
            width = 400,
            height = 120,
            action = nil,  -- disabled
            disabled = true
        },
    }
end

function mode_select.exit()
    -- cleanup if needed
end

function mode_select.update(dt)
    -- animations could go here
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
        if btn.disabled then
            love.graphics.setColor(0.4, 0.4, 0.4)
        else
            love.graphics.setColor(1, 1, 1)
        end

        love.graphics.rectangle("line", btn.x, btn.y, btn.width, btn.height, 8, 8)

        -- Button text (centered)
        local text_y = btn.y + (btn.height - layout.FONT_SIZE) / 2
        love.graphics.printf(btn.label, btn.x, text_y, btn.width, "center")
    end

    -- Footer hint
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("Press \\ to quit", 0, 2200, VW, "center")
end

function mode_select.mousepressed(x, y, button)
    if button ~= 1 then return end

    for _, btn in ipairs(buttons) do
        if not btn.disabled then
            local in_x = x >= btn.x and x <= btn.x + btn.width
            local in_y = y >= btn.y and y <= btn.y + btn.height
            if in_x and in_y and btn.action then
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
