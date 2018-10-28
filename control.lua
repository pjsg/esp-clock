-- tickcontrol

local M = {}

local time = require "time"
local power = require "powerstatus"

local timer = tmr.create()

local pulser = require "pulser"

local pulsePerSecond
local pulsePerRev
local maxSpeed

local limit = 3600 * 1024 * 100 / (100 + 470) / 1000

-- tick runs every 500ms (or so) to keep the clock in phase

local function tick()
  if power.powerok(limit) then
      local ticks, even = pulser.status()
      time.ticks(ticks, even)
      local want, clock, inus, nowus = time.get()
      if want >= 0 and inus >= 0 then
          -- if clock is reading noon and we want to have it say 1:00, then we step fast
          -- if the clock is reading 1:00 and we want to have it say noon, then we stop
          local offset = (want - clock + pulsePerRev) % pulsePerRev
          local atus = inus + nowus  -- now is the next second boundary
          -- we want to figure out the tick number corresponding
          -- to 'want' (which is mod 43200)
          print ('want', want, clock, inus, atus, offset, ticks)
          local offsetS = offset / pulsePerSecond
          if offsetS < 20 then
            pulser.tickAt(ticks + offset, atus)
          elseif offsetS > 43180 then
            pulser.tickAt(ticks + offset - (43200 * pulsePerSecond), atus)
          elseif offsetS > 43200 - 43200 / maxSpeed then
            pulser.tickAt(ticks + 1, nowus + 20000000)
          else
            pulser.tickAt(ticks + 10 * pulsePerSecond, atus)
          end
      end
  else
      time.save()
  end
  timer:alarm(500, 0, tick)
end

M.init = function (pps)
  pulsePerSecond = pps
  pulsePerRev = 43200 * pulsePerSecond
  local pulseWidth = 100000
  maxSpeed = 1000000/(pulsePerSecond * pulseWidth * 2)
  if maxSpeed > 6 then
    maxSpeed = 6
  end
  time.init(pps)
  print ('about to init', pulser)
  pulser.init(true, pps, pulseWidth, maxSpeed * pps)
  print ('inited')
  pulser.start(0, true)
  timer:stop()
  tick()
end

M.stop = function ()
  timer:stop()

  pulser.stop(function()   
    local ticks, even = pulser.status()
    time.ticks(ticks, even)
    time.save()
    time.stop()
    print ('stopped') end)
end


return M
