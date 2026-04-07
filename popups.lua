-- popups.lua
-- Popup queue system: toast/card/celebration tiers, FIFO queue, rendering
-- UI overlay component (like tab_bar.lua) -- manages its own queue and visual state
-- Does NOT touch game state; callers handle side effects via onDismiss callbacks

local layout = require("layout")
local effects = require("effects")

local popups = {}

-- Toast banner constants (from UI-SPEC)
local TOAST_WIDTH = 1040
local TOAST_HEIGHT = 80
local TOAST_Y_VISIBLE = 20
local TOAST_Y_HIDDEN = -100
local TOAST_CORNER_RADIUS = 12
local TOAST_BG = {0.12, 0.16, 0.11, 0.92}
local TOAST_BORDER = {0.3, 0.5, 0.3, 0.5}
local TOAST_BORDER_WIDTH = 2
local TOAST_ACCENT = {0.25, 0.65, 0.35}
local TOAST_ACCENT_WIDTH = 4
local TOAST_ICON_SIZE = 50
local MAX_VISIBLE_TOASTS = 3
local TOAST_HOLD_TIME = 2.0
local TOAST_SLIDE_IN_TIME = 0.25
local TOAST_SLIDE_OUT_TIME = 0.2
local TOAST_TAP_DISMISS_TIME = 0.15
local TOAST_STACK_GAP = 8

-- Medium card constants
local CARD_WIDTH = 648
local CARD_MIN_HEIGHT = 360
local CARD_MAX_HEIGHT = 600
local CARD_CORNER_RADIUS = 16
local CARD_BG = {0.12, 0.16, 0.11, 0.95}
local CARD_BORDER = {0.3, 0.5, 0.3, 0.6}
local CARD_BORDER_WIDTH = 3
local CARD_BACKDROP = {0, 0, 0, 0.7}
local CARD_BUTTON_W = 300
local CARD_BUTTON_H = 70
local CARD_BUTTON_RADIUS = 12
local CARD_ENTER_TIME = 0.2
local CARD_EXIT_TIME = 0.15
local CARD_BACKDROP_TIME = 0.15

-- Celebration card constants
local CELEB_WIDTH = 864
local CELEB_MIN_HEIGHT = 480
local CELEB_MAX_HEIGHT = 720
local CELEB_CORNER_RADIUS = 20
local CELEB_BG = {0.12, 0.16, 0.11, 0.95}
local CELEB_BORDER = {0.35, 0.75, 0.45, 0.8}
local CELEB_BORDER_WIDTH = 4
local CELEB_TITLE_COLOR = {0.95, 0.85, 0.25}
local CELEB_BUTTON_W = 350
local CELEB_BUTTON_H = 80
local CELEB_ENTER_TIME = 0.3
local CELEB_EXIT_TIME = 0.2

-- Shared constants
local BUTTON_COLOR = {0.25, 0.65, 0.35}
local TEXT_PRIMARY = {0.92, 0.88, 0.78}
local TEXT_SECONDARY = {0.65, 0.68, 0.58}
local INTER_DELAY = 0.3
local ICON_COLORS = {
    fuel = {1, 0.75, 0.15},
    star = {0.95, 0.85, 0.25},
    bag  = {0.8, 0.6, 0.3},
}

-- Easing functions (matching effects.lua patterns)
local function easeOutCubic(t)
    return 1 - (1 - t) * (1 - t) * (1 - t)
end
local function easeInQuad(t)
    return t * t
end
local function easeOutElastic(t)
    if t == 0 or t == 1 then return t end
    return math.pow(2, -10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi / 3)) + 1
end

-- Module state
local queue = {}            -- FIFO: {tier, title, body, rewards, onDismiss}
local active_toasts = {}    -- array of active toast objects
local active_modal = nil    -- current card/celebration or nil
local inter_delay_timer = 0 -- countdown between sequential modals
local fonts = nil           -- {heading, display, body, label}
local celebration_effects_fired = false

-- Get Y target for a toast at a given stack index (1-based)
local function toastTargetY(stack_index)
    return TOAST_Y_VISIBLE + (stack_index - 1) * (TOAST_HEIGHT + TOAST_STACK_GAP)
