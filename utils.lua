local utils = {}
-- an iterator to go through all coins in all boxes bi, ci, color 
function utils.each_coin(boxes)
  local bi, ci = 1, 0
  return function()
    while bi <= #boxes do
      ci = ci + 1
      if ci <= #boxes[bi] then
        return bi, ci, boxes[bi][ci]
      end
      bi, ci = bi + 1, 0
    end
  end
end

function utils.debug_stuff1()
  if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
  end
end

function utils.debug_stuff2()
  local love_errorhandler = love.errorhandler
  function love.errorhandler(msg)
    if lldebugger then
      error(msg, 2)
    else
      return love_errorhandler(msg)
    end
  end
end

return utils