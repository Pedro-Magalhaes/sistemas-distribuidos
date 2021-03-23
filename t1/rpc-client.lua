local msg_handler = require("msg-handler")
local socket = require("socket")

local ip = "127.0.0.1"
local port = nil

if arg[1] == nil then
    os.exit(-1)
end

port = arg[1]

local client = assert(socket.connect(ip, port))


local msg = msg_handler.encode({ "a","b","c" })

client:send(msg .. "\n")