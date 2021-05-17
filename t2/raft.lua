local luarpc = require("luarpc")

local r = {}


-- Globals
local default_arq_interface = "interface.lua"
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
local default_IP = "127.0.0.1"

--- Auxiliary

local function printt(t)
    for k, v in pairs(t) do
        print(k, v)
    end
end

local function getRandomTimeout(a,b)
  a = a or 2
  b = b or 6
  return math.random(a, b)
end

local function getWaitTime(n) -- retorna a divisao inteira de (n / 3), caso o resultado seja 0 retorna 1
    local wait = n // 3
    if wait < 0 then
        wait = 1
    end
    return wait
end


r.buildRaftObj = function (IP, arq_interface)
    IP = IP or default_IP
    arq_interface = arq_interface or default_arq_interface
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
    me.shouldVote = false
    me.votes = 0

    -- changing glogal print so it prints the peer's id
    local realPrint = print 
    local print = function(s)
        if me ~= nil and me.id ~= nil and (s ~= nil and type(s) ~= "table")then
          local timestamp = luarpc.gettime()
          realPrint(timestamp .. " --- id[" ..  me.id .. "]: " .. s)
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
          peer.appendEntry(me.term) -- FIXME: What to send here? 
        end
      end
    end

    local function elected()
      -- me.timeout[states.CANDIDATE] = 0 -- FIXME: Do i need to reset the timer????
      me.state = states.LEADER
      me.votes = 0
      me.currTime = me.timeout[states.LEADER] + 1 -- making sure it will timeout and send the heatbeat in the control loop
      print("Got Elected")
    end

    local function processVote(msg)
      if msg.value == msgs.OK and me.state == states.CANDIDATE then
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
      me.votedFor = me.id
      me.shouldVote = false
      local votes = {}
      for peer, _ in pairs(me.peers) do -- FIXME: extract method "broadcast(msg)"
        if(peer ~= me.id) then
          me.peers[peer].receiveMessage({term = me.term, from = me.id, to = peer, type = msgs.VOTEREQUEST, value = ""})
        end
      end
    end

    local function wait()
        local timeToWait = getWaitTime(me.timeout[me.state])
        if me.failureTime > 0 then
            timeToWait = me.failureTime
            me.failureTime = 0
        end
        print("Will wait " .. timeToWait)
        luarpc.wait(timeToWait)  -- BUG AQUI, As vezes o wait não aguarda
    end

    local function castVote(peer, response)
      local to = tonumber(peer)
      me.peers[to].receiveMessage({term = me.term, from = me.id, to = to, type = msgs.VOTE, value = response})
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

    local function initializeProxies()
      for port, _ in pairs(me.peers) do
        print('Hello')
        me.peers[port] = luarpc.createProxy(IP, port, arq_interface)
      end
    end

    -- CORE FUNCTION
    me.initializeNode = function()
      me.state = states.FOLLOWER
      me.leader = nil
      me.shutdown = false
      me.majority = (me.numberOfPeers // 2 + 1)
      me.timeout[states.FOLLOWER] = getRandomTimeout(9, 12) -- timeout to call election
      me.timeout[states.CANDIDATE] = getRandomTimeout(6, 9) -- timeout to abort current election and retry
      me.timeout[states.LEADER] = getRandomTimeout(3, 6) -- timeout for heartbeat
      initializeProxies()
      print("Initializing node")
      printMe()
      while me.shutdown == false do
        local timeBefore = luarpc.gettime()
        wait()
        me.currTime = me.currTime + (luarpc.gettime() - timeBefore)

        if me.failureTime > 0 then -- Failure execution
          if me.currTime >= me.failureTime then
            me.failureTime = 0
            me.currTime = 0
          end
        else  -- Normal Execution
          if me.state == states.FOLLOWER and me.votedFor ~= nil and me.shouldVote then --should cast my vote
            castVote(me.votedFor, msgs.OK)
            me.shouldVote = false
            me.currTime = 0 -- reset time when voting
          end
          -- controle de timeouts
          if me.currTime > me.timeout[me.state] then
            me.currTime = 0 -- reset timeout
            if me.state == states.FOLLOWER then -- FIXME extract a method
              me.state = states.CANDIDATE
              print("TIMEOUT --- BEGIN ELECTION")
              callElection()
            elseif me.state == states.LEADER then
              print("LEADER WILL HEARTBEAT")
              heartbeat()
            else -- CANDIDATE election timeout
              print("ELECTION TIMEOUT --- NEW ELECTION")
              callElection()
            end
          end
        end
      end
    end

    -- CORE FUNCTION
    -- msg { term, from, to, type, value}
    me.receiveMessage = function(msg)
        local returnMsg = msgs.OK
        if msg == nil or me.failureTime > 0 or me.shutdown then
          if msg == nil then
            print("ERRO MENSAGEM RECEBIDA NIL")
          else
            print("Mensagem recebida>> " .. msg.type .. " from: " .. msg.from .. " msgTerm: " .. msg.term)
            print("Will not respond! On falure")
          end
          return
        end
        print("Mensagem recebida>> " .. msg.type .. " from: " .. msg.from .. " msgTerm: " .. msg.term)


        if msg.term > me.term then
          me.votedFor = nil -- making sure that i can cast a vote in each term
        end

        if msg.type == msgs.VOTEREQUEST then
          returnMsg = msgs.OK
          if checkVoteRequest(msg) then
            print("Will vote for ".. msg.from)
            me.votedFor = msg.from
            me.shouldVote = true
          else
            print("Will not vote for " .. msg.from .. " My term: " .. me.term .. " his term: " .. msg.term)
          end
        elseif msg.type == msgs.VOTE then 
          print("Got a vote")
          processVote(msg)
        else
          print("No action for msg received " .. msg.type)
        end

        if msg.term > me.term then
          me.term = msg.term
          if me.state == states.LEADER then
            me.state = states.FOLLOWER -- How to know who is the new leader? Just wait for a hearbeat??
            me.currTime = 0
          end
        end

        return returnMsg
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
      print("Received heartBeat")
      me.currTime = 0 -- FIXME: How to check if the appendEntry is from the correct leader? 
      return "OK"
    end

    -- CORE FUNCTION
    me.snapshot = function()
        printMe()
        return
    end

    return me
end

return r