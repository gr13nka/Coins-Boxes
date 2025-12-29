function love.conf(t)
  t.console = false -- open a console window on Windows
  t.window.resizable  = true  
  t.window.borderless = false   
  t.window.minwidth   = 160
  t.window.minheight  = 500
  t.window.highdpi    = false -- on Retina/HiDPI
  t.window.vsync      = 1
end
