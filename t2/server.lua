local luarpc = require("luarpc")

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
  if wait == 0 then wait = 1 end
  return wait
end

local states = {FOLLOWER = 1, CANDIDATE = 2, LEADER = 3}

local function buildRaftObj()
  local me = {}
  me.timeout = getRandomTimeout()
  me.state = states.FOLLOWER
  me.currTime = 0
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
    realPrint(me.id .. ": " .. s)
  end

  local function printMe()
    local myString = "\n Timeout: " .. me.timeout .. " State: " .. me.state .. " My term: " .. me.myTerm
    if me.numberOfPeers > 0 then
      myString = myString .. "\n Peers:"
      for k, v in pairs(peers) do
        myString = myString .. "\n\t" .. k .. " " .. v
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

  local function wait()
    local timeToWait = getWaitTime(me.timeout) -- caso follower
    if me.failureTime > 0 then
      timeToWait = me.failureTime
      me.failureTime = 0
    elseif me.state == states.LEADER then
      timeToWait = getRandomTimeout()
    end
    luarpc.wait(timeToWait, true)
  end

  me.receiveMessage = function(msg)
    print("Message received")
    printt(msg)
    return "OK"
  end
  
  me.initializeNode = function()
    me.shutdown = false
    me.majority = (me.numberOfPeers // 2 + 1)
    print("Should Initialize the node " .. me.id)
    printMe()
    while me.shutdown == false do
      local timeBefore = luarpc.gettime()
      wait()
      me.currTime = me.currTime + (luarpc.gettime() - timeBefore)
      -- Checkterm?
      if me.currTime > me.timeout then
        me.currTime = 0
        -- CANDIDATE
        print("TIMEOUT --- BEGIN ELECTION")
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
  end


  return me
end

-- cria servidores:
local arq_interface = "interface.lua"

local peers = {}
local peersCount = 5
for i = 1, peersCount, 1 do
  
  local raftImplemtation = buildRaftObj()
    local serv, err = luarpc.createServant(raftImplemtation, arq_interface)
    if err == nil and serv ~= nil then
        peers[serv.port] = serv
        raftImplemtation.id = serv.port
        raftImplemtation.peers = peers
        raftImplemtation.numberOfPeers = peersCount
        print("Server " .. i .. " is running on " .. serv.port)
    else
        print("Erro criando o nó " .. i .. " " .. err)
        os.exit(-1)
    end
end

for k, v in pairs(peers) do
  print(k,v)
end

---- ESCREVE PRA ARQUIVO AS PORTAS???

-- vai para o estado passivo esperar chamadas:
luarpc.waitIncoming()

