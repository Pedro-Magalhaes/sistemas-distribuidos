struct = {
    name = "messageStruct",
    fields = {
      {name = "term", type = "int"},
      {name = "fromNode", type = "int"},
      {name = "toNode", type = "int"},
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
        {direction= "in", type="int"} -- tempo de pausa ( 0 para nao voltar?)
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
