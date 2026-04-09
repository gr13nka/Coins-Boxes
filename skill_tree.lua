-- skill_tree.lua
-- PoE-style skill tree with spendable Stars. Pure data module (no drawing).
-- Replaces the old linear milestone system with an interconnected node web.
-- Nodes are progressively revealed: only unlocked nodes and their neighbors are visible.

local progression = require("progression")

local skill_tree = {}

-- Node definitions: id, name, type, cost, description, grid position, connections
-- All positions are integers on a clean grid. Tree grows upward from start.
-- Only numeric bonuses — no generator unlocks (all generators available from start).
local NODES = {
  -- Center (always owned)
  start = {
    name = "Core Mastery", type = "start", cost = 0,
    desc = "Starting point of the skill tree",
    x = 0, y = 0,
    connections = {"ffuel"},
  },

  -- Gateway
  ffuel = {
    name = "Fuel Tank", type = "small", cost = 2,
    desc = "Fuel cap +10 (50 -> 60)",
    x = 0, y = -1,
    connections = {"start", "drpc", "bp20", "gch1", "grtk", "exbg"},
  },

  -- Row -2: five branches from ffuel
  drpc = {
    name = "Fuel Surge+", type = "notable", cost = 6,
    desc = "Fuel Surge drops give +3 extra fuel",
    x = -3, y = -2,
    connections = {"ffuel", "gch1", "dchc"},
  },
  gch1 = {
    name = "Gen Charges I", type = "small", cost = 3,
    desc = "All generators get +3 max charges",
    x = -1, y = -2,
    connections = {"ffuel", "drpc", "mbon5"},
  },
  bp20 = {
    name = "Bag Power I", type = "small", cost = 2,
    desc = "Bag deals give 20 coins (was 18)",
    x = 0, y = -2,
    connections = {"ffuel", "cspc"},
  },
  grtk = {
    name = "Token Finder", type = "small", cost = 3,
    desc = "Generator Token drop chance +2.5%",
    x = 1, y = -2,
    connections = {"ffuel", "arsp"},
  },
  exbg = {
    name = "Extra Bags", type = "small", cost = 2,
    desc = "Max queued free bags: 2 -> 3",
    x = 3, y = -2,
    connections = {"ffuel", "drpb"},
  },

  -- Row -3
  dchc = {
    name = "Chest Crafter", type = "notable", cost = 7,
    desc = "All chests get +2 tap charges",
    x = -3, y = -3,
    connections = {"drpc", "mbon5", "fbon"},
  },
  mbon5 = {
    name = "Merge Fuel I", type = "notable", cost = 6,
    desc = "L5+ merges give +1 bonus Fuel",
    x = -1, y = -3,
    connections = {"gch1", "dchc", "gch2", "csmr"},
  },
  cspc = {
    name = "Quick Deals", type = "small", cost = 2,
    desc = "+2 bonus coins per bag deal",
    x = 0, y = -3,
    connections = {"bp20", "csmr", "stas"},
  },
  stas = {
    name = "Stash+", type = "small", cost = 3,
    desc = "+1 Stash slot (8 -> 9)",
    x = 1, y = -3,
    connections = {"cspc", "arsp", "csfr"},
  },
  arsp = {
    name = "Order Stars+", type = "small", cost = 3,
    desc = "+1 star per order completion",
    x = 2, y = -3,
    connections = {"grtk", "stas", "drpb", "ardp"},
  },
  drpb = {
    name = "Chest Finder", type = "small", cost = 2,
    desc = "+3% chest drop chance (all levels)",
    x = 3, y = -3,
    connections = {"exbg", "arsp", "fbag1"},
  },

  -- Row -4
  fbon = {
    name = "Lucky Taps", type = "notable", cost = 7,
    desc = "20% chance generator tap costs 0 Fuel",
    x = -3, y = -4,
    connections = {"dchc", "gch2", "bp22"},
  },
  gch2 = {
    name = "Gen Charges II", type = "small", cost = 3,
    desc = "All generators get +3 more charges (+6 total)",
    x = -1, y = -4,
    connections = {"mbon5", "fbon", "csfr", "mbon4", "bp22"},
  },
  csmr = {
    name = "Early Fuel", type = "small", cost = 3,
    desc = "Level 3 merges give +1 Fuel",
    x = 0, y = -4,
    connections = {"cspc", "mbon5", "csfr"},
  },
  csfr = {
    name = "Free Bag Speed", type = "small", cost = 3,
    desc = "Free bag timer: 720s -> 600s",
    x = 1, y = -4,
    connections = {"csmr", "stas", "gch2", "ardp"},
  },
  ardp = {
    name = "Level Stars+", type = "small", cost = 3,
    desc = "+2 stars per level completion",
    x = 2, y = -4,
    connections = {"arsp", "csfr", "mbon4", "stash2"},
  },
  fbag1 = {
    name = "Fast Recharge I", type = "small", cost = 3,
    desc = "Generator recharge: 600s -> 540s",
    x = 3, y = -4,
    connections = {"drpb", "fbag2"},
  },

  -- Row -5
  bp22 = {
    name = "Bag Power II", type = "notable", cost = 8,
    desc = "Bag deals give 22 coins",
    x = -2, y = -5,
    connections = {"fbon", "gch2"},
  },
  mbon4 = {
    name = "Merge Fuel II", type = "notable", cost = 8,
    desc = "L4+ merges give +1 bonus Fuel (stacks)",
    x = 0, y = -5,
    connections = {"gch2", "ardp", "surge"},
  },
  stash2 = {
    name = "Grand Stash", type = "keystone", cost = 15,
    desc = "+2 Stash slots",
    x = 1, y = -5,
    connections = {"ardp", "surge", "bp24", "poison"},
  },
  fbag2 = {
    name = "Fast Recharge II", type = "notable", cost = 7,
    desc = "Generator recharge: 540s -> 420s",
    x = 3, y = -5,
    connections = {"fbag1", "bp24"},
  },

  -- Row -6
  surge = {
    name = "Star Surge", type = "keystone", cost = 18,
    desc = "All star gains +50%",
    x = 0, y = -6,
    connections = {"mbon4", "stash2", "poison"},
  },
  bp24 = {
    name = "Bag Power III", type = "keystone", cost = 15,
    desc = "Bag deals give 24 coins",
    x = 2, y = -6,
    connections = {"fbag2", "stash2"},
  },

  -- Row -7
  poison = {
    name = "Poison Coins", type = "keystone", cost = 25,
    desc = "Adds poison coins — risky but powerful",
    x = 0, y = -7,
    connections = {"surge", "stash2"},
    coming_soon = true,
  },
}

