luarpc = require("luarpc")



local function printt( t )
    for k,v in pairs(t) do
        print(k,v)
    end
end

myobj1 = { foo = 
             function (a, s, st, n)
               return a*2, string.len(s) + st.idade + n
             end,
          boo = 
             function (n)
               return n, { nome = "Bia", idade = 30, peso = 61.0}
             end
        }
myobj2 = { foo = 
             function (a, s, st, n)
               return 0.0, st.idade
             end,
          boo = 
             function (n)
               return 1, { nome = "Teo", idade = 60, peso = 73.0}
             end
        }
-- cria servidores:
local arq_interface1 = "idl1.idl"
local arq_interface2 = "idl2.idl"
local serv1, err1 = luarpc.createServant (myobj1, arq_interface1)

if serv1 then
    print("----- SERVER 1 -------")
    printt(serv1)
    print("----------------")
else
    print("server.lua", "Erro criando servidor 2.", err1)
end

local serv2, err2 = luarpc.createServant (myobj2, arq_interface2)
if serv2 then
    print("----- SERVER 2 -------")
    printt(serv2)
    print("----------------")
else
    print("server.lua", "Erro criando servidor 2.", err2)
end

-- vai para o estado passivo esperar chamadas:
luarpc.waitIncoming()


