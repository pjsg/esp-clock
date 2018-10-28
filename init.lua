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

local power = require "powerstatus"

tmr.alarm(1, 1000, 1, function()
  if power.powerok(646) then
    tmr.unregister(1)

    tmr.alarm(0, 3000, 1, function()
       local ip = wifi.sta.getip()
       if ip == nil then
         return
       end
       tmr.unregister(0)
       syslog:send("Booted: " .. sjson.encode({node.bootreason()}))
       startsync()
       mdns.register(string.format("clock-%06x", node.chipid()))
       --dofile("webserver.lua").register(dofile("httpserver.lua"))
       tmr.alarm(0, 10000, 0, function() 
         (require"control").init(2)
       end)
       --dofile("telnet.lua")
    end)
   end
   end)

--dofile("pps.lua")
--dofile("tick.lua")

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
gpio.trig(3, "down", debounce(function() (require "control").stop() end))

function quit() 
  tmr.unregister(1)
  tmr.unregister(0)
  print ("Done")
end
