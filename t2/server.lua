local luarpc = require("luarpc")
local cfg = require("config")
local raft = require("raft")

-- Globals
local arq_interface = "interface.lua"
local IP = "127.0.0.1"

-- Args: [1]: number of "servers" that should be initialized
--       [2]: Total number of servers
--       [3]: offset for config

-- cria servidores:
local peers = {}
local peersCount = arg[1] or 3
local totalCount = arg[2] or 3
local configOffset = 0 or arg[3]

peersCount = tonumber(peersCount)
totalCount = tonumber(totalCount)
configOffset = tonumber(configOffset)

for i = 1, peersCount, 1 do
    local port = cfg.ports[configOffset + i] or 0
    local raftImplemtation = raft.buildRaftObj(IP,arq_interface)
    local serv, err = luarpc.createServant(raftImplemtation, arq_interface, port)
    if err == nil and serv ~= nil then
        local p = tonumber(serv.port)
        peers[p] = {}
        raftImplemtation.id = p
        raftImplemtation.peers = peers
        raftImplemtation.numberOfPeers = peersCount
    else
        print("Erro criando o nó " .. i .. " " .. err)
        os.exit(-1)
    end
end



local count = 1
for k, _ in pairs(peers) do
    print("Server " .. count .. " is running on " .. k)
    count = count + 1
end

---- ESCREVE PRA ARQUIVO AS PORTAS???

-- vai para o estado passivo esperar chamadas:
luarpc.waitIncoming()

