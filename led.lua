local M = {}

M.black = string.char(0,0,0)
M.red = string.char(255,0,0)
M.yellow = string.char(255,255,0)
M.green = string.char(0,255,0)
M.aqua = string.char(0,255,255)
M.blue = string.char(0,0,255)
M.fuschia = string.char(255,0,255)
M.white = string.char(255,255,255)

local buffer = ws2812.newBuffer(3, 3)
local fadedBuffer = ws2812.newBuffer(3, 3)
local brightness = 256

function M.flush()
  fadedBuffer:mix(brightness, buffer)
  ws2812.write(fadedBuffer) 
end

function M.setD5(color) 
  buffer:set(1, color)
  M.flush()
end

function M.setD4(color) 
  buffer:set(2, color)
  M.flush()
end

function M.setD3(color) 
  buffer:set(3, color)
  M.flush()
end

function M.off()
  buffer:fill(M.black)
  M.flush()
end

function M.setBrightness(bright)
  brightness = bright
  M.flush()
end

local function tohex(led)
    return string.format('%02X%02X%02X', buffer:get(led))
end

function M.getHexColors()
  return { tohex(3), tohex(2), tohex(1) }
end

function M.init()
  ws2812.init()
  M.flush()
end

return M