-- Runtime state
local unlocked = {}
local stars_spent = 0

--------------------------------------------------------------------------------
-- Core API
--------------------------------------------------------------------------------

function skill_tree.init()
  local d = progression.getSkillTreeData()
  unlocked = d.unlocked or {start = true}
  stars_spent = d.stars_spent or 0

  -- Ensure start is always unlocked
  unlocked.start = true

  -- Migration: if player has stars but only start unlocked, convert old milestones
  local resources = require("resources")
  local total_stars = resources.getStars()
  if total_stars > 0 then
    local count = 0
    for _ in pairs(unlocked) do count = count + 1 end
    if count <= 1 then
      skill_tree.migrateFromMilestones(total_stars)
    end
  end
end

function skill_tree.save()
  progression.setSkillTreeData({
    unlocked = unlocked,
    stars_spent = stars_spent,
  })
end

-- Sync state to progression without disk write (for batched saves)
function skill_tree.sync()
  progression.setSkillTreeData({
    unlocked = unlocked,
    stars_spent = stars_spent,
  })
end

function skill_tree.isUnlocked(node_id)
  return unlocked[node_id] == true
end

-- A node is visible if it's unlocked or any of its neighbors is unlocked
function skill_tree.isVisible(node_id)
  if unlocked[node_id] then return true end
  local node = NODES[node_id]
  if not node then return false end
  for _, conn_id in ipairs(node.connections) do
    if unlocked[conn_id] then return true end
  end
  return false
end

function skill_tree.canUnlock(node_id)
  local node = NODES[node_id]
  if not node then return false end
  if unlocked[node_id] then return false end
  if node.coming_soon then return false end

  -- Check star cost
  local resources = require("resources")
  if resources.getStars() < node.cost then return false end

  -- Check adjacency: at least one connected node must be unlocked
  for _, conn_id in ipairs(node.connections) do
    if unlocked[conn_id] then return true end
  end
  return false
end

function skill_tree.unlock(node_id)
  if not skill_tree.canUnlock(node_id) then return false end

  local node = NODES[node_id]
  local resources = require("resources")

  -- Spend stars
  resources.spendStarsNoSave(node.cost)
  stars_spent = stars_spent + node.cost
  unlocked[node_id] = true

  -- Save everything
  skill_tree.sync()
  resources.sync()
  progression.save()

  return true
end

function skill_tree.getNodes()
  return NODES
end

function skill_tree.getUnlocked()
  return unlocked
end

function skill_tree.getNode(node_id)
  return NODES[node_id]
end

--------------------------------------------------------------------------------
-- Query API — replaces all old milestone threshold checks
--------------------------------------------------------------------------------

-- All generators are always unlocked (no skill tree gating)
function skill_tree.isGeneratorUnlocked(_chain_id)
  return true
end

function skill_tree.getBagCoins()
  local base = 18
  if unlocked.bp24 then return 24
  elseif unlocked.bp22 then return 22
  elseif unlocked.bp20 then return 20
  end
  return base
end

function skill_tree.getExtraDealCoins()
  return unlocked.cspc and 2 or 0
end

