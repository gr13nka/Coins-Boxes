-- emoji.lua
-- Food emoji icons for shard/crystal display, drawn as LÖVE2D canvas images.
-- Mapping: red=apple, green=broccoli, purple=eggplant, blue=grapes, pink=donut

local emoji = {}
local images = {}
local initialized = false
local CANVAS_SIZE = 144

local function createImage(drawFunc)
  local c = love.graphics.newCanvas(CANVAS_SIZE, CANVAS_SIZE)
  love.graphics.setCanvas(c)
  love.graphics.clear(0, 0, 0, 0)
  drawFunc(CANVAS_SIZE)
  love.graphics.setCanvas()
  return c
end

function emoji.init()
  if initialized then return end

  -- Apple (red)
  images.red = createImage(function(sz)
    local cx, cy = sz / 2, sz / 2 + 6
    love.graphics.setColor(0.85, 0.12, 0.12)
    love.graphics.circle("fill", cx, cy, 54)
    love.graphics.setColor(1, 0.35, 0.35, 0.5)
    love.graphics.circle("fill", cx - 18, cy - 18, 21)
    love.graphics.setColor(0.4, 0.25, 0.1)
    love.graphics.setLineWidth(7.5)
    love.graphics.line(cx, cy - 54, cx + 6, cy - 36)
    love.graphics.setColor(0.15, 0.65, 0.15)
    love.graphics.ellipse("fill", cx + 18, cy - 45, 21, 9)
  end)

  -- Broccoli (green)
  images.green = createImage(function(sz)
    local cx, cy = sz / 2, sz / 2
    love.graphics.setColor(0.45, 0.55, 0.25)
    love.graphics.rectangle("fill", cx - 12, cy + 15, 24, 42, 6, 6)
    love.graphics.setColor(0.18, 0.58, 0.12)
    love.graphics.circle("fill", cx, cy - 12, 36)
    love.graphics.circle("fill", cx - 30, cy + 6, 24)
    love.graphics.circle("fill", cx + 30, cy + 6, 24)
    love.graphics.circle("fill", cx - 18, cy - 30, 21)
    love.graphics.circle("fill", cx + 18, cy - 30, 21)
    love.graphics.setColor(0.35, 0.75, 0.28, 0.4)
    love.graphics.circle("fill", cx - 9, cy - 24, 15)
  end)

  -- Eggplant (purple)
  images.purple = createImage(function(sz)
    local cx, cy = sz / 2, sz / 2 + 6
    love.graphics.setColor(0.38, 0.08, 0.48)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(-0.3)
    love.graphics.ellipse("fill", 0, 6, 36, 54)
    love.graphics.pop()
    love.graphics.setColor(0.55, 0.25, 0.65, 0.35)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(-0.3)
    love.graphics.ellipse("fill", -12, -9, 12, 30)
    love.graphics.pop()
    love.graphics.setColor(0.18, 0.55, 0.12)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(-0.3)
    love.graphics.ellipse("fill", 0, -48, 27, 12)
    love.graphics.setColor(0.22, 0.6, 0.18)
    love.graphics.setLineWidth(7.5)
    love.graphics.line(0, -57, 6, -69)
    love.graphics.pop()
  end)

  -- Grapes (blue)
  images.blue = createImage(function(sz)
    local cx, cy = sz / 2, sz / 2 + 9
    local r = 18
    love.graphics.setColor(0.28, 0.28, 0.82)
    love.graphics.circle("fill", cx - r, cy + r, r)
    love.graphics.circle("fill", cx + r, cy + r, r)
    love.graphics.circle("fill", cx, cy + r, r)
    love.graphics.circle("fill", cx - r * 0.6, cy, r)
    love.graphics.circle("fill", cx + r * 0.6, cy, r)
    love.graphics.circle("fill", cx, cy - r, r)
    love.graphics.setColor(0.5, 0.5, 1, 0.35)
    love.graphics.circle("fill", cx - 6, cy - r - 6, 9)
    love.graphics.circle("fill", cx - r * 0.6 - 6, cy - 6, 9)
    love.graphics.setColor(0.18, 0.55, 0.12)
    love.graphics.setLineWidth(6)
    love.graphics.line(cx, cy - r - 18, cx, cy - r)
    love.graphics.ellipse("fill", cx + 15, cy - r - 15, 15, 9)
  end)

  -- Donut (pink)
  images.pink = createImage(function(sz)
    local cx, cy = sz / 2, sz / 2
    love.graphics.setColor(0.95, 0.4, 0.6)
    love.graphics.circle("fill", cx, cy, 54)
    love.graphics.setBlendMode("replace")
    love.graphics.setColor(0, 0, 0, 0)
    love.graphics.circle("fill", cx, cy, 21)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 0.55, 0.72, 0.5)
    love.graphics.arc("fill", cx, cy, 45, -math.pi * 0.8, -math.pi * 0.15)
    love.graphics.setLineWidth(6)
    love.graphics.setColor(1, 1, 0.3)
    love.graphics.line(cx - 30, cy - 24, cx - 21, cy - 30)
    love.graphics.setColor(0.3, 0.85, 1)
    love.graphics.line(cx + 21, cy - 30, cx + 30, cy - 24)
    love.graphics.setColor(0.3, 1, 0.3)
    love.graphics.line(cx - 6, cy - 42, cx + 3, cy - 36)
  end)

  initialized = true
end

--- Draw an emoji centered at (x, y) with given size (radius equivalent).
function emoji.draw(color_name, x, y, size)
  if not initialized then return end
  local img = images[color_name]
  if not img then return end
  local s = (size * 2) / CANVAS_SIZE
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(img, x - size, y - size, 0, s, s)
end

return emoji
