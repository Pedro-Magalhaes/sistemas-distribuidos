local luarpc = require("luarpc")

local interface = arg[1]
local port = tonumber(arg[2])
local ip = "127.0.0.1"

local p1 = luarpc.createProxy(ip, port, interface)
local r, s = p1.initializeNode()
print("\n RES p1.execute = ", r, s, "\n")
