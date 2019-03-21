local config = require "config"("config")

local function printrtc()
  local _, _, rate = rtctime.get()
  print ('rate', rate)
end

mdns.register("clock", { service="http", port=80 })
lastNtpResult = {}

local function startsync()
    sntp.sync({"192.168.1.21", "0.nodemcu.pool.ntp.org", "1.nodemcu.pool.ntp.org", "2.nodemcu.pool.ntp.org"
    }, function (a,b, c, d ) 
      lastNtpResult = { secs=a, usecs=b, server=c, info=d }
      print(a,b, c, d['offset_us']) printrtc() 
    end, function(e) print (e) end, 1)
end

syslog = (require "syslog")(config.syslog_("192.168.1.68"))

if true then
  dprint = function() end
else
  dprint = print
end

local power = require "powerstatus"
local led = require "led"

local t1 = tmr.create()
local t0 = tmr.create()

t1:alarm(1000, tmr.ALARM_AUTO, function(t)
  if power.powerok() then
    print("power ok")
    t:unregister()

    t0:alarm(1000, tmr.ALARM_AUTO, function(t)
       local ip = wifi.sta.getip()
       if ip == nil then
         print ("no ip")
         return
       end
       print ("got ip")
       t:unregister()
       syslog:send("Booted: " .. sjson.encode({node.bootreason()}))
       startsync()
       mdns.register(string.format("clock-%06x", node.chipid()))
       dofile("webserver.lua").register(dofile("httpserver.lua"))
       local control = require "control"
       tmr.create():alarm(10000, tmr.ALARM_SINGLE, function() 
         led.setD5(led.green)
         control.start()
       end)
       dofile("tftpd.lua")(function (fn)
         if fn == "lfs.img" then
           control.stop()
           tmr.create():alarm(1000, tmr.ALARM_SINGLE, function() 
             file.remove("forcelfs.img")
             file.rename("lfs.img", "forcelfs.img")
             node.restart()
           end) 
         end
       end) 
    end)
   end
 end)

local function debounce(cb)
  local timeout = tmr.create()
  local enabled = true
  timeout:register(200, tmr.ALARM_SEMI, function() enabled = true end)
  return function()
    if enabled then
      enabled = false
      cb()
      timeout:start()
    end
  end
end

gpio.mode(3, gpio.INT)
gpio.trig(3, "down", debounce(function() (require "control").toggle() end))

function quit() 
  t1:unregister()
  t0:unregister()
  print ("Done")
end
