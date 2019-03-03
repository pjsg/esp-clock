-- webserver.lua

local M = {}

local t = require "time"
local config = require "config"("config")
local tz = require "tz"
local pulser = require "pulser"

local function wrapit(fn)
  return function (conn)
    local buf = "HTTP/1.1 200 OK\r\n" ..
                "Content-type: application/json\r\n" ..
                "Connection: close\r\n\r\n" ..
                sjson.encode(fn())
    conn:send(buf, function(c) c:close() end)
  end
end

local function getStatus()
  local R = {}
  R.time = {rtctime.get()}
  R.hms = t.getpos()
  R.running = t.getrunning()
  R.config = config.table
  R.boardConfig = require "config"('board').table
  R.ntp = lastNtpResult
  R.freemem = node.heap()
  R.mac = wifi.sta.getmac()
  R.isBipolar = pulser.getIsBipolar()
  return R 
end

function M.register(adder)
  function addjson(path, fn)
    adder("GET", path, wrapit(fn)) 
  end
  addjson("/status", getStatus)
  addjson("/zones", function ()
    return tz.getzones()
  end)
  
  adder("POST", "/set", function (conn, vars)
    if vars.start then
      t.start()
    end
    if vars.stop then
      t.stop()
    end
    if vars.pos then
      t.setpos(vars.pos)
    end
    if vars.zone then
      if tz.exists(vars.zone) then
        config.tz = vars.zone
      end
    end
    wrapit(getStatus)(conn)
  end)
end

return M
