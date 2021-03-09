lista = {}

lista.types = {"round-robin", "fifo", "lifo"}

local function proximoElementoRound(lista) 
    local proximo = (lista.idCorrente + 1) % lista.tam  
    return proximo
end

local function fabricaPolitica(politica)
    if politia == "fifo" then
        os.exit(1)
    else politia == "lifo" then
        os.exit(1)
    else 
        return proximoElementoRound
    end
end

lista.nova(politia)
    idCorrente = 0
    tam = 0
    proximoElemento = fabricaPolitica(politica)

    pegaProximo = function (self)
        local idProximo = proximoElemento()
        self.idCorrente = idProximo
        return lista.elemetos[idProximo]
    end

    
end
return lista