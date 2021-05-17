-- Para testar:
-- verificar no artigo o que ele resolve

-- Simular o que o artigo fala 

local luarpc = require("luarpc")

local interface = "interface.lua"
local port = tonumber(arg[1])
local f = tonumber(arg[2])

local ip = "127.0.0.1"
local p1 = luarpc.createProxy(ip, port, interface)

local r,s

if not f then 
  r, s = p1.initializeNode()
elseif f == 0 then
  print("killing node")
  r,s = p1.stopNode(0)
elseif f == -1 then
  r,s = p1.snapshot()
else
  print("sleep node")
  r, s = p1.stopNode(10)
end
print("\n RES p1.execute = ", r, s, "\n")
