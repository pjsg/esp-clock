local M = {}

M.black = string.char(0,0,0)
M.red = string.char(255,0,0)
M.yellow = string.char(255,255,0)
M.green = string.char(0,255,0)
M.blue = string.char(0,0,255)
M.white = string.char(255,255,255)

local d5 = M.black
local d4 = M.black
local d3 = M.black

function M.flush()
  ws2812.write(d5 .. d4 .. d3) 
end

function M.setD5(color) 
  d5 = color
  M.flush()
end

function M.setD4(color) 
  d4 = color
  M.flush()
end

function M.setD3(color) 
  d3 = color
  M.flush()
end

function M.off()
  d3 = M.black
  d4 = M.black
  d5 = M.black
  M.flush()
end

function tohex(str)
    return (str:gsub('.', function (c)
            return string.format('%02X', string.byte(c))
            end))
end

function M.getHexColors()
  return { tohex(d3), tohex(d4), tohex(d5) }
end


return M
