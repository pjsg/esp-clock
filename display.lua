-- display.lua

local disp

local M = {}

local prepare = function () 
  disp:setDisplayRotation(u8g2.R2)
  disp:setFont(u8g2.font_helvB24_tf)
  disp:setFontRefHeightExtendedText()
  disp:setDrawColor(1)
  disp:setFontPosTop()
  disp:setFontDirection(0)
  disp:clearBuffer()
end

M.paint = function (drawfn)
  prepare()
  drawfn(disp)
  disp:sendBuffer()
end

M.init = function(fn)
  disp = u8g2.ssd1306_i2c_128x64_noname(0, 0x3c, fn)
end

return M
