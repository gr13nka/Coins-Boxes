-- mobile.lua
-- Mobile-specific utilities: platform detection, haptic feedback, safe areas

local mobile = {}

-- Platform detection
function mobile.isMobile()
  local os = love.system.getOS()
  return os == "Android" or os == "iOS"
end

function mobile.isAndroid()
  return love.system.getOS() == "Android"
end

function mobile.isiOS()
  return love.system.getOS() == "iOS"
end

-- Haptic feedback (vibration)
-- Duration is in seconds
function mobile.vibrate(duration)
  if love.system.vibrate then
    love.system.vibrate(duration or 0.05)
  end
end

-- Preset vibration patterns
function mobile.vibratePickup()
  mobile.vibrate(0.02)
end

function mobile.vibrateDrop()
  mobile.vibrate(0.04)
end

function mobile.vibrateMerge()
  mobile.vibrate(0.08)
end

function mobile.vibrateError()
  -- Double pulse for error feedback
  mobile.vibrate(0.03)
  -- Note: Can't easily do double pulse without coroutines/timers
  -- Single pulse is sufficient feedback
end

-- Safe area helpers for notched phones
function mobile.getSafeArea()
  if love.window.getSafeArea then
    return love.window.getSafeArea()
  end
  -- Fallback: return full window dimensions
  return 0, 0, love.graphics.getWidth(), love.graphics.getHeight()
end

-- Check if we should go fullscreen (mobile devices)
function mobile.shouldFullscreen()
  return mobile.isMobile()
end

-- Apply mobile-specific window settings
function mobile.applyMobileSettings()
  if mobile.isMobile() then
    love.window.setFullscreen(true)
  end
end

return mobile
