-- arena_icons.lua
-- Item icon sprite loading and rendering for Merge Arena.
-- Pure visual module (no game logic). Falls back gracefully when sprites missing.

local arena_chains = require("arena_chains")

local icons = {}

local sprites = {} -- sprites["ch"][1] = love.Image, etc.

function icons.init()
  local chain_ids = arena_chains.getAllChainIds()
  for _, cid in ipairs(chain_ids) do
    local chain = arena_chains.getChain(cid)
    if chain then
      local key = string.lower(cid)
      sprites[key] = {}
      for level = 1, #chain.items do
        local path = string.format("assets/icons/%s_%d.png", key, level)
        local ok, img = pcall(love.graphics.newImage, path)
        if ok then
          img:setFilter("linear", "linear")
          sprites[key][level] = img
        end
      end
    end
  end
end

function icons.getSprite(chain_id, level)
  local key = string.lower(chain_id)
  local chain_sprites = sprites[key]
  if chain_sprites then
    return chain_sprites[level]
  end
  return nil
end

--- Draw sprite centered at (cx, cy) fitting within radius.
-- Returns true if sprite was drawn, false if fallback needed.
function icons.drawSprite(chain_id, level, cx, cy, radius, alpha)
  local sprite = icons.getSprite(chain_id, level)
  if not sprite then return false end

  alpha = alpha or 1
  local w, h = sprite:getDimensions()
  local diameter = radius * 2
  local scale = diameter / math.max(w, h)

  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.draw(sprite,
    cx - (w * scale) / 2,
    cy - (h * scale) / 2,
    0, scale, scale)
  return true
end

return icons
