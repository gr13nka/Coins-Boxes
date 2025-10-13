-- layout constants
local COL_X0 = 100 -- x of box #1
local COL_GAP = 160 -- horizontal distance between columns
local TOP_Y = 140 -- top of the stacks
local R = 18 -- coin radius
local ROW_STEP = R * 2 + 8

function love.load()
	local boxes = { {}, {}, {} }

	colors = {
		{ name = "red", rgb = { 1, 0.2, 0.2 } },
		{ name = "green", rgb = { 0.2, 0.9, 0.2 } },
		{ name = "blue", rgb = { 0.2, 0.4, 1 } },
	}

	coins = { clr = {}, box = {} } -- coins {{color, box}, ..}

	for i = 1, 10, 1 do
		coins.clr[i] = colors[math.random(#colors)].name
		coins.box[i] = math.random(#boxes)
		print(coins.clr[i])
		print(coins.box[i])
	end
end

function love.draw()
	-- love.graphics.draw(button_merge, 0, 100)
	-- love.graphics.draw(button_add_coins, 0, 100)
	--
	-- love.graphics.draw(box1_img, 0, 100)
	-- love.graphics.draw(box2_img, 200, 100)
	-- love.graphics.draw(box3_img, 400, 100)
end
