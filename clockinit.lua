function printrtc()
  local _, _, rate = rtctime.get()
  print ('rate', rate)
end

--syslog = require("syslog")("192.168.1.68");
lastNtpResult = {}

function startsync()
    sntp.sync({"192.168.1.21", "0.nodemcu.pool.ntp.org", "1.nodemcu.pool.ntp.org", "2.nodemcu.pool.ntp.org"
    }, function (a,b, c, d ) 
      lastNtpResult = { secs=a, usecs=b, server=c, info=d }
      print(a,b, c, d['offset_us']) printrtc() 
      --logit(c, d)
      --syslog:send("SNTP: Server " .. c .. " offset " .. (d['offset_us'] or 'nil') .. " delay " .. (d['delay_us'] or 'nil') .. " rate " .. rtcmem.read32(14))
    end, function(e) print (e) end, 1)
end

function ptime()
  local sec, usec, rate = rtctime.get()
  print ('time', sec, usec, rate)
end

ptime()

syslog = (require "syslog")("192.168.1.68")

if true then
  dprint = function() end
else
  dprint = print
end

print ('syslog =', syslog)

local power = require "powerstatus"

local t1 = tmr.create()
local t0 = tmr.create()

t1:alarm(1000, tmr.ALARM_AUTO, function(t)
  if power.powerok(646) then
    print ("power ok")
    t:unregister()

    t0:alarm(3000, tmr.ALARM_AUTO, function(t)
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
       tmr.create():alarm(10000, tmr.ALARM_SINGLE, function() 
         (require"control").init()
       end)
       --dofile("telnet.lua")
    end)
   end
 end)

function debounce(cb)
  local timeout = tmr.create()
  local enabled = true
  timeout:register(100, tmr.ALARM_SEMI, function() enabled = true end)
  return function()
    if enabled then
      enabled = false
      cb()
      timeout:start()
    end
  end
end

gpio.mode(3, gpio.INT)
--gpio.trig(3, "down", debounce(function() (require "control").stop() end))

function quit() 
  t1:unregister()
  t0:unregister()
  print ("Done")
end
