function love.conf(t)
  t.console = false -- open a console window on Windows
  t.window.resizable  = true
  t.window.borderless = false
  t.window.minwidth   = 160
  t.window.minheight  = 500
  t.window.highdpi    = true -- Enable for sharp mobile rendering
  t.window.usedpiscale = true -- Proper DPI scaling
  t.window.vsync      = 1
  t.window.x = 1600 -- The x-coordinate of the window's position in the specified display (number)
  t.window.y = 900

  -- Mobile-specific settings
  t.accelerometerjoystick = false -- Disable accelerometer as joystick
  t.gammacorrect = false -- Better performance on mobile
end
