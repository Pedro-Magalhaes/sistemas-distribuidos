local luarpc = require("luarpc")

local function printt(t)
    for k, v in pairs(t) do
        print(k, v)
    end
end

local raftObj = {
    foo = function(a, s, st, n)
        return a * 2, string.len(s) + st.idade + n
    end,
    boo = function(n)
        return n, {
            nome = "Bia",
            idade = 30,
            peso = 61.0
        }
    end
}

-- cria servidores:
local arq_interface = "interface.lua"

local nodes = {}
for i = 1, 5, 1 do
    local serv, err = luarpc.createServant(raftObj, arq_interface)
    if err == nil then
        nodes[i] = serv
    else
        print("Erro criando o nó " .. i .. " " .. err)
        os.exit(-1)
    end

end

---- ESCREVE PRA ARQUIVO AS PORTAS???

-- vai para o estado passivo esperar chamadas:
luarpc.waitIncoming()

