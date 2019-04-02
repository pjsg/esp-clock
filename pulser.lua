--pulser

-- This controls the output pulses

local inactive = 0
local active = gpio.LOW + gpio.HIGH - inactive

local pin = { 1, 2 }

gpio.write(pin[1], inactive)
gpio.write(pin[2], inactive)
gpio.mode(pin[1], gpio.OUTPUT)
gpio.mode(pin[2], gpio.OUTPUT)

local M = {}

local isBipolar
local perSecond
local pulseOnTime
local maxPerSecond
local pulseOffTime

local offsetAccumulator = 0

-- this looks like
-- 1:   delay to start,  loop = 4 if starting on odd
-- 2:   even pulse on
-- 3:   even pulse off 
-- 4:   odd pulse on
-- 5:   odd pulse off, loop = 2
local pulser

local function signify(x)
  return bit.arshift(bit.lshift(x, 4), 4)
end

M.init = function(bipolar, pps, pulsetime, maxpps) 
  print ('pulser init starting')
  isBipolar = bipolar
  perSecond = pps
  pulseOnTime = pulsetime
  maxPerSecond = maxpps
  pulseOffTime = 1000000 / perSecond - pulseOnTime
  print ('Pulser inited')
end

-- starts ticking in offset us, with pin[1] if even
M.start = function(offset, even)
  local now = tmr.now()
  
  local table = { { delay=offset }, 
         { [pin[1] ] = active, delay=pulseOnTime },
         { [pin[1] ] = inactive, delay = pulseOffTime,
            min = 1000000 / maxPerSecond - pulseOnTime,
            max = 10 * 1000000 / perSecond - pulseOnTime } }
  if isBipolar then
    table[4] =
         { [pin[2] ] = active, delay=pulseOnTime }
    table[5] =
         { [pin[2] ] = inactive, delay = pulseOffTime,
            min = 1000000 / maxPerSecond - pulseOnTime,
            max = 10 * 1000000 / perSecond - pulseOnTime,
            loop = 2, count = 1000000000} 
  else
    table[3].loop = 2
    table[3].count = 1000000000
  end
  if not even and isBipolar then
    table[1].loop = 4
    table[1].count = 2
  end

  pulser = gpio.pulse.build(table)
  pulser:start(signify(now - tmr.now()), function() end)
end

-- make tick number 'tick' happen at 'us'
M.tickAt = function(tick, us)
  local pos, steps, offset, now = pulser:getstate()

  dprint ('tick', tick, us, 'pulser', pos, steps, offset, now)

  -- If our next tick is 3 in 1000 us, and we want
  -- tick = 2 in 3000 us
  -- then we need to add OnTime + OffTime + 3000 - 1000

  -- if steps is even then we are pulsing. Otherwise not
  local nextTickUs = now + offset
  if bit.band(steps, 1) == 1 then
    nextTickUs = nextTickUs + pulseOnTime
  end

  local nextTick = (steps - 1) / 2 + 1

  local pulsePerDay = 86400 * perSecond

  local tickOff = (nextTick - tick) % pulsePerDay

  if tickOff > pulsePerDay / 2 then
    tickOff = tickOff - pulsePerDay
  end

  local adjust

  if tickOff < -300 then
    adjust = -10000000
  elseif tickOff > 300 then
    adjust = 10000000
  else
    adjust = tickOff * (pulseOnTime + pulseOffTime) 
           + signify(us - rtctime.adjust_delta(nextTickUs))
  end

  local new_adjust
  
  if adjust > -10000 and adjust < 10000 then
    offsetAccumulator = offsetAccumulator + adjust
    M.rebase()
    new_adjust = (adjust + 10) / 20
  else
    new_adjust = adjust
  end
  dprint ('adjust', new_adjust, 'was', adjust, 'tickOff', tickOff)
  pulser:adjust(new_adjust)
end

M.rebase = function()
  if offsetAccumulator < -85 or offsetAccumulator > 85 then
      local adjust_by = (offsetAccumulator + 50) / 100
      if adjust_by ~= 0 then
          print ('adjusting by', adjust_by, '--------------------')
          pulseOffTime = pulseOffTime + adjust_by
          offsetAccumulator = offsetAccumulator - adjust_by * 100
          local upd = { delay=pulseOffTime }
          pulser:update(3, upd)
          if isBipolar then
            pulser:update(5, upd)
          end
      end
  end
end

-- gets the number of ticks since start and even
M.status = function()
  if not pulser then
    return 0, 0
  end

  local pos, steps, offset, new = pulser:getstate()

  -- when we are in a waiting state (odd) then we have completed
  -- the tick
  return (steps - 1) / 2, (pos <= 3)
end

-- calls the callback when stopped with the number of ticks since start
M.stop = function(callback)
  if not pulser then
    return
  end
  local pos, steps, offset, new = pulser:getstate()

  -- 3 & 5 are the delaystates 

  if pos == 2 or pos == 5 or not isBipolar then
    pulser:stop(3, callback)
  else
    pulser:stop(5, callback)
  end
  
end

M.getPulser = function()
  return pulser
end

M.getIsBipolar = function()
  return isBipolar
end

return M
