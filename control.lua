-- tickcontrol

local M = {}

local time = require "time"
local power = require "powerstatus"
local tz = require "tz"

local display = require "display"(disp)

local timer = tmr.create()

local pulser = require "pulser"

local board = require "config"('board')

local pulsePerSecond
local pulsePerRev
local maxSpeed

local function gethms(sec)
  local s = sec % 60
  local mins = sec / 60
  local m = mins % 60
  local hours = mins / 60
  local h = hours % 24
  local days = hours / 24

  return s, m, h, days
end

local function drawState(disp)
  local sec, usec = rtctime.get()

  sec = sec + tz.getoffset(sec)

  local s, m, h = gethms(sec)

  local info = string.format("%02d:%02d:%02d", h, m ,s)

  h, m, s = time.gethms()
  local clockpos = string.format("%02d:%02d:%02d", h, m ,s)

  --disp:setFont(u8g2.
  disp:drawStr(0, 0, info)

  disp:setFont(u8g2.font_helvB18_tf)
  disp:drawStr(0, 40, "C: " .. clockpos)
end

-- tick runs every 500ms (or so) to keep the clock in phase

local function tick()
  if power.powerok() then
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
          dprint ('want', want, clock, inus, atus, offset, ticks)
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
      M.stop()
  end
  timer:alarm(500, 0, tick)
  display.paint(drawState)
end

M.init = function ()
  local pps = board.pps_(1)
  pulsePerSecond = pps
  pulsePerRev = 43200 * pulsePerSecond
  local pulseWidth = board.pulsewidth_(100000)
  maxSpeed = 1000000/(pulsePerSecond * pulseWidth * 2)
  if maxSpeed > 6 then
    maxSpeed = 6
  end
  time.init(pps)
  pulser.init(board.bipolar_(false), pps, pulseWidth, maxSpeed * pps)
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
