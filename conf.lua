function love.conf(t)
  t.console = false -- open a console window on Windows
  t.window.resizable  = false
  t.window.borderless = false   
  t.window.minwidth   = 160
  t.window.minheight  = 500
  t.window.highdpi    = false -- on Retina/HiDPI
  t.window.vsync      = 1
  t.window.x = 1920 -- The x-coordinate of the window's position in the specified display (number)
    t.window.y = nil   
end
