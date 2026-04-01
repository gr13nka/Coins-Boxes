-- arena_orders.lua
-- Level-based order system for the Merge Arena. Pure data module (no drawing).
-- 10 levels of static orders. Complete all orders in a level to advance.

local orders = {}

local MAX_VISIBLE = 3
local current_level = 1
local completed_in_level = {}  -- {order_id = true}

-- Helper to build a requirement entry
local function req(chain_id, level, count)
  return {chain_id = chain_id, level = level, count = count or 1}
end

-- Helper to build a reward item entry
local function rw(chain_id, level)
  return {chain_id = chain_id, level = level}
end

-- === STATIC ORDER DATA (Season 1, Levels 1-10) ===

local ORDER_LEVELS = {
  -- LEVEL 1 (3 orders)
  [1] = {
    orders = {
      {
        id = "L1_1", character = "Meryl",
        requirements = { req("Da", 2) },
        xp_reward = 2,
        item_rewards = { rw("Me", 1) },
      },
      {
        id = "L1_2", character = "Murray",
        requirements = { req("Da", 3), req("Me", 2) },
        xp_reward = 2,
        item_rewards = { rw("Me", 1) },
      },
      {
        id = "L1_3", character = "Marcus",
        requirements = { req("Me", 1) },
        xp_reward = 2,
        item_rewards = { rw("Ch", 1), rw("Da", 1), rw("Da", 1) },
      },
    },
    level_rewards = {
      xp = 4,
      items = { rw("Ch", 3), rw("Ch", 2), rw("Ch", 1) },
    },
  },

  -- LEVEL 2 (4 orders)
  [2] = {
    orders = {
      {
        id = "L2_1", character = "Meryl",
        requirements = { req("Me", 4) },
        xp_reward = 2,
        item_rewards = { rw("Cu", 1), rw("Ch", 3) },
      },
      {
        id = "L2_2", character = "Murray",
        requirements = { req("Ta", 3), req("Ki", 2) },
        xp_reward = 3,
        item_rewards = { rw("Ch", 1), rw("Cu", 1) },
      },
      {
        id = "L2_3", character = "Marcus",
        requirements = { req("Me", 5), req("Da", 4) },
        xp_reward = 8,
        item_rewards = { rw("Cu", 1), rw("Ch", 2), rw("Cu", 2) },
      },
      {
        id = "L2_4", character = "Mike",
        requirements = { req("Da", 4), req("Ta", 3) },
        xp_reward = 7,
        item_rewards = { rw("Ch", 2), rw("Bl", 2) },
      },
    },
    level_rewards = {
      xp = 5,
      items = { rw("Bl", 1), rw("Cu", 2) },
    },
  },

  -- LEVEL 3 (4 orders)
  [3] = {
    orders = {
      {
        id = "L3_1", character = "Meryl",
        requirements = { req("De", 4) },
        xp_reward = 3,
        item_rewards = { rw("Ch", 2), rw("Cu", 2), rw("Ki", 2) },
      },
      {
        id = "L3_2", character = "Mike",
        requirements = { req("Ki", 1), req("Ki", 2, 2) },
        xp_reward = 3,
        item_rewards = { rw("Cu", 1), rw("Cu", 2), rw("De", 3) },
      },
      {
        id = "L3_3", character = "Marcus",
        requirements = { req("Da", 5, 2), req("Ki", 1) },
        xp_reward = 3,
        item_rewards = { rw("Ch", 1), rw("Cu", 1), rw("Bl", 2) },
      },
      {
        id = "L3_4", character = "Midori",
        requirements = { req("Me", 5), req("Ki", 4) },
        xp_reward = 3,
        item_rewards = { rw("Ch", 3), rw("Bl", 3) },
      },
    },
    level_rewards = {
      xp = 9,
      items = { rw("He", 3) },
    },
  },

  -- LEVEL 4 (4 orders)
  [4] = {
    orders = {
      {
        id = "L4_1", character = "Midori",
        requirements = { req("Da", 6), req("De", 3, 2) },
        xp_reward = 4,
        item_rewards = { rw("He", 1), rw("Bl", 2) },
      },
      {
        id = "L4_2", character = "Meryl",
        requirements = { req("Me", 5), req("Ba", 3) },
        xp_reward = 5,
        item_rewards = { rw("He", 1), rw("Bl", 1) },
      },
      {
        id = "L4_3", character = "Mike",
        requirements = { req("Ba", 3, 2), req("Ta", 5) },
        xp_reward = 5,
        item_rewards = { rw("Cu", 2), rw("Bl", 2) },
      },
      {
        id = "L4_4", character = "Murray",
        requirements = { req("Me", 6), req("Ki", 4) },
        xp_reward = 5,
        item_rewards = { rw("Ch", 2) },
      },
    },
    level_rewards = {
      xp = 5,
      items = { rw("Ch", 2), rw("He", 3), rw("Bl", 1) },
    },
  },

  -- LEVEL 5 (5 orders)
  [5] = {
    orders = {
      {
        id = "L5_1", character = "Marcus",
        requirements = { req("Me", 5, 2), req("Ba", 4, 2) },
        xp_reward = 5,
        item_rewards = { rw("Ch", 2), rw("Cu", 1) },
      },
      {
        id = "L5_2", character = "Murray",
        requirements = { req("Da", 6), req("Ta", 5, 2) },
        xp_reward = 5,
        item_rewards = { rw("He", 2), rw("Cu", 2) },
      },
      {
        id = "L5_3", character = "Mike",
        requirements = { req("Da", 7), req("Ki", 3) },
        xp_reward = 10,
        item_rewards = { rw("Bl", 1), rw("Cu", 1) },
      },
      {
        id = "L5_4", character = "Meryl",
        requirements = { req("Me", 7), req("De", 4, 2) },
        xp_reward = 5,
        item_rewards = { rw("Bl", 1), rw("Ch", 2) },
      },
      {
        id = "L5_5", character = "Midori",
        requirements = { req("Da", 7), req("De", 5) },
        xp_reward = 5,
        item_rewards = { rw("Bl", 1), rw("Ch", 1) },
      },
    },
    level_rewards = {
      xp = 5,
      items = { rw("Cu", 3), rw("He", 3) },
    },
  },

  -- LEVEL 6 (6 orders)
  [6] = {
    orders = {
      {
        id = "L6_1", character = "Meryl",
        requirements = { req("Ki", 3), req("Ba", 5, 2) },
        xp_reward = 2,
        item_rewards = { rw("Ch", 1), rw("He", 1) },
      },
      {
        id = "L6_2", character = "Mike",
        requirements = { req("Me", 5, 2), req("De", 5) },
        xp_reward = 2,
        item_rewards = { rw("Cu", 1), rw("Bl", 2) },
      },
      {
        id = "L6_3", character = "Murray",
        requirements = { req("Ba", 6), req("Be", 3) },
        xp_reward = 2,
        item_rewards = { rw("Cu", 1), rw("He", 3) },
      },
      {
        id = "L6_4", character = "Marcus",
        requirements = { req("De", 4), req("Me", 6, 2) },
        xp_reward = 4,
        item_rewards = { rw("Ch", 1), rw("Bl", 2) },
      },
      {
        id = "L6_5", character = "Meryl",
        requirements = { req("Ba", 6), req("Me", 7) },
        xp_reward = 2,
        item_rewards = { rw("Cu", 1), rw("He", 1) },
      },
      {
        id = "L6_6", character = "Murray",
        requirements = { req("Ta", 6), req("Ba", 7) },
        xp_reward = 3,
        item_rewards = { rw("Ch", 1), rw("Cu", 2) },
      },
    },
    level_rewards = {
      xp = 8,
      items = { rw("Bl", 1), rw("He", 3), rw("Ch", 2) },
    },
  },

  -- LEVEL 7 (6 orders)
  [7] = {
    orders = {
      {
        id = "L7_1", character = "Midori",
        requirements = { req("Da", 6, 3), req("Ba", 7) },
        xp_reward = 3,
        item_rewards = { rw("Cu", 1), rw("Ch", 2), rw("He", 3) },
      },
      {
        id = "L7_2", character = "Meryl",
        requirements = { req("Da", 7), req("Ba", 8) },
        xp_reward = 7,
        item_rewards = { rw("Bl", 2), rw("Cu", 1) },
      },
      {
        id = "L7_3", character = "Mike",
        requirements = { req("Ki", 6), req("Me", 7) },
        xp_reward = 5,
        item_rewards = { rw("He", 1), rw("Ch", 2) },
      },
      {
        id = "L7_4", character = "Marcus",
        requirements = { req("Me", 6, 2), req("Be", 4) },
        xp_reward = 3,
        item_rewards = { rw("Ch", 2), rw("Bl", 2) },
      },
      {
        id = "L7_5", character = "Murray",
        requirements = { req("Ki", 5), req("De", 6) },
        xp_reward = 3,
        item_rewards = { rw("Cu", 1), rw("He", 3) },
      },
      {
        id = "L7_6", character = "Mike",
        requirements = { req("Da", 5, 3), req("De", 4, 3) },
        xp_reward = 3,
        item_rewards = { rw("Bl", 2), rw("Cu", 1), rw("He", 1) },
      },
    },
    level_rewards = {
      xp = 9,
      items = { rw("Bl", 1), rw("Cu", 2), rw("Ch", 3) },
    },
  },

  -- LEVEL 8 (7 orders)
  [8] = {
    orders = {
      {
        id = "L8_1", character = "Meryl",
        requirements = { req("Me", 6, 2), req("Ba", 5) },
        xp_reward = 4,
        item_rewards = { rw("He", 1), rw("Ch", 1) },
      },
      {
        id = "L8_2", character = "Mike",
        requirements = { req("Da", 7), req("Ta", 6) },
        xp_reward = 5,
        item_rewards = { rw("Bl", 2), rw("Cu", 1) },
      },
      {
        id = "L8_3", character = "Midori",
        requirements = { req("Ba", 8), req("Ki", 5) },
        xp_reward = 5,
        item_rewards = { rw("Bl", 2), rw("Cu", 1), rw("Ch", 1) },
      },
      {
        id = "L8_4", character = "Marcus",
        requirements = { req("Ba", 6), req("Ki", 5) },
        xp_reward = 5,
        item_rewards = { rw("He", 1), rw("Cu", 1), rw("Ch", 1) },
      },
      {
        id = "L8_5", character = "Mike",
        requirements = { req("Me", 8), req("De", 5) },
        xp_reward = 5,
        item_rewards = { rw("Ch", 1), rw("Bl", 2) },
      },
      {
        id = "L8_6", character = "Midori",
        requirements = { req("Da", 7), req("Ta", 6) },
        xp_reward = 5,
        item_rewards = { rw("Bl", 2), rw("Cu", 1), rw("Ch", 1) },
      },
      {
        id = "L8_7", character = "Marcus",
        requirements = { req("Da", 8), req("Be", 5) },
        xp_reward = 5,
        item_rewards = { rw("Bl", 2), rw("He", 1), rw("Ch", 1) },
      },
    },
    level_rewards = {
      xp = 10,
      items = { rw("Bl", 1), rw("Cu", 3), rw("He", 2) },
    },
  },

  -- LEVEL 9 (7 orders)
  [9] = {
    orders = {
      {
        id = "L9_1", character = "Murray",
        requirements = { req("Ba", 8), req("Ki", 6) },
        xp_reward = 5,
        item_rewards = { rw("Bl", 2), rw("Ch", 2) },
      },
      {
        id = "L9_2", character = "Marcus",
        requirements = { req("De", 5), req("Be", 3) },
        xp_reward = 5,
        item_rewards = { rw("Ch", 2), rw("He", 3) },
      },
      {
        id = "L9_3", character = "Midori",
        requirements = { req("Me", 7), req("Ta", 6) },
        xp_reward = 5,
        item_rewards = { rw("Cu", 1), rw("He", 1), rw("Ch", 1) },
      },
      {
        id = "L9_4", character = "Meryl",
        requirements = { req("Da", 7, 2), req("Ki", 6) },
        xp_reward = 5,
        item_rewards = { rw("Bl", 2), rw("Cu", 2) },
      },
      {
        id = "L9_5", character = "Mike",
        requirements = { req("Me", 7), req("Ba", 7) },
        xp_reward = 5,
        item_rewards = { rw("Ch", 1), rw("Bl", 1) },
      },
      {
        id = "L9_6", character = "Murray",
        requirements = { req("Me", 6), req("De", 7) },
        xp_reward = 5,
        item_rewards = { rw("He", 1), rw("Cu", 1) },
      },
      {
        id = "L9_7", character = "Marcus",
        requirements = { req("Ta", 5), req("De", 4) },
        xp_reward = 5,
        item_rewards = { rw("Cu", 2), rw("Ch", 3) },
      },
    },
    level_rewards = {
      xp = 11,
      items = { rw("Bl", 3), rw("Ch", 2), rw("He", 3) },
    },
  },

  -- LEVEL 10 (7 orders)
  [10] = {
    orders = {
      {
        id = "L10_1", character = "Mike",
        requirements = { req("Ki", 5), req("Me", 7) },
        xp_reward = 5,
        item_rewards = { rw("Bl", 1), rw("Ch", 1), rw("He", 1) },
      },
      {
        id = "L10_2", character = "Murray",
        requirements = { req("Da", 7), req("De", 8) },
        xp_reward = 5,
        item_rewards = { rw("He", 3), rw("Cu", 2), rw("Ch", 1) },
      },
      {
        id = "L10_3", character = "Meryl",
        requirements = { req("Ta", 6), req("De", 5) },
        xp_reward = 5,
        item_rewards = { rw("Bl", 1), rw("He", 3), rw("Cu", 1) },
      },
      {
        id = "L10_4", character = "Midori",
        requirements = { req("Me", 6), req("Ba", 8) },
        xp_reward = 5,
        item_rewards = { rw("Cu", 2), rw("Cu", 1), rw("Bl", 2) },
      },
      {
        id = "L10_5", character = "Midori",
        requirements = { req("Da", 8), req("Ki", 6, 2) },
        xp_reward = 5,
        item_rewards = { rw("Ch", 1), rw("He", 1), rw("Cu", 1) },
      },
      {
        id = "L10_6", character = "Midori",
        requirements = { req("De", 6, 2), req("Be", 5) },
        xp_reward = 5,
        item_rewards = { rw("Ch", 1), rw("Cu", 2), rw("Bl", 1) },
      },
      {
        id = "L10_7", character = "Midori",
        requirements = { req("Da", 6), req("Ba", 7) },
        xp_reward = 5,
        item_rewards = { rw("Bl", 2), rw("He", 1), rw("Cu", 2) },
      },
    },
    level_rewards = {
      xp = 11,
      items = { rw("Bl", 3), rw("Cu", 3), rw("He", 3) },
    },
  },
}

