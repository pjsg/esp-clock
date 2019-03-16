-- display.lua

return function(disp) 
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

  return M
end
