-- control

local M = {}

local time = require "time"
local power = require "powerstatus"
local tz = require "tz"
local led = require "led"

local display = require "display"
display.init()

local timer = tmr.create()

local pulser = require "pulser"

local board = require "config"('board')

local pulsePerSecond
local pulsePerRev
local maxSpeed

local running = false


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
  if not pulsePerSecond then
    return
  end
  local sec, usec = rtctime.get()
  local ticks, even = pulser.status()

  sec = sec + tz.getoffset(sec)

  local s, m, h = gethms(sec)

  local info = string.format("%02d:%02d:%02d", h, m ,s)

  sec = time.getposFromTicks(ticks) / pulsePerSecond

  s, m, h = gethms(sec)
  local clockpos = string.format("%2d:%02d:%02d", h, m ,s)

  disp:drawStr(0, 0, info)

  disp:setFont(u8g2.font_helvB18_tf)
  disp:drawStr(0, 40, "C: " .. clockpos)
end

local capture
local captureBuffer

function doRepaint(t)
  display.paint(drawState)
  if capture then
    local ok, err = pcall(function ()
      local single = table.concat(captureBuffer)
      captureBuffer = {}
      capture(single)
    end)
    captureBuffer = {}
    if not ok then
      print("Caught error from capture callback", err)
    end
  end
  local sec, usec = rtctime.get()

  if usec > 600000 then
    t:alarm((1000000 - usec) / 1000 + 1, tmr.ALARM_SINGLE, doRepaint)
  else
    t:alarm(300, tmr.ALARM_SINGLE, doRepaint)
  end
end

tmr.create():alarm(250, tmr.ALARM_SINGLE, doRepaint)

M.setCapture = function(fn)
  capture = fn
  register_object("capture-fn", fn)
  if capture then
    display.init(function(line)
      local ok, err = pcall(function(line)
        if line == nil then
          captureBuffer = {}
        else
          table.insert(captureBuffer, line:sub(1, 1 + 2 * string.byte(line, 1)))
        end
      end, line)
      if not ok then
        print("Caught error from capture assembly", err)
      end 
    end)
  else
    captureBuffer = {}
    display.init()
  end
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
          local ledcolor = led.blue
          if offsetS < 2 or offsetS > 43197 then
            ledcolor = led.green
          end
          if offsetS < 20 then
            pulser.tickAt(ticks + offset, atus)
          elseif offsetS > 43180 then
            pulser.tickAt(ticks + offset - (43200 * pulsePerSecond), atus)
          elseif offsetS > 43200 - 43200 / maxSpeed then
            pulser.tickAt(ticks + 1, nowus + 20000000)
          else
            pulser.tickAt(ticks + 10 * pulsePerSecond, atus)
          end
          led.setD5(ledcolor)
      end
  else
      M.stop()
  end
  timer:alarm(500, 0, tick)
end

local maxBrightness = 256
local minBrightness = 16

tmr.create():alarm(60000, tmr.ALARM_AUTO, function() 
  local sec, usec = rtctime.get()

  sec = sec + tz.getoffset(sec)

  local s, m, h = gethms(sec)

  -- darkest after 8 pm and before 4AM
  -- brightest after 8AM and before 4PM

  if h < 4 or h >= 20 then
    led.setBrightness(minBrightness)
  elseif h >= 8 and h < 16 then
    led.setBrightness(maxBrightness)
  else
    m = h * 60 + m
    if m > 12 * 60 then
      m = 24 * 60 - m
    end

    m = m - 4 * 60
    led.setBrightness(m * (maxBrightness - minBrightness) / (4 * 60))
  end
end)

M.start = function ()
  if running then return end
  local pps = board.pps_(1)
  pulsePerSecond = pps
  pulsePerRev = 43200 * pulsePerSecond
  local pulseWidth = board.pulsewidth_(100000)
  maxSpeed = 1000000/(pulsePerSecond * pulseWidth * 2)
  if maxSpeed > 6 then
    maxSpeed = 6
  end
  time.init(pps)
  local pos, even = time.getpos_even()
  pulser.init(board.bipolar_(false), pps, pulseWidth, maxSpeed * pps)
  pulser.start(0, even)
  timer:stop()
  tick()
  running = true
  led.setD5(led.yellow)
end

M.stop = function ()
  if not running then return end
  timer:stop()

  pulser.stop(function()   
    local ticks, even = pulser.status()
    time.ticks(ticks, even)
    time.save()
    time.stop()
    running = false
    led.setD5(led.red)
    print ('stopped') end)
end

M.toggle = function()
  if running then
    M.stop()
  else
    M.start()
  end
end


return M
