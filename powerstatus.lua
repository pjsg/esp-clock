-- powerstatus.lua

local m = {}

local adcval = bit.lshift(adc.read(0), 5)
local last = false

function m.powerok(limit)
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
  return last
end

function m.get()
  return bit.rshift(adcval, 5)
end

return m
