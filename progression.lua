-- progression.lua
-- Full progression system: unlocks, stats, achievements, persistence

local progression = {}

-- Schema versioning for save migration
local CURRENT_SCHEMA_VERSION = 1

-- Migration functions: each migrates data from version N-1 to version N
local MIGRATIONS = {
  -- Migration to version 1: clean stale classic-mode fields from old saves
  [1] = function(data)
    -- Remove dead currency system
    data.currency = nil

    -- Clean dead unlock categories (keep modes for dormant mode_select)
    if data.unlocks then
      data.unlocks.colors = nil
      data.unlocks.backgrounds = nil
      data.unlocks.powerups = nil
      data.unlocks.cosmetics = nil
    end

    -- Strip dead upgrades_data sub-fields, keep only max_coin_reached
    if data.upgrades_data then
      local mcr = data.upgrades_data.max_coin_reached
      data.upgrades_data = { max_coin_reached = mcr or 0 }
    end

    -- Remove dead achievement entries (keep live ones: first_merge, merge_master, merge_legend, dedicated_player)
    if data.achievements then
      data.achievements.color_collector = nil
      data.achievements.point_hunter = nil
    end

    -- Clean dead stats
    if data.stats then
      data.stats.highest_score_classic = nil
      data.stats.highest_score_2048 = nil
    end

    return data
  end,
}

--- Run all pending migrations on loaded save data
local function runMigrations(data)
  local version = data.schema_version or 0
  while version < CURRENT_SCHEMA_VERSION do
    version = version + 1
    if MIGRATIONS[version] then
      data = MIGRATIONS[version](data)
    end
    data.schema_version = version
  end
  return data
end

-- Default progression data structure
local function getDefaultData()
  return {
    -- Save schema version (for migration support)
    schema_version = CURRENT_SCHEMA_VERSION,

    -- Unlocks by category
    unlocks = {
      modes = {
        classic = true,
        mode_2048 = true,  -- Start unlocked for now, can lock later
      },
    },

    -- Stats for tracking progress
    stats = {
      total_merges = 0,
      total_points = 0,
      games_played = 0,
      total_coins_placed = 0,
    },

    -- Power-ups: consumable counts
    powerups_data = {
      auto_sort = 100,
      hammer = 100,
    },

    -- Upgrades: max coin reached (used by coin_sort.lua)
    upgrades_data = {
      max_coin_reached = 0,
    },

    -- Achievements (name -> unlocked boolean)
    achievements = {
      first_merge = false,
      merge_master = false,      -- 100 total merges
      merge_legend = false,      -- 1000 total merges
      dedicated_player = false,  -- Play 50 games
    },

    -- Resources: Fuel + Stars (Stars replace old Metal/Components)
    resources_data = {
      fuel = 50,
      stars = 0,
    },

    -- Coin bags for Coin Sort dealing
    bags_data = {
      bags = 5,
      free_bag_timer = 0,
      free_bags_queued = 0,
    },

    -- Drops: cross-mode variable rewards
    drops_data = {
      shelf = {},
      gen_tokens = 0,
      pending_cs_drops = {hammer = 0, auto_sort = 0, bag_bundle = 0, double_merge = 0},
    },

    -- Skill tree: PoE-style upgrade web
    skill_tree_data = {
      unlocked = {start = true},
      stars_spent = 0,
    },

    -- Merge Arena state (7x8 grid with boxes/sealed/items, dispenser, stash)
    arena_data = {
      grid = {},
      stash = {},
      dispenser_queue = {},
      order_level = 1,
      completed_orders = {},
      xp = 0,
      tutorial_step = 1,
    },

    -- Coin Sort game state (grid, points, progress)
    coin_sort_data = {},
  }
end

-- Current progression data
local data = getDefaultData()

-- Persistence settings
local SAVE_FILENAME = "progression.dat"
local persistenceEnabled = true

-- Unlock condition definitions
local UNLOCK_CONDITIONS = {
  -- Modes unlock conditions
  modes = {
    -- mode_2048 = { stat = "total_merges", threshold = 5 },  -- Example: unlock at 5 merges
  },
}

-- Achievement condition definitions
local ACHIEVEMENT_CONDITIONS = {
  first_merge = function() return data.stats.total_merges >= 1 end,
  merge_master = function() return data.stats.total_merges >= 100 end,
  merge_legend = function() return data.stats.total_merges >= 1000 end,
  dedicated_player = function() return data.stats.games_played >= 50 end,
}

--------------------------------------------------------------------------------
-- Serialization (simple Lua table format)
--------------------------------------------------------------------------------

