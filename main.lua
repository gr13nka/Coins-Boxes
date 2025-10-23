if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
	require("lua/lldebugger").start()
end

-- slayout constants
local TOP_Y = 140 -- top of the stacks
local COIN_R = 18 -- coin radius
local ROW_STEP = COIN_R * 2 + 8

function love.load()
	local boxes = { {}, {}, {} }
	-- box number
	coins = { color = "green", box = 1 }
	colors = { "green", "red", "blue" }

	for i = 1, 10, 1 do
		table.insert(coins, { color = colors[math.random(#colors)], box = math.random(#boxes) })
	end

	for i, coin in ipairs(coins) do
		print(i, coin.color, coin.box)
	end
	print("++++++++++++++++++++++++++++++++++")
	table.sort(coins, function(a, b)
		return a.box < b.box
	end)

	for i, coin in ipairs(coins) do
		print(i, coin.color, coin.box)
	end
end

function sort_coins() end

function love.draw()
	for i, v in ipairs(coins) do
		local cnt = 1
		local column_cnt = 1
		print("------------" .. v.color[i])
		love.graphics.circle("fill", COLUMN_STEP * column_cnt, ROW_STEP * cnt, COIN_R)

		-- draw all coins from each box
		if v.box[i] ~= v.box[i + 1] then
			cnt = 0
			row_cnt = row_cnt + 30
		end
		cnt = cnt + 10
	end

	-- sort_coins()

	-- love.graphics.setColor(coins.color[i])
	-- love.graphics.circle("fill", )
end
