struct = {
    name = "messageStruct",
    fields = {
      {name = "term", type = "int"},
      {name = "from", type = "int"},
      {name = "to", type = "int"},
      {name = "type", type = "string"},
      {name = "value", type = "string"}
    }
  }

  interface = {
   name = "Raft",
   methods = {
     receiveMessage = {
       resulttype = "string",
       args = {
         {direction = "in", type = "messageStruct"}
       }
     },
     initializeNode = {
       resulttype = "void",
       args = {
       }
     },
     stopNode ={
      resulttype = "void",
      args = {
        {direction= "in", type="int"} -- tempo de pausa ( 0 para nao voltar?) tenho que rever o comportamento
      }
     },
     appendEntry ={  --heartBeat
      resulttype = "string",
      args = {
        {direction= "in", type="int"}
      },
     },
      snapshot ={
        resulttype = "void",
        args = {
        }
      },
    }
  }
