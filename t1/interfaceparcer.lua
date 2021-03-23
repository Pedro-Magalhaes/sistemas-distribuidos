-- Retorna como primeiro argumento se ocorreu erro verificando a interface, em caso de sucesso retorna nil
function read(interface) -- recebe a string do arquivo, vou assumir que a string cabe em memória
    local i1,j1 =  string.find(interface, "struct")
    local i2,j2 = string.find(interface, "interface")

    -- check if interface exists
    if i2 == nil or i2 < 0 then print("erro: interface nao encontrada"); os.exit(-1) end
    -- check if struct exists
    if i1 == nil or i1 < 0 then i1 = i2; j1 = j2 end
    
    -- TODO: testar i's e j's
    local st = string.sub(interface, j1 + 1, i2 - 1)
    local inter = string.sub(interface, j2 + 1, #interface)

    local error, reason = checkStructs(st)
    if error then
      return "Struct Error", reason
    end
    error, reason = checkFunctions(st, inter)
    if error then
      return "Function Error", reason
    end

    -- Como checar erros?
    st = load("return " .. st)()
    inter = load("return " .. inter)()
    return nil, st, inter

end

-- Recebe a struct estraida e verifica se as structs usam os tipos corretos
-- incluindo as structs declaradas. Exemplo st a {int,int}, st b {a,string}
-- em caso de sucesso retorna nil
function checkStructs(st)
  return nil
end

-- Verifica as funções para ver se seguem os padroes de tipo
-- em caso de sucesso retorna nil
function checkFunctions(st, inter)
  return nil
end

----- TESTES:
local teste_string = [[ struct { name = "minhaStruct",
fields = {{name = "nome",
           type = "string"},
          {name = "peso",
           type = "double"},
          {name = "idade",
           type = "int"}
          }
} 
interface { name = "minhaInt",
   methods = {
      foo = {
        resulttype = "double",
        args = {{direction = "in",
                 type = "double"},
                {direction = "in",
                 type = "string"},
                {direction = "in",
                 type = "minhaStruct"},
                {direction = "out",
                 type = "int"}
               }

      },
      boo = {
        resulttype = "void",
        args = {{direction = "in",
                 type = "double"},
                {direction = "out",
                 type = "minhaStruct"}
               }
      }
    }
   }]]

local s,i = read(teste_string)

print(s,i)

print(i["name"])
print(s["name"])
