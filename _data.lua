local webserver = require "webserver"
local control = require "control"

local opencount = 0

return function (socket)
  local t = tmr.create()
  node.setcpufreq(node.CPU160MHZ)
  opencount = opencount + 1
  local function dosend()
    if socket.getPendingCount() < 2 then
      socket.send(sjson.encode(webserver.getStatus()), 1)
    end
  end
  t:alarm(1000, tmr.ALARM_AUTO, dosend)
  register_object("data-timer", t)
  function socket.onclose()
    opencount = opencount - 1
    if not opencount then
      node.setcpufreq(node.CPU80MHZ)
    end
    t:unregister()
    control.setCapture(nil)
    t = nil
  end
  local lastHash
  control.setCapture(function (data) 
    if socket.getPendingCount() < 2 then
      local hash = crypto.hash("sha1", data)
      if hash ~= lastHash then
        for i = 1, #data, 768 do
          socket.send(sjson.encode({ display=crypto.toBase64(data:sub(i, i + 767)), first=(i == 1), last=(i + 768 > #data) }), 1)
        end
        lastHash = hash
      end
    end
  end)
  dosend()
end


