-- time.lua

local M = {}
local MEMPOS = 16
local clockpos = 0
local startpos = 0
local savedpos = 0
local pulse = 0  -- either 0x10000 or 0
local PULSEVAL = 0x1000000
local running = 1
local filename = "clockpos.state"
local statefile 
local pulsePerSecond = 1
local pulsePerRev = 43200

local tz = require "tz"

function M.init(pps)
  pulsePerSecond = pps
  pulsePerRev = pps * 43200
  
  local mem = rtcmem.read32(MEMPOS)
  if -1 == bit.bxor(mem, rtcmem.read32(MEMPOS+1)) then
    clockpos = bit.band(mem, PULSEVAL - 1)
    pulse = bit.band(mem, PULSEVAL)
    print ('restored pos', clockpos)
  else
    print ('Resetting to 0', mem, rtcmem.read32(MEMPOS+1))
    clockpos = 0
    pulse = 0
  end
  startpos = clockpos
  if clockpos < 0 or clockpos >= 43200 * pulsePerSecond then
    M.setpos(0)
  end

  sntp.setoffset(0)
end

function M.ticks(count, even) 
  if even then
    pulse = 0
  else
    pulse = PULSEVAL
  end
  M.setpos(startpos + count)
  if not statefile then
    -- this means that we have already saved the (now) wrong pos
    file.remove(filename)
    statefile = file.open(filename, "w")
  end
end

function M.stop()
  running = 0
end

function M.start()
  running = 1
end

function M.setpos(pos)
  clockpos = pos % pulsePerRev
  rtcmem.write32(MEMPOS, clockpos + pulse)
  rtcmem.write32(MEMPOS + 1, bit.bxor(-1, clockpos + pulse))
end

function M.sethms(hour, min, sec)
  local original = clockpos
  M.setpos((hour * 3600 + min * 60 + sec) * pulsePerSecond)
  startpos = startpos + clockpos - original
  M.start()
end

function M.gethms()
  local t = clockpos / pulsePerSecond
  return t / 3600, (t / 60) % 60, t % 60
end

function M.getpos()
  return clockpos
end

function M.getrunning()
  return running
end

function M.get()
  -- returns the clock pas that we want in x us.
  -- Also returns the current clock pos.
  if running == 0 then
    return -1, -1, -1, -1
  end
  local rtctime_get = rtctime.get
  local now = tmr.now()
  local us, nus = rtctime_get()
  if us < 1000000 then
    return -1, -1, -1, -1
  end
  local offset = sntp.getoffset()
  us = us - offset
  local want = (us + 1 + tz.getoffset(us + 1)) % 43200
  dprint (string.format("%d.%06d offset=%d want=%d, now=%d", us + offset, nus, offset, want, now))
  return want * pulsePerSecond, clockpos, 1000000 - nus, now

end

function M.save()
  local savevalue = rtcmem.read32(MEMPOS)
  
  if savevalue ~= savedpos then
    if not statefile then
      statefile = file.open(filename, "w+")
    end
    print ('saving clockpos', savevalue)
    statefile:write(struct.pack("L", savevalue))
    statefile:close()
    statefile = nil
    savedpos = savevalue
  end
end

statefile = file.open(filename)
if statefile then
    local clockposstr = statefile:read(5)
    statefile:close()
    if clockposstr and string.len(clockposstr) == 4 then
      local cpos = struct.unpack("L", clockposstr)
      rtcmem.write32(MEMPOS, cpos)
      rtcmem.write32(MEMPOS+1, bit.bxor(-1, cpos))
      print ('restoring clockpos', rtcmem.read32(MEMPOS), rtcmem.read32(MEMPOS+1))
    end
    file.remove(filename)
end

statefile = file.open(filename, "w")


return M
