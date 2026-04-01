-- arena_chains.lua
-- Static item chain and generator definitions for the Merge Arena.
-- 12 chains: 6 main (with generators) + 6 sub-chains (produced by generators).
-- Pure data module, no runtime state.

local chains = {}

-- Ordered list of all chain IDs
local CHAIN_IDS = {"Ch", "Cu", "He", "Bl", "Ki", "Ta", "Me", "Da", "Ba", "De", "So", "Be"}

-- Generator drop level probabilities by offset above threshold
-- offset = gen_level - generator_threshold
local GEN_DROP_PROBS = {
  [0] = { {1, 1.0} },
  [1] = { {1, 0.70}, {2, 0.30} },
  [2] = { {1, 0.40}, {2, 0.40}, {3, 0.20} },
  [3] = { {1, 0.25}, {2, 0.35}, {3, 0.40} },
  [4] = { {1, 0.15}, {2, 0.30}, {3, 0.55} },
  [5] = { {1, 0.10}, {2, 0.25}, {3, 0.65} },
  [6] = { {1, 0.05}, {2, 0.20}, {3, 0.75} },
}

local CHAIN_DATA = {
  -- === MAIN CHAINS (items + generators) ===

  Ch = {
    name = "Chill",
    color = {0.4, 0.85, 1.0},
    generator_threshold = 4,
    generator_name = "Fridge",
    items = {
      "Ice Block", "Ice Cubes", "Bucket of Ice",
      "Fridge I", "Fridge II", "Fridge III", "Fridge IV",
      "Fridge V", "Fridge VI", "Fridge VII",
    },
    produces = {
      {chain_id = "Me", max_level = 3, weight = 3},
      {chain_id = "Da", max_level = 3, weight = 3},
      {chain_id = "Ch", max_level = 1, weight = 1},
    },
  },

  Cu = {
    name = "Cupboard",
    color = {0.7, 0.5, 0.3},
    generator_threshold = 4,
    generator_name = "Cupboard",
    items = {
      "Bin", "Utensil Bin", "Tackle Box",
      "Cupboard I", "Cupboard II", "Cupboard III",
      "Cupboard IV", "Cupboard V", "Cupboard VI",
    },
    produces = {
      {chain_id = "Ta", max_level = 2, weight = 2},
      {chain_id = "Ki", max_level = 2, weight = 2},
      {chain_id = "Bl", max_level = 1, weight = 1},
      {chain_id = "He", max_level = 1, weight = 1},
    },
  },

  He = {
    name = "Heating",
    color = {0.9, 0.35, 0.2},
    generator_threshold = 4,
    generator_name = "Toaster",
    items = {
      "Heating Element", "Knob", "Plunger",
      "Toaster I", "Toaster II", "Toaster III", "Toaster IV",
      "Toaster V", "Toaster VI", "Toaster VII",
    },
    produces = {
      {chain_id = "Ba", max_level = 2, weight = 1},
    },
  },

  Bl = {
    name = "Blending",
    color = {0.7, 0.4, 0.9},
    generator_threshold = 4,
    generator_name = "Blender",
    items = {
      "Sieve", "Chasen", "Steel Whisk",
      "Blender I", "Blender II", "Blender III", "Blender IV",
      "Blender V", "Blender VI", "Blender VII",
    },
    produces = {
      {chain_id = "De", max_level = 3, weight = 1},
    },
  },

  Ki = {
    name = "Kitchenware",
    color = {0.3, 0.75, 0.3},
    generator_threshold = 7,
    generator_name = "Pot",
    items = {
      "Kitchen Knife", "Tenderizer", "Spatula", "Tongs", "Ladle", "Sauce Pan",
      "Pot",
    },
    produces = {
      {chain_id = "So", max_level = 1, weight = 1},
    },
  },

  Ta = {
    name = "Tableware",
    color = {0.3, 0.5, 0.9},
    generator_threshold = 7,
    generator_name = "Carafe",
    items = {
      "Napkin", "Spoon", "Fork", "Butter Knife", "Plate", "Cup",
      "Carafe",
    },
    produces = {
      {chain_id = "Be", max_level = 2, weight = 1},
    },
  },

  -- === SUB-CHAINS (produced by generators, no generators of their own) ===

  Me = {
    name = "Meat",
    color = {0.8, 0.25, 0.2},
    items = {
      "Smoked Meat", "Sausage", "Meatballs", "BBQ Wings", "Nuggets",
      "Drum Stick", "Steak", "Schnitzel", "Schweinhaxe", "Ham",
      "Spare Ribs", "Roast Turkey",
    },
  },

  Da = {
    name = "Dairy",
    color = {0.95, 0.85, 0.4},
    items = {
      "Egg", "Sunny Side Up", "Scrambled Eggs", "Glass of Milk", "Milk Bottle",
      "Farmer's Can", "Sour Cream", "Soft Cheese", "Mozzarella", "Braided Cheese",
      "Aged Cheddar", "Cheese Wheel",
    },
  },

  Ba = {
    name = "Bakery",
    color = {0.85, 0.65, 0.3},
    items = {
      "Wheat Flour", "Flour Bag", "Bread Slice", "Pretzel", "Croissant",
      "Bagel", "Loaf of Bread", "Ciabatta", "Challah", "Mouse Loaf",
    },
  },

  De = {
    name = "Desert",
    color = {0.9, 0.5, 0.7},
    items = {
      "Brown Sugar", "Sugar Cubes", "Chocolate", "Truffles", "Doughnut",
      "Eclair", "Strudel", "Cupcake", "Pie", "Devil Cake Piece",
      "Tiramisu", "Creme Brulee",
    },
  },

  So = {
    name = "Soups",
    color = {0.5, 0.7, 0.2},
    items = {
      "Noodle Soup", "Clam Chowder", "Gumbo", "Onion Soup", "Chili",
      "Strawberry Soup",
    },
  },

  Be = {
    name = "Beverages",
    color = {0.2, 0.7, 0.7},
    items = {
      "Glass of Water", "Cup of Tea", "Coffee", "Orange Juice", "Lemonade",
      "Merge Cola",
    },
  },
}