local function serializeValue(val, indent)
  indent = indent or 0
  local spaces = string.rep("  ", indent)

  if type(val) == "table" then
    local parts = {}
    local isArray = #val > 0
    for k, v in pairs(val) do
      local keyStr
      if type(k) == "number" then
        keyStr = "[" .. k .. "]"
      else
        keyStr = '["' .. tostring(k) .. '"]'
      end
      table.insert(parts, spaces .. "  " .. keyStr .. " = " .. serializeValue(v, indent + 1))
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. spaces .. "}"
  elseif type(val) == "string" then
    return '"' .. val:gsub('"', '\\"') .. '"'
  elseif type(val) == "boolean" or type(val) == "number" then
    return tostring(val)
  else
    return "nil"
  end
end

local function serialize(tbl)
  return "return " .. serializeValue(tbl)
end

local function deserialize(str)
  local fn, err = (loadstring or load)(str)
  if fn then
    local ok, result = pcall(fn)
    if ok then return result end
  end
  return nil
end

--------------------------------------------------------------------------------
-- Core API
--------------------------------------------------------------------------------

--- Initialize the progression system
-- @param enable_persistence If false, don't save/load (for testing)
function progression.init(enable_persistence)
  if enable_persistence == nil then
    enable_persistence = true
  end
  persistenceEnabled = enable_persistence

  if persistenceEnabled then
    progression.load()
  end
end

--- Reset all progression to defaults (for testing)
function progression.reset()
  data = getDefaultData()
  if persistenceEnabled then
    progression.save()
  end
end

--- Save progression to file
function progression.save()
  if not persistenceEnabled then return true end

  local success, err = love.filesystem.write(SAVE_FILENAME, serialize(data))
  if not success then
    print("Failed to save progression:", err)
    return false
  end
  return true
end

--- Load progression from file
function progression.load()
  if not love.filesystem.getInfo(SAVE_FILENAME) then
    -- No save file, use defaults
    data = getDefaultData()
    return true
  end

  local contents, err = love.filesystem.read(SAVE_FILENAME)
  if not contents then
    print("Failed to read progression file:", err)
    data = getDefaultData()
    return false
  end

  local loaded = deserialize(contents)
  if loaded then
    -- Run migrations FIRST (handles structural changes like removing dead fields)
    loaded = runMigrations(loaded)
    -- Then merge with defaults (fills any missing new fields)
    data = progression.mergeWithDefaults(loaded, getDefaultData())
    -- Ensure schema_version stays current after merge
    data.schema_version = CURRENT_SCHEMA_VERSION
    return true
  else
    print("Failed to parse progression file")
    data = getDefaultData()
    return false
  end
end

--- Merge loaded data with defaults (to handle version updates)
function progression.mergeWithDefaults(loaded, defaults)
  local result = {}

  -- Apply defaults first
  for k, v in pairs(defaults) do
    if type(v) == "table" then
      if type(loaded[k]) == "table" then
        result[k] = progression.mergeWithDefaults(loaded[k], v)
      else
        result[k] = v
      end
    else
      result[k] = loaded[k] ~= nil and loaded[k] or v
    end
  end

  -- Preserve loaded keys not in defaults (e.g. coin_sort_data contents)
  for k, v in pairs(loaded) do
    if result[k] == nil then
      result[k] = v
    end
  end

  return result
end

--------------------------------------------------------------------------------
-- Unlock System
--------------------------------------------------------------------------------

--- Check if something is unlocked
-- @param category Category name (modes, colors, backgrounds, powerups, cosmetics)
-- @param key Item key within category
-- @return true if unlocked
function progression.isUnlocked(category, key)
  if data.unlocks[category] then
    return data.unlocks[category][key] == true
  end
  return false
end

--- Unlock something
-- @param category Category name
-- @param key Item key
-- @return true if newly unlocked, false if already unlocked
function progression.unlock(category, key)
  if not data.unlocks[category] then
    data.unlocks[category] = {}
  end

  if data.unlocks[category][key] then
    return false  -- Already unlocked
  end

  data.unlocks[category][key] = true
  progression.save()
  return true
end

--- Get all unlocked items in a category
-- @param category Category name
-- @return Table of unlocked keys
function progression.getUnlocked(category)
  local result = {}
  if data.unlocks[category] then
    for key, unlocked in pairs(data.unlocks[category]) do
      if unlocked then
        table.insert(result, key)
      end
    end
  end
  return result
end

--- Get unlock progress for a locked item
-- @param category Category name
-- @param key Item key
-- @return current, required (progress numbers) or nil if no condition defined
function progression.getUnlockProgress(category, key)
  if progression.isUnlocked(category, key) then
    return nil, nil  -- Already unlocked
  end

  local conditions = UNLOCK_CONDITIONS[category]
  if conditions and conditions[key] then
    local cond = conditions[key]
    local current = data.stats[cond.stat] or 0
    return current, cond.threshold
  end

  return nil, nil
end

