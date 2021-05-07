luarpc = require("luarpc")


local ip = "127.0.0.1"
local porta1 = arg[1]
local porta2 = arg[2]
local arq_interface = "idl1.lua"
local arq_interface2 = "idl2.lua"
local p1 = luarpc.createProxy (ip, porta2, arq_interface)
local p2 = luarpc.createProxy (ip, porta1, arq_interface2)

local err1, t, p = p1:boo(10)

if err1 then
    print("ARQUIVO CLIENTE------ Erro no p1:boo")
    print(err1)
else
    print("result p2:boo------")
    print(t,p)
end

local err2,r, s = p2:foo(6, "alo", {nome = "Aaa", idade = 200, peso = 55.0}, 6)
if err2 then
    print("ARQUIVO CLIENTE------ Erro no p2:foo")
    print(err2)
else
    print("result p1:foo------")
    print(r,s)
end
