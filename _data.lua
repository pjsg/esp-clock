local webserver = require "webserver"
local control = require "control"

return function (socket)
  local t = tmr.create()
  node.setcpufreq(node.CPU160MHZ)
  local function dosend()
    if socket.getPendingCount() < 2 then
      socket.send(sjson.encode(webserver.getStatus()), 1)
    end
  end
  t:alarm(1000, tmr.ALARM_AUTO, dosend)
  function socket.onclose()
    node.setcpufreq(node.CPU80MHZ)
    t:unregister()
    control.setCapture(nil)
    t = nil
  end
  if true then
  control.setCapture(function (data) 
    if socket.getPendingCount() < 2 then
      for i = 1, #data, 768 do
        socket.send(sjson.encode({ display=crypto.toBase64(data:sub(i, i + 767)), first=(i == 1), last=(i + 768 > #data) }), 1)
      end
    end
  end)
  end
  dosend()
end


