-- bags.lua
-- Coin bag inventory + free bag timer. Pure data module (no drawing).
-- Bags are consumed in Coin Sort to deal coins. Free bags generate on a timer.

local progression = require("progression")
local resources = require("resources")

local bags = {}

local FREE_BAG_INTERVAL = 720   -- 12 minutes in seconds
local FREE_BAG_COINS = 18       -- coins per free bag
local MAX_QUEUED_FREE = 2       -- max free bags in queue
local INITIAL_BAGS = 5          -- bags on fresh start

-- Runtime state
local bags_count = 0
local free_bag_timer = 0
local free_bags_queued = 0

function bags.init()
  local d = progression.getBagsData()
  bags_count = d.bags or INITIAL_BAGS
  free_bag_timer = d.free_bag_timer or 0
  free_bags_queued = d.free_bags_queued or 0
end

function bags.save()
  progression.setBagsData({
    bags = bags_count,
    free_bag_timer = free_bag_timer,
    free_bags_queued = free_bags_queued,
  })
  progression.save()
end

-- Advance free bag timer by offline elapsed seconds, granting any earned bags.
function bags.catchUp(elapsed)
  if elapsed <= 0 then return end
  local st = require("skill_tree")
  local max_free = st.getMaxQueuedFree()
  local interval = st.getFreeBagInterval()

  if free_bags_queued >= max_free then return end

  free_bag_timer = free_bag_timer + elapsed
  local earned = false
  while free_bag_timer >= interval and free_bags_queued < max_free do
    free_bag_timer = free_bag_timer - interval
    free_bags_queued = free_bags_queued + 1
    earned = true
  end
  -- If capped, don't accumulate leftover time beyond one interval
  if free_bags_queued >= max_free then
    free_bag_timer = math.min(free_bag_timer, interval - 1)
  end
  if earned then
    bags.save()
  end
end

-- Tick free bag timer. Call from update(dt) on any active screen.
-- Returns true if a new free bag was generated.
function bags.update(dt)
  local st = require("skill_tree")
  local max_free = st.getMaxQueuedFree()
  local interval = st.getFreeBagInterval()

  if free_bags_queued >= max_free then
    return false
  end

  free_bag_timer = free_bag_timer + dt
  if free_bag_timer >= interval then
    free_bag_timer = free_bag_timer - interval
    free_bags_queued = math.min(free_bags_queued + 1, max_free)
    bags.save()
    return true
  end
  return false
end

-- Bag power: coins per bag from skill tree upgrades + deal bonus
function bags.getBagCoins()
  local st = require("skill_tree")
  return st.getBagCoins() + st.getExtraDealCoins()
end

-- Use a bag: returns coin count if available, nil if no bags
function bags.useBag()
  local coins = bags.getBagCoins()
  -- Prioritize queued free bags
  if free_bags_queued > 0 then
    free_bags_queued = free_bags_queued - 1
    bags.save()
    return coins
  end

  if bags_count > 0 then
    bags_count = bags_count - 1
    bags.save()
    return coins
  end

  return nil
end

-- Add bags (from arena order rewards)
function bags.addBags(n)
  bags_count = bags_count + n
  bags.save()
end

-- Add bags without saving (caller handles save via bags.sync + progression.save)
function bags.addBagsNoSave(n)
  bags_count = bags_count + n
end

-- Push bags state to progression without writing to disk
function bags.sync()
  progression.setBagsData({
    bags = bags_count,
    free_bag_timer = free_bag_timer,
    free_bags_queued = free_bags_queued,
  })
end

-- Getters
function bags.getBags() return bags_count end
function bags.getFreeBagsQueued() return free_bags_queued end
function bags.getTotalAvailable() return bags_count + free_bags_queued end
function bags.getFreeTimer() return free_bag_timer end
function bags.getFreeInterval()
  local st = require("skill_tree")
  return st.getFreeBagInterval()
end
function bags.getFreeBagCoins() return FREE_BAG_COINS end

return bags
