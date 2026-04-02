-- yandex.lua
-- Yandex Games SDK bridge (web only)
-- Uses Emscripten FFI to call JavaScript from Lua. All functions are no-ops
-- when not running on web, so the game works identically on desktop/mobile.

local mobile = require("mobile")

local yandex = {}

local is_web = false
local js_eval = nil
local js_eval_string = nil

function yandex.init()
  is_web = mobile.isWeb()
  if not is_web then return end

  local ok, ffi = pcall(require, "ffi")
  if not ok then return end

  pcall(function()
    ffi.cdef[[
      void emscripten_run_script(const char *script);
      char *emscripten_run_script_string(const char *script);
    ]]
    js_eval = function(code)
      ffi.C.emscripten_run_script(code)
    end
    js_eval_string = function(code)
      local ptr = ffi.C.emscripten_run_script_string(code)
      if ptr ~= nil then
        return ffi.string(ptr)
      end
      return nil
    end
  end)
end

function yandex.isWeb()
  return is_web
end

function yandex.isReady()
  if not is_web or not js_eval_string then return false end
  local result = js_eval_string("window.yandexBridge && window.yandexBridge.sdkReady ? 'yes' : 'no'")
  return result == "yes"
end

-- Interstitial ads (fullscreen, between natural breaks)
function yandex.showInterstitial()
  if not is_web or not js_eval then return end
  js_eval("window.yandexBridge.showInterstitial()")
end

function yandex.getInterstitialResult()
  if not is_web or not js_eval_string then return "none" end
  return js_eval_string("window.yandexBridge.interstitialResult || 'none'")
end

function yandex.resetInterstitialResult()
  if not is_web or not js_eval then return end
  js_eval("window.yandexBridge.interstitialResult = 'none'")
end

-- Rewarded video ads (player watches for reward)
function yandex.showRewarded()
  if not is_web or not js_eval then return end
  js_eval("window.yandexBridge.showRewarded()")
end

function yandex.getRewardedResult()
  if not is_web or not js_eval_string then return "none" end
  return js_eval_string("window.yandexBridge.rewardedAdResult || 'none'")
end

function yandex.resetRewardedResult()
  if not is_web or not js_eval then return end
  js_eval("window.yandexBridge.rewardedAdResult = 'none'")
end

-- Sticky banner ads (passive, top/bottom of screen)
function yandex.showBanner()
  if not is_web or not js_eval then return end
  js_eval("window.yandexBridge.showBanner()")
end

function yandex.hideBanner()
  if not is_web or not js_eval then return end
  js_eval("window.yandexBridge.hideBanner()")
end

return yandex
