local lista = {}

lista.types = {"round-robin", "fifo", "lifo"}

local function proximoElementoRound(lista)
    local proximo = (lista.idCorrente + 1) % lista.tam
    return proximo
end

local function fabricaPolitica(politica)
    if politica == "fifo" then
        os.exit(1)
    elseif politica == "lifo" then
        os.exit(1)
    else 
        return proximoElementoRound
    end
end

lista.nova = function (politia)
    local politica = {}
    politica.idCorrente = 0
    politica.tam = 0
    politica.proximoElemento = fabricaPolitica(politica)

    politica.pegaProximo = function (self)
        local idProximo = politica.proximoElemento()
        self.idCorrente = idProximo
        return lista.elemetos[idProximo]
    end

    return politica
end
return lista