
node.flashindex("_init")()
wifi.setmode(wifi.STATION)

dofile("clockinit.lua")

tmr.create():alarm(500, tmr.ALARM_AUTO, function(t)
  if wifi.sta.getip() then
    t:stop()
    dofile("clockinit2.lua")
  end
end)