end

-- Calculate card height based on content
local function calculateCardHeight(data, is_celebration)
    local min_h = is_celebration and CELEB_MIN_HEIGHT or CARD_MIN_HEIGHT
    local max_h = is_celebration and CELEB_MAX_HEIGHT or CARD_MAX_HEIGHT
    local h = 48 + 48 + 70 + 80  -- title + gap + button + padding
    if data.body and data.body ~= "" and fonts and fonts.body then
        local card_w = is_celebration and CELEB_WIDTH or CARD_WIDTH
        local _, lines = fonts.body:getWrap(data.body, card_w - 80)
        h = h + #lines * fonts.body:getHeight() * 1.4 + 32
    end
    if data.rewards and #data.rewards > 0 then
        h = h + 50
    end
    if is_celebration and data.level_text then
        h = h + 80
    end
    return math.max(min_h, math.min(max_h, h))
end

-- Get the accept button rect for the active modal
local function getModalButtonRect()
    if not active_modal then return 0, 0, 0, 0 end
    local is_celeb = active_modal.data.tier == "celebration"
    local card_w = is_celeb and CELEB_WIDTH or CARD_WIDTH
    local card_h = active_modal.card_height or CARD_MIN_HEIGHT
    local btn_w = is_celeb and CELEB_BUTTON_W or CARD_BUTTON_W
    local btn_h = is_celeb and CELEB_BUTTON_H or CARD_BUTTON_H
    local card_x = (layout.VW - card_w) / 2
    local card_y = (layout.VH - card_h) / 2
    return card_x + (card_w - btn_w) / 2, card_y + card_h - btn_h - 24, btn_w, btn_h
end

-- Spawn a new toast from queue data
local function spawnToast(data)
    local stack_index = #active_toasts + 1
    active_toasts[stack_index] = {
        data = data, state = "entering", timer = 0,
        y = TOAST_Y_HIDDEN, target_y = toastTargetY(stack_index), alpha = 1,
    }
end

-- Pop toasts from queue (up to MAX_VISIBLE_TOASTS active)
local function processToastQueue()
    local i = 1
    while i <= #queue do
        if #active_toasts >= MAX_VISIBLE_TOASTS then return end
        if queue[i].tier == "toast" then
            spawnToast(table.remove(queue, i))
        else
            i = i + 1
        end
    end
end

-- Pop the next card/celebration from queue
local function processModalQueue()
    if active_modal or inter_delay_timer > 0 then return end
    for i = 1, #queue do
        local item = queue[i]
        if item.tier == "card" or item.tier == "celebration" then
            local data = table.remove(queue, i)
            local is_celeb = data.tier == "celebration"
            active_modal = {
                data = data, state = "entering", timer = 0,
                alpha = 0, scale = is_celeb and 0.7 or 0.85,
                backdrop_alpha = 0, card_height = calculateCardHeight(data, is_celeb),
            }
            celebration_effects_fired = false
            return
        end
    end
end

-- Rounded rectangle helper
local function drawRoundedRect(mode, x, y, w, h, r)
    love.graphics.rectangle(mode, x, y, w, h, r, r)
end

-- Public API

function popups.init(fonts_table)
    fonts = fonts_table
    queue = {}
    active_toasts = {}
    active_modal = nil
    inter_delay_timer = 0
    celebration_effects_fired = false
end

