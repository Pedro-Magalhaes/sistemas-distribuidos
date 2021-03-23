local msg = {}
local _json = require("json")

function msg.encode( obj )
    local encoded_msg = _json.encode(obj)
    print(encoded_msg)
    return encoded_msg
end

function msg.decode( json )
    local decoded_msg = _json.decode(json)
    print(decoded_msg)
    return decoded_msg
end

return msg