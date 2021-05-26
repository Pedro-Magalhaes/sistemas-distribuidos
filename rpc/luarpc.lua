
local socket = require("socket")
local msgHandler = require("msg-handler")
local module = {}
local servers = {}
local clients = {}

-- mapa para que dado um servidor eu possa rodar a função dele, vou indexar pela porta.
-- Assim uma chamada a foo() na porta x vai executar serverObjPortMap[x].foo()
local serverObjPortMap = {} 



-- checa tipo struct
function checkStructType(param, structFields)
    local err = nil
    local paramSize = 0
    for k,v in pairs(param) do
        paramSize = paramSize + 1
    end
    if paramSize ~= #structFields then 
        return "Erro, o numero de campos da struct está incorreto." .. "num esperado " .. #structFields .. " recebidos " .. paramSize
    end
    for k,v in pairs(structFields) do
        err = checkSimpleType(v.type, param[v.name])
        if err then
            err = "Erro na Struct. No campo " .. v.name .. ". ".. err
            return err
        end
    end
end

-- faz a checagem de tipo para os parametros simples recebidos
function checkSimpleType(interfaceType, param)
    local err = nil
    if interfaceType == "char" then
        if type(param) ~= "string" or #param ~= 1 then
            err = "Erro parametro não eh char. Param recebido: " .. type(param)
        end
    elseif interfaceType == "string" then
        if type(param) ~= "string" then
            err = "Erro parametro não eh string. Param recebido: " .. type(param)
        end
    elseif interfaceType == "double" then
        if type(param) ~= "number" then
            err = "Erro parametro não eh double. Param recebido: " .. type(param)
        elseif math.type(param) ~= "float" and math.type(param) ~= "integer" then -- aceito int no double
            err = "Erro parametro não eh double. Param recebido: " ..  math.type(param)
        end
    elseif interfaceType == "int" then
        if type(param) ~= "number" then
            err = "Erro parametro não eh int. Param recebido: " .. type(param)
        elseif math.type(param) ~= "integer" then
            err = "Erro parametro não eh int. Param recebido: " ..  math.type(param)
        end
    else -- tipo desconhecido
        err = "Erro parametro desconhecido. Parametro esperado: " .. interfaceType .. " Param recebido: " ..  type(param)
    end
    return err
end



