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

local power = require "powerstatus"

local t1 = tmr.create()
local t0 = tmr.create()

t1:alarm(1000, tmr.ALARM_AUTO, function(t)
  if power.powerok() then
    print("power ok")
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
       local control = require "control"
       tmr.create():alarm(10000, tmr.ALARM_SINGLE, function() 
         control.start()
       end)
       dofile("tftpd.lua")(function (fn)
         if fn == "lfs.img" then
           control.stop()
           tmr.create():alarm(5000, tmr.ALARM_SINGLE, function() 
             node.flashreload(fn) end) 
         end
       end) 
       --dofile("telnet.lua")
    end)
   end
 end)

function debounce(cb)
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

i2c.setup(0, 6, 5, 400000)
disp = u8g2.ssd1306_i2c_128x64_noname(0, 0x3c)

gpio.mode(3, gpio.INT)
gpio.trig(3, "down", debounce(function() (require "control").toggle() end))

function quit() 
  t1:unregister()
  t0:unregister()
  print ("Done")
end
