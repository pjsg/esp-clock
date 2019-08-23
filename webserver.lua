-- webserver.lua

local M = {}

local t = require "time"
local control = require "control"
local config = require "config"("config")
local tz = require "tz"
local led = require "led"
local pulser = require "pulser"
local powerstatus = require "powerstatus"

local function wrapit(fn)
  return function (conn)
    local buf = "HTTP/1.1 200 OK\r\n" ..
                "Content-type: application/json\r\n" ..
                "Connection: close\r\n\r\n" ..
                sjson.encode(fn())
    local now = tmr.now()
    conn:send(buf, function(c) print ('closing socket after', tmr.now() - now) c:close() end)
  end
end

local function getStatus()
  local R = {}
  local ticks, even = pulser.status()

  R.time = {rtctime.get()}
  R.pos = t.getposFromTicks(ticks)
  R.hmst = {t.gethmstFromPos(R.pos)}
  R.running = t.getrunning()
  R.config = config.table
  R.boardConfig = require "config"('board').table
  R.ntp = lastNtpResult
  R.freemem = node.heap()
  R.mac = wifi.sta.getmac()
  R.isBipolar = pulser.getIsBipolar()
  R.millivolts = powerstatus.millivolts()
  R.leds = led.getHexColors()
  R.sw_build, _ = node.flashindex()
  local _,_,_,_,_,_,_,_,info = node.info()
  if info then
    R.hw_build = string.match(info, "%d%d%d%d%-%d%d%-%d%d %d%d:%d%d")
  end
  return R 
end

M.getStatus = getStatus

function M.register(adder)
  local function addjson(path, fn)
    adder("GET", path, wrapit(fn)) 
  end
  addjson("/status", getStatus)
  addjson("/zones", function ()
    return tz.getzones()
  end)
  
  adder("POST", "/set", function (conn, vars)
    if vars.stop then
      control.stop()
    end
    if vars.pos then
      t.sethands(vars.pos)
    end
    if vars.brightness then
      config.brightness = vars.brightness
    end
    if vars.zone then
      if tz.exists(vars.zone) then
        config.tz = vars.zone
      end
    end
    if vars.start then
      control.start()
    end
    wrapit(getStatus)(conn)
  end)
end

return M
