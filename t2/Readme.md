Trabalho de Raft - Pedro Magalhães

# Arquivos

* config.lua

    Contem uma tabela com as portas que podemos usar para os servidores. Fiz isso para facilitar a comunicação e saber quais portas estãos sendo usadas
    
    Ia criar aqui os proxies mas como não usei processos separados de fato, passei o numero de servidores na criação no serve.lua e fiz a criação no proprio raft.lua 

* raft.lua 

  Implementação das funções RPC e do "obj" que guarda o estado de um membro do algoritmo

* server.lua 

  Instancia os objetos e cria o servelet RPC. O server recebe 3 parametros para facilitar a criação de servelets em processos diferentes.
  
  Nos meus testes eu criava todos os servelets no mesmo processo para facilitar o debug. 

* client.lua

    faz a chamada ao node Initialize. Recebe 2 parametros o primeiro é a porta do server e segundo indica a ação que deve ser feita
       Se não passarmos o segundo parametro a função Initialize é chamada, se passarmos 0 a função stopNode é chamada (finaliza um servidor)
        se passarmos -1 a função snapShot é chamada e printa no console do servidor algumas informações do servidor. Qualquer outro faz o no dormir por 10s


# Relatório

Tive bastante dificuldade nesse trabalho para debugar os erros que estava tendo, estou tendo um bug intermitente que não consegui resolver 100%
Em algumas execuções o luarpc.wait() para de respeitar o tempo de timeout e por vezes um ou mais servidores passam a fazer o loop sem "dormir" 
o que acaba gerando logs gigantes. Fiz algumas alterações no arquivo luarpc.lua e vi que algumas variaveis era usadas como globais (sem o "local"), alterando isso O
problema diminuiu bastante mas ainda acontece. 1 a cada 10 rodadas o wait parava de funcionar, reparei que o erro ocorria principalmente logo após 
algum nó ser eleito

Para executar estava executando o seguinte comando: (por  padrão cria 3 servidores nas portas 31111, 32222,33333)

$ lua server.lua >> log.txt

Em seguida abria os clientes em terminais diferentes:

$ lua client.lua 33333

$ lua client.lua 32222

$ lua client.lua 31111

Para parar um servidor que está rodando:

$ lua client.lua 33333 0

Para dar sleep de 10s:

$ lua client.lua 33333 2


Coloquei logs demonstrando o funcionamento normal e os bugs que tive:

* Normal:
* 
log-5servers.txt

log-Leader-failure.txt

log1.txt (tem varias execuções diferentes no mesmo log)

log-apenas-2de3-inicializados.txt

* Com erro:
* 
log-falha-temporaria-wait-quebrou.txt

log-DeadLock-Eleiçao-simultanea.txt

log-erro-wait.txt

