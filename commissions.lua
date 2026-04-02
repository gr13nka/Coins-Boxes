-- commissions.lua
-- Commission system for Coin Sort: Forge/Harvest goals with Bag+Star rewards.
-- 2-3 active commissions per session, refreshed on enter from Arena.
-- Pure data module (no drawing).

local resources = require("resources")
local bags = require("bags")

local commissions = {}

-- Commission templates by difficulty
local FORGE_TEMPLATES = {
  easy = {
    {desc = "Create a Level-4 coin", type = "forge", target_level = 4, target_count = 1},
    {desc = "Complete 5 merges", type = "harvest_merges", target = 5},
  },
  medium = {
    {desc = "Create 2 Level-4 coins", type = "forge", target_level = 4, target_count = 2},
    {desc = "Create a Level-5 coin", type = "forge", target_level = 5, target_count = 1},
    {desc = "Earn 10 Fuel", type = "harvest_fuel", target = 10},
    {desc = "Complete 8 merges", type = "harvest_merges", target = 8},
  },
  hard = {
    {desc = "Create 2 Level-5 coins", type = "forge", target_level = 5, target_count = 2},
    {desc = "Create a Level-6 coin", type = "forge", target_level = 6, target_count = 1},
    {desc = "Earn 3 Stars", type = "harvest_stars", target = 3},
    {desc = "Earn 15 Fuel", type = "harvest_fuel", target = 15},
  },
}

local REWARDS = {
  easy   = {bags = 1, stars = 3},
  medium = {bags = 2, stars = 5},
  hard   = {bags = 3, stars = 10},
}

-- Active commissions: array of {desc, type, difficulty, target, progress, completed}
local active = {}

-- Pick random item from array
local function pick(arr)
  return arr[math.random(#arr)]
end

-- Generate a set of commissions based on max_coin_reached
function commissions.generate(max_coin)
  active = {}
  -- Pick 1 easy + 1 medium, or 1 medium + 1 hard based on progression
  local sets
  if max_coin >= 5 then
    sets = {"medium", "hard"}
  elseif max_coin >= 3 then
    sets = {"easy", "medium"}
  else
    sets = {"easy", "easy"}
  end

  for _, difficulty in ipairs(sets) do
    local template = pick(FORGE_TEMPLATES[difficulty])
    active[#active + 1] = {
      desc = template.desc,
      type = template.type,
      difficulty = difficulty,
      target_level = template.target_level,
      target_count = template.target_count,
      target = template.target or template.target_count,
      progress = 0,
      completed = false,
    }
  end
end

-- Track a merge event: new_number = resulting coin level, gained = {fuel, stars}
function commissions.onMerge(new_number, gained)
  for _, c in ipairs(active) do
    if c.completed then
      -- skip
    elseif c.type == "forge" and new_number >= c.target_level then
      c.progress = c.progress + 1
      if c.progress >= c.target then
        c.completed = true
      end
    elseif c.type == "harvest_merges" then
      c.progress = c.progress + 1
      if c.progress >= c.target then
        c.completed = true
      end
    elseif c.type == "harvest_fuel" and gained and gained.fuel > 0 then
      c.progress = c.progress + gained.fuel
      if c.progress >= c.target then
        c.completed = true
      end
    elseif c.type == "harvest_stars" and gained and gained.stars > 0 then
      c.progress = c.progress + gained.stars
      if c.progress >= c.target then
        c.completed = true
      end
    end
  end
end

-- Get active commissions list
function commissions.getActive()
  return active
end

-- Collect rewards for all completed commissions. Returns total {bags, stars}.
function commissions.collectRewards()
  local total_bags, total_stars = 0, 0
  for _, c in ipairs(active) do
    if c.completed then
      local r = REWARDS[c.difficulty]
      if r then
        total_bags = total_bags + r.bags
        total_stars = total_stars + r.stars
      end
    end
  end
  if total_bags > 0 then bags.addBags(total_bags) end
  if total_stars > 0 then resources.addStars(total_stars) end
  return {bags = total_bags, stars = total_stars}
end

-- Check if all commissions are completed
function commissions.allCompleted()
  for _, c in ipairs(active) do
    if not c.completed then return false end
  end
  return #active > 0
end

-- Clear commissions (on game over)
function commissions.clear()
  active = {}
end

return commissions
