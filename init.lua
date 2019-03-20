local _init = node.flashindex('_init')

if not _init then
  node.flashreload("lfs.img")
  print("Failed to load the lfs image")
else
  _init()

  local led = require "led"

  led.init()
  led.setD5(led.red)

  i2c.setup(0, 6, 5, 400000)
  disp = u8g2.ssd1306_i2c_128x64_noname(0, 0x3c)
  local splashdata = pcall(require, 'splash')
  if not splashdata then
    local splash = file.open("splash.mono")
    if splash then
      splashdata = splash:read(128 * 64 / 8)
      splash:close()
    end
  end
  if splashdata then
    disp:drawXBM(0, 0, 128, 64, splashdata)
  end

  wifi.setmode(wifi.STATION)

  enduser_setup.start(function() 
    led.setD5(led.yellow)
    tmr.create():alarm(200, tmr.ALARM_SINGLE, function () 
      enduser_setup.stop()
      dofile("clockinit.lua")
    end)
  end)
end