function popups.push(item)
    if not item or not item.tier then return end
    queue[#queue + 1] = item
    if item.tier == "toast" then
        processToastQueue()
    end
end

function popups.update(dt)
    if inter_delay_timer > 0 then
        inter_delay_timer = inter_delay_timer - dt
    end

    -- Update active toasts
    local i = 1
    while i <= #active_toasts do
        local toast = active_toasts[i]
        toast.timer = toast.timer + dt

        if toast.state == "entering" then
            local progress = math.min(toast.timer / TOAST_SLIDE_IN_TIME, 1)
            local eased = easeOutCubic(progress)
            toast.y = TOAST_Y_HIDDEN + (toast.target_y - TOAST_Y_HIDDEN) * eased
            toast.alpha = eased
            if progress >= 1 then
                toast.state = "visible"
                toast.timer = 0
                toast.y = toast.target_y
                toast.alpha = 1
            end
        elseif toast.state == "visible" then
            if toast.timer >= TOAST_HOLD_TIME then
                toast.state = "exiting"
                toast.timer = 0
            end
        elseif toast.state == "exiting" then
            local exit_dur = toast.tap_dismiss and TOAST_TAP_DISMISS_TIME or TOAST_SLIDE_OUT_TIME
            local progress = math.min(toast.timer / exit_dur, 1)
            local eased = easeInQuad(progress)
            toast.y = toast.target_y + (TOAST_Y_HIDDEN - toast.target_y) * eased
            toast.alpha = 1 - eased
            if progress >= 1 then
                if toast.data.onDismiss then toast.data.onDismiss() end
                table.remove(active_toasts, i)
                for j = i, #active_toasts do
                    active_toasts[j].target_y = toastTargetY(j)
                end
                i = i - 1  -- re-check this index after removal
            end
        end
        i = i + 1
    end

    -- Update active modal
    if active_modal then
        active_modal.timer = active_modal.timer + dt
        local is_celeb = active_modal.data.tier == "celebration"

        if active_modal.state == "entering" then
            local enter_time = is_celeb and CELEB_ENTER_TIME or CARD_ENTER_TIME
            local progress = math.min(active_modal.timer / enter_time, 1)
            local backdrop_progress = math.min(active_modal.timer / CARD_BACKDROP_TIME, 1)
            active_modal.backdrop_alpha = CARD_BACKDROP[4] * backdrop_progress
            if is_celeb then
                local eased = easeOutElastic(progress)
                active_modal.scale = 0.7 + 0.3 * eased
                active_modal.alpha = math.min(progress / 0.3, 1)
            else
                local eased = easeOutCubic(progress)
                active_modal.scale = 0.85 + 0.15 * eased
                active_modal.alpha = eased
            end
            if is_celeb and not celebration_effects_fired then
                celebration_effects_fired = true
                effects.spawnFlash(0.3, 0.95, 0.85, 0.25)
                effects.spawnBurst(layout.VW / 2, layout.VH / 2, 16, {0.95, 0.85, 0.25})
            end
            if progress >= 1 then
                active_modal.state = "visible"
                active_modal.timer = 0
                active_modal.scale = 1
                active_modal.alpha = 1
                active_modal.backdrop_alpha = CARD_BACKDROP[4]
            end
        elseif active_modal.state == "exiting" then
            local exit_time = is_celeb and CELEB_EXIT_TIME or CARD_EXIT_TIME
            local progress = math.min(active_modal.timer / exit_time, 1)
            local eased = easeInQuad(progress)
            active_modal.scale = 1 - (is_celeb and 0.15 or 0.1) * eased
            active_modal.alpha = 1 - eased
            active_modal.backdrop_alpha = CARD_BACKDROP[4] * (1 - eased)
            if progress >= 1 then
                if active_modal.data.onDismiss then active_modal.data.onDismiss() end
                active_modal = nil
                inter_delay_timer = INTER_DELAY
            end
        end
    end

    processToastQueue()
    processModalQueue()
end

function popups.drawToasts()
    if #active_toasts == 0 or not fonts then return end
    local toast_x = (layout.VW - TOAST_WIDTH) / 2

    for i = 1, #active_toasts do
        local toast = active_toasts[i]
        local x, y, alpha = toast_x, toast.y, toast.alpha

        -- Background
        love.graphics.setColor(TOAST_BG[1], TOAST_BG[2], TOAST_BG[3], TOAST_BG[4] * alpha)
        drawRoundedRect("fill", x, y, TOAST_WIDTH, TOAST_HEIGHT, TOAST_CORNER_RADIUS)

        -- Border
        love.graphics.setLineWidth(TOAST_BORDER_WIDTH)
        love.graphics.setColor(TOAST_BORDER[1], TOAST_BORDER[2], TOAST_BORDER[3], TOAST_BORDER[4] * alpha)
        drawRoundedRect("line", x, y, TOAST_WIDTH, TOAST_HEIGHT, TOAST_CORNER_RADIUS)

        -- Left accent stripe
        love.graphics.setColor(TOAST_ACCENT[1], TOAST_ACCENT[2], TOAST_ACCENT[3], alpha)
        love.graphics.rectangle("fill", x + 2, y + TOAST_CORNER_RADIUS,
            TOAST_ACCENT_WIDTH, TOAST_HEIGHT - 2 * TOAST_CORNER_RADIUS)

        -- Icon area (colored circle based on first reward type)
        local icon_x = x + TOAST_ACCENT_WIDTH + 12 + TOAST_ICON_SIZE / 2
        local icon_y = y + TOAST_HEIGHT / 2
        local icon_color = {1, 1, 1}
        if toast.data.rewards and #toast.data.rewards > 0 then
            local ic = ICON_COLORS[toast.data.rewards[1].icon_type]
            if ic then icon_color = ic end
        end
        love.graphics.setColor(icon_color[1], icon_color[2], icon_color[3], alpha)
        love.graphics.circle("fill", icon_x, icon_y, TOAST_ICON_SIZE / 2 - 4)

        -- Message text
        love.graphics.setFont(fonts.body)
        love.graphics.setColor(TEXT_PRIMARY[1], TEXT_PRIMARY[2], TEXT_PRIMARY[3], alpha)
        love.graphics.print(toast.data.title or "",
            icon_x + TOAST_ICON_SIZE / 2 + 12,
            y + (TOAST_HEIGHT - fonts.body:getHeight()) / 2)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function popups.drawModal()
    if not active_modal or not fonts then return end

    local data = active_modal.data
    local is_celeb = data.tier == "celebration"
    local card_w = is_celeb and CELEB_WIDTH or CARD_WIDTH
    local card_h = active_modal.card_height or CARD_MIN_HEIGHT
    local corner_r = is_celeb and CELEB_CORNER_RADIUS or CARD_CORNER_RADIUS
    local border_w = is_celeb and CELEB_BORDER_WIDTH or CARD_BORDER_WIDTH
    local bg = is_celeb and CELEB_BG or CARD_BG
    local border = is_celeb and CELEB_BORDER or CARD_BORDER
    local btn_w = is_celeb and CELEB_BUTTON_W or CARD_BUTTON_W
    local btn_h = is_celeb and CELEB_BUTTON_H or CARD_BUTTON_H
    local btn_label = is_celeb and "Continue" or "Claim Reward"
    local modal_alpha = active_modal.alpha

    -- Backdrop dimmer
    love.graphics.setColor(0, 0, 0, active_modal.backdrop_alpha)
    love.graphics.rectangle("fill", 0, 0, layout.VW, layout.VH)

    -- Card position (centered)
    local card_x = (layout.VW - card_w) / 2
    local card_y = (layout.VH - card_h) / 2
    local cx, cy = card_x + card_w / 2, card_y + card_h / 2

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(active_modal.scale, active_modal.scale)
    love.graphics.translate(-cx, -cy)

    -- Card background and border
    love.graphics.setColor(bg[1], bg[2], bg[3], bg[4] * modal_alpha)
    drawRoundedRect("fill", card_x, card_y, card_w, card_h, corner_r)
    love.graphics.setLineWidth(border_w)
    love.graphics.setColor(border[1], border[2], border[3], border[4] * modal_alpha)
    drawRoundedRect("line", card_x, card_y, card_w, card_h, corner_r)

    -- Content layout (top-down)
    local content_y = card_y + 32

    -- Title
    local title_color = is_celeb and CELEB_TITLE_COLOR or TEXT_PRIMARY
    love.graphics.setFont(fonts.heading)
    local title = data.title or ""
    local title_w = fonts.heading:getWidth(title)
    love.graphics.setColor(title_color[1], title_color[2], title_color[3], modal_alpha)
    love.graphics.print(title, card_x + (card_w - title_w) / 2, content_y)
    content_y = content_y + fonts.heading:getHeight() + 16

    -- Level number (celebration only)
    if is_celeb and data.level_text then
        love.graphics.setFont(fonts.display)
        local lw = fonts.display:getWidth(data.level_text)
        love.graphics.setColor(TEXT_PRIMARY[1], TEXT_PRIMARY[2], TEXT_PRIMARY[3], modal_alpha)
        love.graphics.print(data.level_text, card_x + (card_w - lw) / 2, content_y)
        content_y = content_y + fonts.display:getHeight() + 16
    end

    -- Body text
    if data.body and data.body ~= "" then
        love.graphics.setFont(fonts.body)
        local text_w = card_w - 80
        love.graphics.setColor(TEXT_SECONDARY[1], TEXT_SECONDARY[2], TEXT_SECONDARY[3], modal_alpha * 0.9)
        love.graphics.printf(data.body, card_x + 40, content_y, text_w, "center")
        local _, lines = fonts.body:getWrap(data.body, text_w)
        content_y = content_y + #lines * fonts.body:getHeight() * 1.4 + 24
    end

    -- Reward row (horizontal icons + amounts, centered)
    if data.rewards and #data.rewards > 0 then
        love.graphics.setFont(fonts.label)
        local total_w, items = 0, {}
        for _, reward in ipairs(data.rewards) do
            local text = "+" .. tostring(reward.amount)
            local tw = fonts.label:getWidth(text)
            local iw = 24 + 6 + tw + 20  -- circle diameter + gap + text + spacing
            total_w = total_w + iw
            items[#items + 1] = {icon_type = reward.icon_type, text = text, w = iw}
        end
        local rx, ry = card_x + (card_w - total_w) / 2, content_y + 8
        for _, item in ipairs(items) do
            local c = ICON_COLORS[item.icon_type] or {1, 1, 1}
            love.graphics.setColor(c[1], c[2], c[3], modal_alpha)
            love.graphics.circle("fill", rx + 12, ry + 10, 12)
            love.graphics.setColor(TEXT_PRIMARY[1], TEXT_PRIMARY[2], TEXT_PRIMARY[3], modal_alpha)
            love.graphics.print(item.text, rx + 30, ry)
            rx = rx + item.w
        end
    end

    -- Accept button
    local bx = card_x + (card_w - btn_w) / 2
    local by = card_y + card_h - btn_h - 24
    love.graphics.setColor(BUTTON_COLOR[1], BUTTON_COLOR[2], BUTTON_COLOR[3], modal_alpha)
    drawRoundedRect("fill", bx, by, btn_w, btn_h, CARD_BUTTON_RADIUS)
    love.graphics.setFont(fonts.body)
    local btw = fonts.body:getWidth(btn_label)
    local bth = fonts.body:getHeight()
    love.graphics.setColor(TEXT_PRIMARY[1], TEXT_PRIMARY[2], TEXT_PRIMARY[3], modal_alpha)
    love.graphics.print(btn_label, bx + (btn_w - btw) / 2, by + (btn_h - bth) / 2)

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function popups.isModalActive()
    return active_modal ~= nil
end

function popups.isInputBlocked()
    if not active_modal then return false end
    return active_modal.state == "entering" or active_modal.state == "visible"
end

function popups.handleToastTap(x, y)
    if #active_toasts == 0 then return false end
    local toast_x = (layout.VW - TOAST_WIDTH) / 2
    for i = 1, #active_toasts do
        local toast = active_toasts[i]
        if toast.state == "visible" or toast.state == "entering" then
            if x >= toast_x and x <= toast_x + TOAST_WIDTH
               and y >= toast.y and y <= toast.y + TOAST_HEIGHT then
                toast.state = "exiting"
                toast.timer = 0
                toast.tap_dismiss = true
                return true
            end
        end
    end
    return false
end

function popups.handleModalTap(x, y)
    if not active_modal then return false end
    if active_modal.state ~= "visible" then return false end
    local bx, by, bw, bh = getModalButtonRect()
    if x >= bx and x <= bx + bw and y >= by and y <= by + bh then
        active_modal.state = "exiting"
        active_modal.timer = 0
        return true
    end
    return false
end

return popups