--- Check and apply all unlock conditions
local function checkUnlocks()
  local newUnlocks = {}

  for category, conditions in pairs(UNLOCK_CONDITIONS) do
    for key, cond in pairs(conditions) do
      if not progression.isUnlocked(category, key) then
        local current = data.stats[cond.stat] or 0
        if current >= cond.threshold then
          progression.unlock(category, key)
          table.insert(newUnlocks, { category = category, key = key })
        end
      end
    end
  end

  return newUnlocks
end

--------------------------------------------------------------------------------
-- Stats System
--------------------------------------------------------------------------------

--- Add to a stat
-- @param key Stat name
-- @param amount Amount to add (default 1)
function progression.addStat(key, amount)
  amount = amount or 1
  data.stats[key] = (data.stats[key] or 0) + amount
end

--- Set a stat (for high scores, etc.)
-- @param key Stat name
-- @param value New value
function progression.setStat(key, value)
  data.stats[key] = value
end

--- Get a stat value
-- @param key Stat name
-- @return Stat value or 0
function progression.getStat(key)
  return data.stats[key] or 0
end

--- Update high score if new score is higher
-- @param key Stat name (e.g., highest_score_classic)
-- @param score New score
-- @return true if new high score
function progression.updateHighScore(key, score)
  local current = data.stats[key] or 0
  if score > current then
    data.stats[key] = score
    return true
  end
  return false
end

--------------------------------------------------------------------------------
-- Achievements System
--------------------------------------------------------------------------------

--- Check if an achievement is unlocked
-- @param name Achievement name
-- @return true if unlocked
function progression.hasAchievement(name)
  return data.achievements[name] == true
end

--- Get all achievements with their unlock status
-- @return Table of {name = unlocked}
function progression.getAchievements()
  return data.achievements
end

--- Check and award all achievements
-- @return Array of newly awarded achievement names
function progression.checkAchievements()
  local newAchievements = {}

  for name, checkFn in pairs(ACHIEVEMENT_CONDITIONS) do
    if not data.achievements[name] and checkFn() then
      data.achievements[name] = true
      table.insert(newAchievements, name)
    end
  end

  if #newAchievements > 0 then
    progression.save()
  end

  return newAchievements
end

--------------------------------------------------------------------------------
-- Game Event Hooks
--------------------------------------------------------------------------------

--- Called when a merge happens
-- @param mode Game mode ("classic" or "2048")
-- @param count Number of coins merged (default 1)
-- @return newUnlocks, newAchievements tables
function progression.onMerge(mode, count)
  count = count or 1
  progression.addStat("total_merges", count)

  local newUnlocks = checkUnlocks()
  local newAchievements = progression.checkAchievements()

  progression.save()

  return newUnlocks, newAchievements
end

--- Called when points are scored
-- @param points Points scored
function progression.onPoints(points)
  progression.addStat("total_points", points)

  checkUnlocks()
  progression.checkAchievements()
  progression.save()
end

--- Called when a coin is placed
function progression.onCoinPlaced()
  progression.addStat("total_coins_placed", 1)
end

--- Called when a game ends
function progression.onGameEnd()
  progression.addStat("games_played", 1)

  checkUnlocks()
  progression.checkAchievements()
  progression.save()
end

--------------------------------------------------------------------------------
-- Debug/Testing
--------------------------------------------------------------------------------

--- Get raw data (for debugging)
function progression.getData()
  return data
end

--- Force unlock everything (for testing)
function progression.unlockAll()
  for category, items in pairs(data.unlocks) do
    for key, _ in pairs(items) do
      data.unlocks[category][key] = true
    end
  end
  for name, _ in pairs(data.achievements) do
    data.achievements[name] = true
  end
  progression.save()
end

--------------------------------------------------------------------------------
-- Sub-system Data Accessors
--------------------------------------------------------------------------------

function progression.getUpgradesData()
  return data.upgrades_data
end

function progression.setUpgradesData(d)
  data.upgrades_data = d
end

function progression.getPowerupsData()
  return data.powerups_data
end

function progression.setPowerupsData(d)
  data.powerups_data = d
end

function progression.getResourcesData()
  return data.resources_data
end

function progression.setResourcesData(d)
  data.resources_data = d
end

function progression.getBagsData()
  return data.bags_data
end

function progression.setBagsData(d)
  data.bags_data = d
end

function progression.getArenaData()
  return data.arena_data
end

function progression.setArenaData(d)
  data.arena_data = d
end

function progression.getDropsData()
  return data.drops_data or {shelf = {}, gen_tokens = 0, pending_cs_drops = {hammer = 0, auto_sort = 0, bag_bundle = 0, double_merge = 0}}
end

function progression.setDropsData(d)
  data.drops_data = d
end

function progression.getSkillTreeData()
  return data.skill_tree_data or {unlocked = {start = true}, stars_spent = 0}
end

function progression.setSkillTreeData(d)
  data.skill_tree_data = d
end

function progression.getCoinSortData()
  return data.coin_sort_data or {}
end

function progression.setCoinSortData(d)
  data.coin_sort_data = d
end

return progression
