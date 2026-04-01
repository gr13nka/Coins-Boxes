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

return utils