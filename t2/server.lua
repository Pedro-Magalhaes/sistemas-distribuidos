local luarpc = require("luarpc")

-- Globals
local arq_interface = "interface.lua"
local states = {
    FOLLOWER = "follower",
    CANDIDATE = "candidate",
    LEADER = "leader"
}
local msgs = {
    OK = "ok",
    NO = "no",
    VOTE = "vote",
    VOTEREQUEST = "voterequest",
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
    me.timeout = { [states.CANDIDATE] = nil, [states.FOLLOWER] = nil , [states.LEADER] = nil}
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
    me.votedFor = nil
    me.votes = 0

    -- changing glogal print so it prints the peer's id
    local realPrint = print 
    local print = function(s)
        if me ~= nil and me.id ~= nil then
          realPrint(me.id .. ": " .. s)
        else
          realPrint(s)
        end
    end

    local function printMe()
        local myString = "\n Timeout: " .. me.timeout[me.state] .. " State: " .. me.state .. " My term: " .. me.myTerm
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

    local function heartbeat()
      for port, peer in pairs(me.peers) do
        if port ~= me.id then
          print("heartbeating: " .. port)
          local s = luarpc.createProxy(IP, port, arq_interface)
          s.appendEntry(me.term) -- FIXME: What to send here? 
        end
      end
    end

    local function elected()
      -- me.timeout[states.CANDIDATE] = 0 -- FIXME: Do i need to reset the timer????
      me.state = states.LEADER
      me.votes = 0
      me.currTime = 0
      print("Got Elected")
      for port, _ in pairs(me.peers) do
        local s = luarpc.createProxy(IP, port, arq_interface)
      end
      heartbeat()
    end

    local function processVote(msg)
      if msg.value == msgs.OK then
        me.votes = me.votes + 1
        if me.votes >= me.majority then
          elected()
        end
      end
    end

    local function callElection()
      me.term = me.term + 1
      me.state = states.CANDIDATE
      me.votes = 1 -- my vote
      local votes = {}
      for peer, _ in pairs(me.peers) do -- FIXME: extract method "broadcast(msg)"
        if(peer ~= me.id) then
          local s = luarpc.createProxy(IP, peer, arq_interface)
          votes[peer] = s.receiveMessage({term = me.term, from = me.id, to = peer, type = msgs.VOTEREQUEST, value = "blabla"})
        end
      end
      for peer, vote in pairs(votes) do --FIXME: Temporary, return when using a async election!!!!!
        if me.votes >= me.majority then
          return
        end
        processVote({["value"] = vote})
      end
    end

    local function wait()
        local timeToWait = getWaitTime(me.timeout[me.state])
        if me.failureTime > 0 then
            timeToWait = me.failureTime
            me.failureTime = 0
        end
        luarpc.wait(timeToWait, true)
    end

    local function castVote(peer, response)
      local s = luarpc.createProxy(IP, peer, arq_interface)
      s.receiveMessage({term = me.term, from = me.id, to = peer, type = msgs.VOTE, value = response})
    end

    local function checkVoteRequest(msg)
      if msg.term < me.term then
        return false
      end
      if me.votedFor ~= nil and me.votedFor ~= msg.from then
        return false
      end
      return true
    end

    -- CORE FUNCTION
    -- msg { term, from, to, type, value}
    me.receiveMessage = function(msg)
        print("Mensagem recebida")
        printt(msg)
        local returnMsg = msgs.OK
        if msg == nil then -- Pode ser nil???????
            print("ERRO MENSAGEM RECEBIDA NIL")
            return
        end
        if msg.type == msgs.VOTEREQUEST then -- FIXME: Should be async! create a voting state for followers??? How to keep the peer info?
          if checkVoteRequest(msg) then
            returnMsg = msgs.OK
          else
            returnMsg = msgs.NO
          end
        elseif msg.type == msgs.VOTE and me.state == states.CANDIDATE then -- FIXME: for now is not been used! Will be used when the voting is async
          processVote(msg)
        else
          print("receiveMessage, type not implemented. Received: " .. msg.type)
        end

        if msg.term > me.term then -- FIXME: Should it be updated here??
          me.term = msg.term
          if me.state == states.LEADER then
            me.state = states.FOLLOWER -- How to know who is the new leader? Just wait for a hearbeat??
            me.currTime = 0
          end
        end

        return returnMsg
    end

    -- CORE FUNCTION
    me.initializeNode = function()
        me.state = states.FOLLOWER
        me.leader = nil
        me.shutdown = false
        me.majority = (me.numberOfPeers // 2 + 1)
        me.timeout[states.FOLLOWER] = getRandomTimeout() -- timeout to call election
        me.timeout[states.CANDIDATE] = getRandomTimeout() -- timeout to abort current election and retry
        me.timeout[states.LEADER] = getRandomTimeout() -- timeout for heartbeat
        print("Should Initialize the node " .. me.id)
        printMe()
        while me.shutdown == false do
            local timeBefore = luarpc.gettime()
            wait()
            me.currTime = me.currTime + (luarpc.gettime() - timeBefore)
            -- controle de timeouts
            if me.currTime > me.timeout[me.state] then
              if me.state == states.FOLLOWER then -- FIXME extract a method
                me.currTime = 0
                me.state = states.CANDIDATE
                print("TIMEOUT --- BEGIN ELECTION")
                callElection()
              elseif me.state == states.LEADER then
                print("LEDER WILL HEARTBEAT")
                heartbeat()
              else -- CANDIDATE
                me.currTime = 0
                callElection()
              end
          end
        end
    end

    -- CORE FUNCTION
    me.stopNode = function(time)
        if time == 0 then
            print("Should shutdown")
            me.shutdown = true
        else
            me.failureTime = time
        end

    end

    -- CORE FUNCTION
    me.appendEntry = function(msg)
        me.currTime = 0 -- FIXME: How to check if the appendEntry is from the correct leader? 
        if msg == nil then
            msg = "nil"
        end
        print("Append entry received msg: " .. msg)
        return "OK"
    end

    -- CORE FUNCTION
    me.snapshot = function()
        printMe()
        return
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

