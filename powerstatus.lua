-- powerstatus.lua

local m = {}
local board = require 'config'('board')

local adcval = bit.lshift(adc.read(0), 5)
local last = false
local limit = board.power_(646)

function m.powerok()
  local current = adc.read(0)
  adcval = adcval + current - bit.rshift(adcval, 5)

  current = m.get()

  if last and current < limit then
    print ('Power Bad', current, bit.rshift(adcval, 5))
    last = false
  elseif not last and current > limit + limit / 20 then
    print ('Power OK', current, bit.rshift(adcval, 5))
    last = true
  end
  return true -- last
end

function m.get()
  return bit.rshift(adcval, 5)
end

return m
