-- bags.lua
-- Coin bag inventory + free bag timer. Pure data module (no drawing).
-- Bags are consumed in Coin Sort to deal coins. Free bags generate on a timer.

local progression = require("progression")

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

-- Tick free bag timer. Call from update(dt) on any active screen.
-- Returns true if a new free bag was generated.
function bags.update(dt)
  if free_bags_queued >= MAX_QUEUED_FREE then
    return false
  end

  free_bag_timer = free_bag_timer + dt
  if free_bag_timer >= FREE_BAG_INTERVAL then
    free_bag_timer = free_bag_timer - FREE_BAG_INTERVAL
    free_bags_queued = math.min(free_bags_queued + 1, MAX_QUEUED_FREE)
    bags.save()
    return true
  end
  return false
end

-- Use a bag: returns coin count if available, nil if no bags
function bags.useBag()
  -- Prioritize queued free bags
  if free_bags_queued > 0 then
    free_bags_queued = free_bags_queued - 1
    bags.save()
    return FREE_BAG_COINS
  end

  if bags_count > 0 then
    bags_count = bags_count - 1
    bags.save()
    return FREE_BAG_COINS
  end

  return nil
end

-- Add bags (from arena order rewards)
function bags.addBags(n)
  bags_count = bags_count + n
  bags.save()
end

-- Getters
function bags.getBags() return bags_count end
function bags.getFreeBagsQueued() return free_bags_queued end
function bags.getTotalAvailable() return bags_count + free_bags_queued end
function bags.getFreeTimer() return free_bag_timer end
function bags.getFreeInterval() return FREE_BAG_INTERVAL end
function bags.getFreeBagCoins() return FREE_BAG_COINS end

return bags