-- Build reverse lookup: item name -> {chain_id, level}
local NAME_LOOKUP = {}
for chain_id, chain in pairs(CHAIN_DATA) do
  for level, name in ipairs(chain.items) do
    NAME_LOOKUP[name] = {chain_id = chain_id, level = level}
  end
end

-- === PUBLIC API ===

function chains.getChain(chain_id)
  return CHAIN_DATA[chain_id]
end

function chains.getAllChains()
  return CHAIN_DATA
end

function chains.getAllChainIds()
  return CHAIN_IDS
end

function chains.getColor(chain_id)
  local chain = CHAIN_DATA[chain_id]
  return chain and chain.color or {0.5, 0.5, 0.5}
end

function chains.getItemName(chain_id, level)
  local chain = CHAIN_DATA[chain_id]
  if not chain or not chain.items[level] then return nil end
  return chain.items[level]
end

function chains.getMaxLevel(chain_id)
  local chain = CHAIN_DATA[chain_id]
  if not chain then return 0 end
  return #chain.items
end

function chains.isGenerator(chain_id, level)
  local chain = CHAIN_DATA[chain_id]
  if not chain or not chain.generator_threshold then return false end
  return level >= chain.generator_threshold
end

function chains.getGeneratorName(chain_id)
  local chain = CHAIN_DATA[chain_id]
  return chain and chain.generator_name
end

function chains.getProduces(chain_id)
  local chain = CHAIN_DATA[chain_id]
  return chain and chain.produces
end

-- Roll a drop from a generator. Returns {chain_id, level} or nil.
function chains.rollDrop(chain_id, gen_level)
  local chain = CHAIN_DATA[chain_id]
  if not chain or not chain.produces or not chain.generator_threshold then return nil end

  -- Pick target chain (weighted random)
  local produces = chain.produces
  local total_weight = 0
  for _, p in ipairs(produces) do
    total_weight = total_weight + p.weight
  end

  local r = math.random() * total_weight
  local chosen = produces[1]
  local cumulative = 0
  for _, p in ipairs(produces) do
    cumulative = cumulative + p.weight
    if r <= cumulative then
      chosen = p
      break
    end
  end

  -- Roll drop level based on generator level offset
  local offset = gen_level - chain.generator_threshold
  if offset < 0 then offset = 0 end
  local probs = GEN_DROP_PROBS[offset] or GEN_DROP_PROBS[6]

  local r2 = math.random()
  local drop_level = 1
  local cum2 = 0
  for _, entry in ipairs(probs) do
    cum2 = cum2 + entry[2]
    if r2 <= cum2 then
      drop_level = entry[1]
      break
    end
  end

  -- Cap at max_level for the chosen produce chain
  if drop_level > chosen.max_level then
    drop_level = chosen.max_level
  end

  return {chain_id = chosen.chain_id, level = drop_level}
end

-- Parse a code like "Ch3" or "He10" into {chain_id, level}
function chains.parseItemCode(code)
  if not code or code == "." then return nil end
  local chain_id = code:sub(1, 2)
  local level = tonumber(code:sub(3))
  if not CHAIN_DATA[chain_id] or not level then return nil end
  return {chain_id = chain_id, level = level}
end

-- Look up item by display name. Returns {chain_id, level} or nil.
function chains.lookupByName(name)
  return NAME_LOOKUP[name]
end

return chains