-- === PUBLIC API ===

function orders.init(order_level, completed_set)
  current_level = order_level or 1
  completed_in_level = completed_set or {}
end

-- Returns up to MAX_VISIBLE uncompleted orders from current level
function orders.getVisibleOrders()
  local level_data = ORDER_LEVELS[current_level]
  if not level_data then return {} end

  local visible = {}
  for _, order in ipairs(level_data.orders) do
    if not completed_in_level[order.id] then
      visible[#visible + 1] = order
      if #visible >= MAX_VISIBLE then break end
    end
  end
  return visible
end

function orders.getOrderById(order_id)
  local level_data = ORDER_LEVELS[current_level]
  if not level_data then return nil end
  for _, order in ipairs(level_data.orders) do
    if order.id == order_id then return order end
  end
  return nil
end

-- Mark order completed. Returns {xp_reward, item_rewards}.
function orders.completeOrder(order_id)
  local order = orders.getOrderById(order_id)
  if not order then return nil end
  completed_in_level[order_id] = true
  return {
    xp_reward = order.xp_reward,
    item_rewards = order.item_rewards,
  }
end

function orders.isLevelComplete()
  local level_data = ORDER_LEVELS[current_level]
  if not level_data then return false end
  for _, order in ipairs(level_data.orders) do
    if not completed_in_level[order.id] then return false end
  end
  return true
end

-- Advance to next level. Returns level_rewards or nil if at max.
function orders.advanceLevel()
  local level_data = ORDER_LEVELS[current_level]
  if not level_data then return nil end
  local rewards = level_data.level_rewards

  if current_level >= #ORDER_LEVELS then return nil end
  current_level = current_level + 1
  completed_in_level = {}

  return rewards
end

function orders.getCurrentLevel()
  return current_level
end

function orders.getCompletedSet()
  return completed_in_level
end

function orders.getLevelOrderCount()
  local level_data = ORDER_LEVELS[current_level]
  if not level_data then return 0 end
  return #level_data.orders
end

function orders.getCompletedCount()
  local count = 0
  local level_data = ORDER_LEVELS[current_level]
  if not level_data then return 0 end
  for _, order in ipairs(level_data.orders) do
    if completed_in_level[order.id] then count = count + 1 end
  end
  return count
end

function orders.getMaxLevel()
  return #ORDER_LEVELS
end

-- Returns flat list of all required items from uncompleted orders in current level.
-- Each entry: {chain_id, level}. Duplicated per count (e.g. 2×Me5 = two entries).
function orders.getAllRemainingRequirements()
  local level_data = ORDER_LEVELS[current_level]
  if not level_data then return {} end
  local items = {}
  for _, order in ipairs(level_data.orders) do
    if not completed_in_level[order.id] then
      for _, r in ipairs(order.requirements) do
        for _ = 1, r.count do
          items[#items + 1] = {chain_id = r.chain_id, level = r.level}
        end
      end
    end
  end
  return items
end

return orders