-- conta e retorna quantos argumentos são do tipo "in" e quantos do tipo "out"
function getNumberOfInAndOutArguments(arguments)
    local i = 0
    local o = 0
    for k,v in pairs(arguments) do
        if v.direction == "in" then
           i = i + 1
        else
            o = o + 1
        end
    end
    -- assert(i+o == #arguments) -- sanity check
    return i,o
end

-- Checa se todas as funções estão no objeto recebido
function checkServantObj(obj, interface)
    for k,v in pairs(obj) do
        if interface.methods[k] == nil then
            print("Erro, objeto recebido não implementa a interface a função " .. k .. " não existe")
            return "error"
        end
    end
end

-- checa se os retornos casam com a interface, se o numero de parametros não casar com o esperado, retorna erro direto
-- caso contrario retorna apenas o ultimo erro, se houver
function checkReturnTypes(returnTbl, returnType, params, structTbl)
    local inParams, outParams = getNumberOfInAndOutArguments(params)
    local defaultReturn = 1 -- por default toda funçao retona 1 parametro, vou tratar o caso void passando pra zero
    local expectedReturns = defaultReturn + outParams -- o numero de parametros retornados eh o retorno default da função mais os parametros out
    if returnType == "void" then defaultReturn = 0 end -- caso void não tem retorno "default"
    if #returnTbl ~= expectedReturns then 
        return "Erro, Numero de retornos diferente do esperado na IDL. Esperava: " .. expectedReturns .. "Recebeu " .. #returnTbl
    end

    local err = nil
    local index = 1
    if defaultReturn == 1 then -- temos que checar o retorno "basico"
        if returnType == structTbl.name then
            err = checkStructType(returnTbl[index], structTbl.fields)
        else
            err = checkSimpleType(returnType, returnTbl[index])
        end        
        if err then
            print("ERRO VERIFICANDO TIPO BASICO DE RETORNO")
            return err 
        end
        index = index + 1
    end

    -- checando os parametros out na ordem
    for _,v in ipairs(params) do
        if(v.direction == "out") then
            if v.type == structTbl.name then
                err = checkStructType(returnTbl[index], structTbl.fields)
            else
                err = checkSimpleType(v.type,returnTbl[index])
            end
            if err then
                print("checkReturnTypes", err)
                return err
             end
            index = index + 1
        end        
    end
end

-- Função Exportada pelo módulo
-- cria o servent, adicionei o parametro opcional da porta para facilitar uma porta fixa
-- o primeiro parametro retornado indica erro ou sucesso
function module.createServant(obj, interfaceFile, porta)
    if obj == nil then
        return nil, "Objeto que implementa a interface eh nulo"
    end
    if interfaceFile == nil then
        return nil, "Arquivo de interface eh nulo"
    end
    if porta == nil then porta = 0 end -- default é "0"
    -- funções para poder chamar o arquivo de interface com o "dofile"
    -- a struct e a interface ficaram guardadas nas variaveis structTbl e interfaceTbl    
    local interfaceTbl = nil
    local structTbl = nil

    function interface(tbl)
        interfaceTbl = tbl  
    end

    function struct(tbl)
        structTbl = tbl  
    end
    -- Risco de segurança, qualquer código pode ser rodado!!!!!
    dofile(interfaceFile)
    err = checkServantObj(obj, interfaceTbl)
    if err then
        return nil, err
    end
    
    local server = assert(socket.bind("*", porta))

    -- find out which port the OS chose for us
    local ip, port = server:getsockname()

    -- salvando a interface e struct para verificar o retorno da função
    obj["checkReturnTypes"] = function (returnTbl, method)
        return checkReturnTypes(returnTbl, interfaceTbl.methods[method].resulttype,interfaceTbl.methods[method].args, structTbl)
    end
    serverObjPortMap[port] = obj -- adiciona ao mapa para ser usado na waitIncoming

    table.insert(servers, server) -- adicionando aos servidores observados na waitIncoming
    print("Novo servidor criado com ip " .. ip .. " na porta " .. port )
    return { ip = ip, port = port }
end

-- Função Exportada pelo modulo
-- cria o método que o cliente vai usar de forma transparente 
-- quando o método criado é executado pelo cliente, são executadas as verificações de parametros de entrada
-- os parametros de retorno são tratados pelo servidor
function module.createProxy(hostname, port, interfaceFile)
    -- funções para poder chamar o arquivo de interface com o "dofile"
    -- a struct e a interface ficarão guardadas nas variaveis structTbl e interfaceTbl
    local interfaceTbl = nil
    local structTbl = nil

    function interface(tbl)
        interfaceTbl = tbl  
    end

    function struct(tbl)
        structTbl = tbl  
    end

    -- Risco de segurança, qualquer código pode ser rodado!!!!!
    dofile(interfaceFile)

    local functions = {}
    local prototypes = interfaceTbl
    
    for name, tbl in pairs(prototypes.methods) do
        functions[name] = function(self, ...)
            local inArgs, outArgs = getNumberOfInAndOutArguments(tbl.args)
            -- validating params
            local params = {...}
            local values = { }
            local returValue = tbl.resulttype
            local inputs = tbl.args
            if inArgs ~= #params then -- checa se o numero de parametros recebidos está correto
                print("ERRO Numero de parametros nao esta de acordo com a idl")
                return "ERRO Numero de parametros nao esta de acordo com a idl. Recebido: " .. #params .. " , esperado: " .. inArgs
            end
            for i = 1, inArgs do -- checando tipos, 
                local err
                if inputs[i].type == structTbl.name then
                    err = checkStructType(params[i], structTbl.fields)
                else
                    err = checkSimpleType(inputs[i].type, params[i])
                end
                
                if err then
                    return err
                end
                values[#values + 1] = params[i]
            end

            --- Execução remota
            print("Conectando ao Servidor: " .. hostname .. " na porta: " .. port)

            local client, err = socket.connect(hostname, port)
            
            if client == nil then
                return "Erro ao conectar ao servidor no ip " .. hostname .. " porta " .. port .. " erro:" .. err
            end
            -- construindo requisicao
            msg = {type = "REQUEST", method = name, params = values}
            request =  msgHandler.encode(msg) -- faz o encode de lua obj para json

            -- envia requisicao
            print("enviando RPC ao servidor")
            error = socket.skip(1, client:send(request .. "\n"))
            if error then
                print("Erro enviando msg ao servidor RPC. " .. error)
                return "Erro enviando msg ao servidor RPC. " .. error
            end

            local result, error = client:receive("*l")

            if error then
                local err_msg = "Erro de comunicação na resposta recebida do servidor pelo cliente! Erro: "
                if message == nil then
                    print(err_msg .. error)
                    return err_msg .. error
                else
                    print(err_msg .. error, "Message: " .. message)
                    return err_msg .. error, "Message: " .. message
                end  
            end
        
            if result == nil then -- (não deve acontecer nunca o if anterior deveria cobrir)
                return "Erro mensagem recebida eh nil mas flag de erro não está ligada... Erro inexperado"
            end
            client:close() -- fecha a conexão com o servidor rpc
            resultObj = msgHandler.decode(result)

            if string.lower(resultObj.type) ~= "response" then
                print("Cliente recebeu resposta de erro na RPC. result type: " .. resultObj.type)
                return resultObj.error 
            else
                return nil, table.unpack(resultObj.result)
            end
        end
    end
    return functions
end

-- recebe um cliente recebe a msg faz a chamada ao metodo decrito na msg e faz as verificações de retorno
-- em caso de sucesso envia msg do tipo "RESULT"
-- em caso de erro envia msg do tipo "ERROR"
function handleClient(client)
    client:settimeout(1.0)
    local message, error = client:receive("*l")

    if error then
        if message == nil then
            print("Erro mensagem recebida do cliente eh nil! Erro: " .. error)
        else
            print("Erro mensagem recebida do cliente eh nil! Erro: " .. error, "Message: " .. message)
        end
        return
    end

    if message == nil then -- (não deve acontecer nunca o if anterior deveria cobrir)
        return "Erro mensagem recebida eh nil mas flag de erro não está ligada... Erro inexperado"
    end
            
    msgObj = msgHandler.decode(message)
    local ip, port = client:getsockname()
    serverObj = serverObjPortMap[port]

    -- tipo da msg tem que ser request
    if string.lower(msgObj.type) ~=  "request" then
        print("Erro, o tipo da mensagem deveria ser request. Recebido: " .. msgObj.type)
        print(msgObj.type)
        response = createResponse("ERROR", "Erro, o tipo da mensagem deveria ser request. Recebido: " .. msgObj.type, msgObj.method)
        client:send(msgHandler.encode(response) .. "\n")
        return
    end

    if serverObj[msgObj.method] == nil then 
        print("ERRO Critico, metodo não encontrado no objeto! method: ", msgObj.method)
        response = createResponse("ERROR", "ERRO Critico, metodo não encontrado no objeto!", msgObj.method)
        client:send(msgHandler.encode(response) .. "\n")
        return
    end
    local resp = nil
    print("Executando metodo " .. msgObj.method .. " no servidor")
    if msgObj.params then
        resp = table.pack(serverObj[msgObj.method](table.unpack(msgObj.params)))
    else -- metodo void
        resp = table.pack(serverObj[msgObj.method]())
    end
    -- removendo campo com tamanho da table criado pelo table.pack
    resp["n"] = nil
    local response = nil

    -- checando se os tipos retornados correspondem aos esperados
    local retErr = serverObj.checkReturnTypes(resp, msgObj.method)
    if retErr then -- erro nos tipos da resposta
        print("Erro nos tipos de retorno da função " .. msgObj.method)
        print("Erro: " .. retErr)
        response = createResponse("ERROR", "Erro nos parametros de retorno. ".. retErr, msgObj.method)
    else
        print("Execução bem sucedida no servidor. Fução: " .. msgObj.method)
        response = createResponse("RESPONSE", resp, msgObj.method)
    end
    client:send(msgHandler.encode(response) .. "\n")
end



------ Função exportada pelo módulo
--- Fica aguardando receber chamadas nos servervants criados
--- quando recebe uma conexao a funçao handleClient trata aguardando o receive com timeout de 1.0 em caso de timeout trata como erro
function module.waitIncoming()
    if #servers == 0 then -- caso nenhum servidor tenha sido criado corretamente
        print("Não há servidores cadastrados")
        return
    end
    while (true) do
        local ready = socket.select(servers) 
        for index, server in ipairs(ready) do
            server:settimeout(1.0) -- mesmo com o select devemos usar o settimeout para evitar bloqueio

            local client, error = server:accept()
            if client ~= nil then
                handleClient(client)
            else
                if error == nil then error = "nil" end
                print("waitIncoming", "Erro! Não foi possivel dar server:accept. Erro: " .. error)
            end  
        end
    end
end

function createResponse(type, msg, method)
    local obj = {}
    obj["type"] = type
    if method then
        obj["method"] = method
    end
    local key = "error"
    if string.lower(type) == "request" then
        key = "params"
    elseif string.lower(type) == "response" then
        key = "result"
    end
    obj[key] = msg
    return obj
end

return module