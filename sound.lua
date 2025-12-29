-- sound.lua
-- Sound management module: loading, playback, and toggle state

local sound = {}

-- Toggle states
local musicEnabled = false
local sfxEnabled = false

-- Sound sources (initialized in sound.init())
local bgnd_music
local pick_up_snd
local merge_snd
local add_snd

--- Initialize all sound sources and start background music
function sound.init()
  bgnd_music = love.audio.newSource("bgnd_music/storm-clouds-purpple-cat(chosic.com).mp3", "stream")
  pick_up_snd = love.audio.newSource("sfx/chip-lay-2.ogg", "static")
  merge_snd = love.audio.newSource("sfx/chips-handle-1.ogg", "static")
  add_snd = love.audio.newSource("sfx/chips-collide-2.ogg", "static")

  if musicEnabled then
    love.audio.play(bgnd_music)
  end
end

--- Check if music is enabled
function sound.isMusicEnabled()
  return musicEnabled
end

--- Check if SFX is enabled
function sound.isSfxEnabled()
  return sfxEnabled
end

--- Toggle music on/off
function sound.toggleMusic()
  musicEnabled = not musicEnabled
  if musicEnabled then
    love.audio.play(bgnd_music)
  else
    love.audio.pause(bgnd_music)
  end
end

--- Toggle SFX on/off
function sound.toggleSfx()
  sfxEnabled = not sfxEnabled
end

--- Play pickup sound effect
function sound.playPickup()
  if sfxEnabled then
    pick_up_snd:play()
  end
end

--- Play merge sound effect
function sound.playMerge()
  if sfxEnabled then
    merge_snd:play()
  end
end

--- Play add coins sound effect
function sound.playAdd()
  if sfxEnabled then
    add_snd:play()
  end
end

return sound
