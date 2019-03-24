-- romfile
--
-- has an open method that returns either a file object or an object that has read and close methods

local M = {}

local RF = {}

function RF:new(o)
  o = o or {}   -- create object if user does not provide one
  setmetatable(o, self)
  self.__index = self
  o.pos = 1
  return o
end

function RF:read(n)
  local result = self.data:sub(self.pos, self.pos - 1 + n)
  self.pos = self.pos + n
  return result
end

function RF:close()
  self.data = nil
end

function M.exists(filename)
  local ok, result = pcall(require, filename:gsub("[.]", "_"))
  if not ok then
    return file.exists(filename)
  end
  return true
end

function M.open(filename)
  local f = file.open(filename)
  if f then
    return f
  end
  local ok, result = pcall(require, filename:gsub("[.]", "_"))
  if not ok then
    return nil
  end
  return RF:new({data=result})
end

return M
