-- commissions.lua
-- Commission system for Coin Sort: Forge/Harvest goals with Bag+Star rewards.
-- Persistent across sessions via progression.dat. Manual per-commission collect,
-- batch refresh when both are collected. Difficulty scales by lifetime completions.
-- Pure data module (no drawing).

local resources = require("resources")
local bags = require("bags")
local progression = require("progression")

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

-- Active commissions: array of {desc, type, difficulty, target_level, target_count, target, progress, completed, collected}
local active = {}

-- Lifetime count of commissions collected (drives difficulty scaling)
local lifetime_completed = 0

-- Pick random item from array
local function pick(arr)
  return arr[math.random(#arr)]
end

-- Generate a set of commissions. Difficulty based on lifetime_completed count.
function commissions.generate()
  active = {}
  local sets
  if lifetime_completed >= 20 then
    sets = {"medium", "hard"}
  elseif lifetime_completed >= 8 then
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
      collected = false,
    }
  end
end

-- Track a merge event: new_number = resulting coin level, gained = {fuel, stars}
function commissions.onMerge(new_number, gained)
  local any_progress = false
  for _, c in ipairs(active) do
    if c.completed or c.collected then
      -- skip completed/collected commissions
    elseif c.type == "forge" and new_number >= c.target_level then
      c.progress = c.progress + 1
      if c.progress >= c.target then
        c.completed = true
      end
      any_progress = true
    elseif c.type == "harvest_merges" then
      c.progress = c.progress + 1
      if c.progress >= c.target then
        c.completed = true
      end
      any_progress = true
    elseif c.type == "harvest_fuel" and gained and gained.fuel and gained.fuel > 0 then
      c.progress = c.progress + gained.fuel
      if c.progress >= c.target then
        c.completed = true
      end
      any_progress = true
    elseif c.type == "harvest_stars" and gained and gained.stars and gained.stars > 0 then
      c.progress = c.progress + gained.stars
      if c.progress >= c.target then
        c.completed = true
      end
      any_progress = true
    end
  end
  if any_progress then
    commissions.save()
  end
end

-- Get active commissions list
function commissions.getActive()
  return active
end

-- Get lifetime completed count
function commissions.getLifetimeCompleted()
  return lifetime_completed
end

-- Collect reward for a single commission by index. Returns {bags, stars} or nil.
function commissions.collectSingle(index)
  local c = active[index]
  if not c or not c.completed or c.collected then return nil end

  local r = REWARDS[c.difficulty]
  if not r then return nil end

  c.collected = true
  lifetime_completed = lifetime_completed + 1

  -- Apply rewards
  bags.addBags(r.bags)
  resources.addStars(r.stars)

  commissions.save()
  return {bags = r.bags, stars = r.stars}
end

-- Check if all commissions have been collected (ready for batch refresh)
function commissions.canRefresh()
  if #active == 0 then return false end
  for _, c in ipairs(active) do
    if not c.collected then return false end
  end
  return true
end

-- Refresh commissions if all are collected (batch refresh per D-13)
function commissions.refreshIfReady()
  if not commissions.canRefresh() then return false end
  commissions.generate()
  commissions.save()
  return true
end

-- Save commission state to progression
function commissions.save()
  progression.setCommissionsData({
    active = active,
    lifetime_completed = lifetime_completed,
  })
end

-- Sync for save batching (called by coin_sort.save() / arena.save() before progression.save())
function commissions.sync()
  commissions.save()
end

-- Load commission state from progression. Generates new if no valid save.
function commissions.load()
  local saved = progression.getCommissionsData()
  if saved and saved.active and #saved.active > 0 then
    active = saved.active
    lifetime_completed = saved.lifetime_completed or 0
  else
    lifetime_completed = saved and saved.lifetime_completed or 0
    commissions.generate()
  end
end

-- Initialize commissions (load from save or generate fresh)
function commissions.init()
  commissions.load()
end

return commissions
