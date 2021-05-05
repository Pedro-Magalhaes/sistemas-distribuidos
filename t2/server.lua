local luarpc = require("luarpc")

-- Globals
local arq_interface = "interface.lua"
local states = {
    FOLLOWER = 1,
    CANDIDATE = 2,
    LEADER = 3
}
local msgs = {
    OK = "ok",
    NO = "no",
    VOTE = "vote",
    HEARTBEAT = "beat"
}
local IP = "127.0.0.1"

--- Auxiliary

local function printt(t)
    for k, v in pairs(t) do
        print(k, v)
    end
end

local function getRandomTimeout()
    return math.random(2, 6)
end

local function getWaitTime(n) -- retorna a divisao inteira de (n / 3), caso o resultado seja 0 retorna 1
    local wait = n // 3
    if wait == 0 then
        wait = 1
    end
    return wait
end

local function buildRaftObj()
    local me = {}
    me.electionTimeout = getRandomTimeout() + 2 -- FIXME: random????
    me.leaderTimeout = getRandomTimeout() -- FIXME: Check good number
    me.timeout = getRandomTimeout() -- FIXME: Refactor for a table with all timeouts
    me.state = states.FOLLOWER
    me.currTime = 0 -- contabiliza a passagem de tempo desde o ultimo heartbeat ou troca de estado
    me.leader = nil
    me.id = nil -- id vai ser a porta
    me.peers = {}
    me.numberOfPeers = 0
    me.majority = 0
    me.shutdown = false;
    me.failureTime = 0
    me.myTerm = 0
    me.term = 0

    local realPrint = print
    local print = function(s)
        if me ~= nil and me.id ~= nil then
          realPrint(me.id .. ": " .. s)
        else
          realPrint(s)
        end
    end

    local function printMe()
        local myString = "\n Timeout: " .. me.timeout .. " State: " .. me.state .. " My term: " .. me.myTerm
        if me.numberOfPeers > 0 then
            myString = myString .. "\n Peers:"
            for k, _ in pairs(me.peers) do
                myString = myString .. "\n\t" .. k 
            end
        end
        myString = myString .. "\n Leader: "
        if me.leader then
            myString = myString .. me.leader
        else
            myString = myString .. "nil"
        end
        print(myString)
    end

    local function callElection()
        print("callElection not yet implemented") -- FIXME
    end

    local function heartbeat()
        for port, peer in pairs(me.peers) do
            if port ~= me.id then
                print("ALLLOOOOOO")
                local s = luarpc.createProxy(IP, port, arq_interface)
                local resp = s.receiveMessage({term = me.term, from = me.id, to = port, type = msgs.HEARTBEAT, value = "blabla"})
                realPrint(resp)
                print(resp)
            end
        end
    end

    local function wait()
        local timeToWait = getWaitTime(me.timeout) -- caso follower
        if me.failureTime > 0 then
            timeToWait = me.failureTime
            me.failureTime = 0
        elseif me.state == states.LEADER then
            timeToWait = getRandomTimeout()
            print("Leader will wait ")
            print(timeToWait)
        end
        luarpc.wait(timeToWait, true)
    end

    -- msg { term, from, to, type, value}
    me.receiveMessage = function(msg) -- FIXME bad if else logic!!
        print("Mensagem recebida")
        printt(msg)

        if msg == nil then -- Pode ser nil???????
            print("ERRO MENSAGEM RECEBIDA NIL")
            return
        end
        if msg.term < me.term then
            return msgs.NO -- FIXME what to return???? 
        end
        if msg.term > me.term then -- should be new election? if i failed what to do to catch up?
          if me.state == states.LEADER then
            me.state = states.FOLLOWER -- How to know who is the new leader? Just wait for a hearbeat??
            me.currTime = 0
            return msgs.OK -- FIXME, what to do here? should i check if its a new election?
          end
        end
        if msg.type == msgs.HEARTBEAT then
          if me.leader == nil then me.leader = msg.from end
          if msg.from == me.leader then
              print("heartbeat from:" .. msg.from .. " received")
              me.currTime = 0
          end
        end
        return "OK"
    end

    me.initializeNode = function()
        me.state = states.LEADER -- FIXME Remove!!!! just for debug purposes 
        me.shutdown = false
        me.majority = (me.numberOfPeers // 2 + 1)
        print("Should Initialize the node " .. me.id)
        printMe()
        while me.shutdown == false do
            local timeBefore = luarpc.gettime()
            wait()
            me.currTime = me.currTime + (luarpc.gettime() - timeBefore)
            -- controle de timeouts
            if me.state == states.FOLLOWER then -- FIXME extract a method
                if me.currTime > me.timeout then
                    me.currTime = 0
                    me.state = states.CANDIDATE
                    callElection()
                    print("TIMEOUT --- BEGIN ELECTION")
                end
            elseif me.state == states.LEADER then
                print("LEDER WILL HEARTBEAT")
                heartbeat()
            else -- CANDIDATE

            end

        end
    end

    me.stopNode = function(time)
        if time == 0 then
            print("Should shutdown")
            me.shutdown = true
        else
            me.failureTime = time
        end

    end
    me.appendEntry = function(msg)
        -- me.currTime = 0
        if msg == nil then
            msg = ""
        end
        print("Append entry received msg: " .. msg)
        return "OK"
    end

    me.snapshot = function()
        printMe()
        return "2"
    end

    return me
end

-- cria servidores:
local peers = {}
local peersCount = 5
for i = 1, peersCount, 1 do

    local raftImplemtation = buildRaftObj()
    local serv, err = luarpc.createServant(raftImplemtation, arq_interface)
    if err == nil and serv ~= nil then
        local p = tonumber(serv.port)
        peers[p] = serv
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

