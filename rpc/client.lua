local luarpc = require("luarpc")
local cfg = require("config")

local port = arg[2] or cfg.clientPort
local ip = arg[1] or cfg.ip
local interface = arg[3] or cfg.interface
-- local arq_interface = "idl1.idl"
-- local arq_interface2 = "idl2.idl"
local proxy = luarpc.createProxy (ip, port, interface)

local err, t, p = proxy:boo(10)

if err then
    print("ARQUIVO CLIENTE------ Erro no p1:boo")
    print(err)
else
    print("result p2:boo------")
    print(t,p)
end