function skill_tree.getMergeBonusFuel(new_number)
  local bonus = 0
  if unlocked.mbon4 and new_number >= 4 then bonus = bonus + 1 end
  if unlocked.mbon5 and new_number >= 5 then bonus = bonus + 1 end
  return bonus
end

function skill_tree.getL3FuelBonus()
  return unlocked.csmr and 1 or 0
end

function skill_tree.getFuelCap()
  local base = 50
  if unlocked.ffuel then base = base + 10 end
  return base
end

function skill_tree.getStashSize()
  local base = 8
  if unlocked.stas then base = base + 1 end
  if unlocked.stash2 then base = base + 2 end
  return base
end

function skill_tree.getGenChargeBonus()
  local bonus = 0
  if unlocked.gch1 then bonus = bonus + 3 end
  if unlocked.gch2 then bonus = bonus + 3 end
  return bonus
end

function skill_tree.getGenRechargeTime()
  local base = 600
  if unlocked.fbag1 then base = base - 60 end
  if unlocked.fbag2 then base = base - 120 end
  return base
end

function skill_tree.getFreeBagInterval()
  local base = 720
  if unlocked.csfr then base = base - 120 end
  return base
end

function skill_tree.getMaxQueuedFree()
  local base = 2
  if unlocked.exbg then base = base + 1 end
  return base
end

function skill_tree.getChestChargeBonus()
  return unlocked.dchc and 2 or 0
end

function skill_tree.getFuelSurgeBonus()
  return unlocked.drpc and 3 or 0
end

function skill_tree.getGenTokenChanceBonus()
  return unlocked.grtk and 0.025 or 0
end

function skill_tree.getChestChanceBonus()
  return unlocked.drpb and 0.03 or 0
end

function skill_tree.getOrderStarBonus()
  return unlocked.arsp and 1 or 0
end

function skill_tree.getLevelStarBonus()
  return unlocked.ardp and 2 or 0
end

function skill_tree.getFreeFuelTapChance()
  return unlocked.fbon and 0.20 or 0
end

function skill_tree.getStarMultiplier()
  return unlocked.surge and 1.5 or 1.0
end

--------------------------------------------------------------------------------
-- Migration from old milestone system
--------------------------------------------------------------------------------

function skill_tree.migrateFromMilestones(total_stars)
  -- Old milestones mapped to tree nodes (in threshold order)
  local MIGRATION_MAP = {
    {threshold = 10,  nodes = {"ffuel"}},
    {threshold = 20,  nodes = {"bp20"}},
    {threshold = 35,  nodes = {"gch1"}},
    {threshold = 50,  nodes = {"mbon5"}},
    {threshold = 75,  nodes = {"drpc"}},
    {threshold = 100, nodes = {"bp22"}},
    {threshold = 130, nodes = {"gch2"}},
    {threshold = 170, nodes = {"mbon4"}},
    {threshold = 220, nodes = {"stas"}},
    {threshold = 280, nodes = {"bp24"}},
  }

  -- Determine which target nodes the player earned under old system
  local targets = {}
  for _, mapping in ipairs(MIGRATION_MAP) do
    if total_stars >= mapping.threshold then
      for _, node_id in ipairs(mapping.nodes) do
        targets[node_id] = true
      end
    end
  end

  -- BFS to find all path nodes needed to connect targets to start
  local to_unlock = {start = true}
  for node_id in pairs(targets) do
    to_unlock[node_id] = true
  end

  -- For each target, ensure a path exists from start by unlocking intermediaries
  for target_id in pairs(targets) do
    -- BFS from start to target
    local queue = {"start"}
    local visited = {start = true}
    local parent = {}
    local found = false

    local qi = 1
    while qi <= #queue do
      local current = queue[qi]
      qi = qi + 1

      if current == target_id then
        found = true
        break
      end

      local node = NODES[current]
      if node then
        for _, conn_id in ipairs(node.connections) do
          if not visited[conn_id] and NODES[conn_id] then
            visited[conn_id] = true
            parent[conn_id] = current
            queue[#queue + 1] = conn_id
          end
        end
      end
    end

    -- Trace path and unlock intermediaries
    if found then
      local curr = target_id
      while curr and curr ~= "start" do
        to_unlock[curr] = true
        curr = parent[curr]
      end
    end
  end

  -- Calculate total cost
  local total_cost = 0
  for node_id in pairs(to_unlock) do
    total_cost = total_cost + (NODES[node_id].cost or 0)
  end

  -- Apply unlocks
  unlocked = to_unlock
  stars_spent = total_cost

  -- Deduct stars
  local resources = require("resources")
  local remaining = math.max(0, total_stars - total_cost)
  local to_deduct = total_stars - remaining
  if to_deduct > 0 then
    resources.spendStarsNoSave(to_deduct)
  end

  -- Save
  skill_tree.sync()
  resources.sync()
  progression.save()
end

return skill_tree
