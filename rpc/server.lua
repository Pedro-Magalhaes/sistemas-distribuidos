local luarpc = require("luarpc")
local cfg = require("config")
local implementation = require(cfg.implementation)


local function printt( t )
    for k,v in pairs(t) do
        print(k,v)
    end
end

local myobj1 = { foo = 
             function (a, s, st, n)
               return a*2, string.len(s) + st.idade + n
             end,
          boo = 
             function (n)
               return n, { nome = "Bia", idade = 30, peso = 61.0}
             end
        }
local myobj2 = { foo = 
             function (a, s, st, n)
               return 0.0, st.idade
             end,
          boo = 
             function (n)
               return 1, { nome = "Teo", idade = 60, peso = 73.0}
             end
        }
-- cria servidor:
local serv1, err1 = luarpc.createServant (implementation, cfg.interface, cfg.port)

if serv1 then
    print("----- SERVER 1 -------")
    printt(serv1)
    print("----------------")
else
    print("server.lua", "Erro criando servidor 2.", err1)
end

luarpc.waitIncoming()


