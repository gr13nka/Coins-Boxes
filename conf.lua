-- Start debugger if launched from VS Code debug adapter (must run before love.conf)
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
  require("lldebugger").start()
end

function love.conf(t)
  t.console = os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") ~= "1" -- console conflicts with debugger stdio
  t.window.resizable  = true
  t.window.borderless = false
  t.window.minwidth   = 160
  t.window.minheight  = 500
  t.highdpi           = true -- Enable for sharp mobile rendering
  t.window.usedpiscale = true -- Proper DPI scaling
  t.window.vsync      = 1
  t.window.x = 1600 -- The x-coordinate of the window's position in the specified display (number)
  t.window.y = 900

  -- Mobile-specific settings
  t.accelerometerjoystick = false -- Disable accelerometer as joystick
  if t.graphics then
    t.graphics.gammacorrect = false -- Better performance on mobile
  end
end
