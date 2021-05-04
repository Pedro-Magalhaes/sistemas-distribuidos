local luarpc = require("luarpc")

local interface = "interface.lua"
local port = tonumber(arg[1])
local f = tonumber(arg[2])

local ip = "127.0.0.1"
local p1 = luarpc.createProxy(ip, port, interface)

if not f then 
  local r, s = p1.initializeNode()
elseif f == 0 then
  print("killing node")
  local r,s = p1.stopNode(0)
elseif f == -1 then
  p1.snapshot()
else
  print("sleep node")
  local r, s = p1.stopNode(10)
end
print("\n RES p1.execute = ", r, s, "\n")
