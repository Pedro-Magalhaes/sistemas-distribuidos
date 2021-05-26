FROM nickblah/lua:5-luarocks as builder

RUN apt update && apt install gcc -y
RUN luarocks install luasocket

FROM builder
COPY *.lua /app/
COPY *.idl /app/
WORKDIR /app
ENTRYPOINT [ "lua" , "server.lua"]