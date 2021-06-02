-- load socket lib
socket = require("socket")

---- Server
function serverLoop( serverSkt, shouldStop )
    while shouldStop == false do
        client = serverSkt:accept()
        coroutine.yield(client)
    end
end
---- Client Handler
------ loop que tenta receber msgs dos clientes até que o limite de tempo seja atingido e 
------ pelo menos o monTries tenha ocorrido. O min tries serve como workaround para a falta
------ de um melhor controle para o tempo de espera pelo cliente (como saber que o tempo não foi gasto em outros processos) 
function clientHandler(client, id, timeLimit, minTries)
    function overTime(initialTime, endTime, limit)
        return os.difftime(initialTime,endTime) > limit
    end
    local msg
    local initialTime = os.time()
    while !overTime(initialTime, os.time(), limit) and msg == nil do
        msg, err = client:receive()
        if err ~= nil then
            -- panic What to do? erro == problema ou deu o timeout?
        end
        coroutine.yield(id, msg) -- what happens when the msg is received? will yield the msg and return after the while
    end
    return msg
end

---- Control
local port = arg[1] or "0"
port = tonumber(port)
local timeout = 0.2
local server = assert(socket.bind("*", port))
local ip, port = server:getsockname()
-- print a message informing what’s up
print("Please telnet to localhost on port " .. port)
print("After connecting, you have xxxxs to enter a line to be echoed")

server:timeout(timeout)
local serverRoutine = coroutine.create( serverLoop )
local clientRoutine = {}
local clientId = 1
while true do
    local client = coroutine.resume(serverRoutine)
    if client ~= nil then
        clientRoutine[clientId] = coroutine.create(clientHandler)
        local id, msg = coroutine.resume( clientRoutine[clientId], client, clientId, /*Segundos??*/ 10, 5) -- do i need msg? The client should resolve all??
        clientId = clientId + 1
        if id then
            clientRoutine[id] = nil -- Bad smell, table with nils should change the structure
        end
    else
        -- Run a low index coroutine??
        -- Run any? Random?
    end
end


-- find out which port the OS chose for us

-- loop forever waiting for clients
while 1 do
-- wait for a connection from any client
local client = server:accept()
-- make sure we don’t block waiting for this client’s line
client:settimeout(10)
-- receive the line
local line, err = client:receive()
-- if there was no error, send it back to the client
if not err then client:send(line .. "\n") end
-- done with client, close the object
client:close()
end