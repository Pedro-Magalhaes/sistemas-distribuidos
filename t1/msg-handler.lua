local msg = {}
local _json = require("json")

function msg.encode( obj )
    local encoded_msg = _json.encode(obj)
    return encoded_msg
end

function msg.decode( json )
    local decoded_msg = _json.decode(json)
    return decoded_msg
end

return msg