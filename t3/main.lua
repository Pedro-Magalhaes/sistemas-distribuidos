local mqtt = require("mqtt_library")
local cfg = require("config")
local json = require("json")
local logBuilder = require("log")

-- Globals
local nodeId = "1"
local elapsedTime = 0 -- counter to reset the event table
local neighbours = {}
local neighboursCount = 0
local events = {} -- events that has seen
local quiting = false -- will be used not to loop the close event thugh mqtt when closing the app

local mqttClient
local objList = {}
local log = nil
local colors = {white = {1, 1, 1}, green = {0.2, 0.7, 0.2}, black = {0, 0, 0}, blue = {0.2, 0.2, 0.7}}

local logSize = cfg.log.lines or 10

-- MQTT functions

local function split(s, sep)
  local fields = {}

  local sep = sep or " "
  local pattern = string.format("([^%s]+)", sep)
  string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)

  return fields
end

local function getRandomneighbourId(neighboursTable, count)
  neighboursTable = neighboursTable or neighbours
  count = count or neighboursCount

  local index = math.random(1, count)
  local neighbourId
  for id, _ in pairs(neighboursTable) do
    if index == 1 then
      neighbourId = id
      break
    end
    index = index - 1
  end
  return neighbourId
end


-- CORE FUNCTION respond to Event
-- Function that creates an agent to disseminate an event
local function handleAgent(topic, msg)
  msg.hops = msg.hops + 1
  msg.seen[nodeId] = true
  for name, e in pairs(msg.events) do
    local hops = e.hops + 1
    if events[name] and tonumber(events[name].hops) < hops then -- my path is better
      log.add("I have a better path to " .. name .. " Agent hops was " .. hops .. " mine is " .. events[name].hops)
    else -- did not see the event or my path was worst
      log.add("Agent has a better path to " .. name .. " adjusting my event table")
      events[name] = {hops = hops, source = msg.from}
    end
  end

  local agentTtl = tonumber(msg.ttl) - 1
  if agentTtl > 0 then
    local foundCandidate = false
    for id, _ in pairs(neighbours) do
      if msg.seen[tostring(id)] == nil then -- not visited by the agent, will foward to it
        foundCandidate = true
        msg.events = events
        msg.ttl = agentTtl
        msg.from = nodeId
        msg.to = id
        msg.seen[nodeId] = true
        log.add("Fowarding agent to node " .. id)
        mqttClient:publish(topic, json.encode(msg))
        break --send to only one
      end
    end
    if foundCandidate == false then -- all neighbours were in the "seen" tbl
      log.add("Agent dead end. total hops: " .. msg.hops)
    end
  else
    log.add("Agent time to live has finished. Total hops: " .. msg.hops)
  end
end

local function handleQuery(topic, msg)
  local event = msg.name
  msg.from = nodeId
  msg.hops = msg.hops + 1

  if event == "return" then -- case of query returning to the origin
    local nextNode = table.remove(msg.path,#msg.path)
    if nextNode == nil then
      log.add("Query returned to query origin! Total hops: " .. msg.hops)
      return
    else
      msg.to = nextNode
      mqttClient:publish(topic, json.encode(msg))
      log.add("Routing query response back to origin. Next: " .. nextNode)
      return
    end
  end

  -- CORE FUNCTION respond to Query
  -- case query trying to reach an event
  local ttl = msg.ttl - 1
  msg.seen[nodeId] = true
  local to
  if events[event] ~= nil then
    if tostring(events[event].source) == tostring(nodeId) then -- current node is the source
      log.add("Event query reached event source")
      local nextNode = table.remove(msg.path,#msg.path)
      msg.name = "return"
      msg.to = nextNode
      log.add("Returning with msg: " .. json.encode(msg))
      mqttClient:publish(topic, json.encode(msg))
      return
    else -- node has route
      to = events[event].source
      log.add("Node has a route to: " .. topic)
    end
  else -- has no route should pick a neighbour
    if ttl < 1 then
      log.add("Query failed, TTL expired")
      return
    end
    local possibleNeighbours = {}
    local possibleCount = 0
    for k,_ in pairs(neighbours) do
      if msg.seen[tostring(k)] == nil then
        possibleNeighbours[k] = true
        possibleCount = possibleCount + 1
      end
    end
    if possibleCount == 0 then
      log.add("Dead end. No candidate to continue the query")
      return
    end
    to = tostring(getRandomneighbourId(possibleNeighbours, possibleCount))
  end
  msg.to = to
  msg.ttl = ttl
  table.insert(msg.path, nodeId)
  log.add("Fowarding: " .. json.encode(msg))
  mqttClient:publish(topic, json.encode(msg))
end


local function mqttcb(topic, message)
  local msg = json.decode(message)

  if msg.type == "close" then -- respont to a close event in any topic
    quiting = true
    love.event.quit(0)
  end

  local to = tostring(msg.to)
  local from = msg.from

  if (neighbours[from] == true and nodeId == to) then
    log.add("Received: " .. topic .. ": " .. json.encode(message))
    if tonumber(msg.ttl) > 0 then
      if msg.type == "agent" then
        handleAgent(topic, msg)
      else
        log.add("Query")
        handleQuery(topic, msg)
      end
    else
      log.add(msg.type .. " " .. msg.name .. " TTL expired")
    end
  end
end

local function mqttIntialize()
  mqttClient = mqtt.client.create(cfg.mqtt.server.ip, cfg.mqtt.server.port, mqttcb)
  if not mqttClient then
    print("ERROR. Could not create mqtt client. Conection info:")
    print("ip:", cfg.mqtt.server.ip, "port:", cfg.mqtt.server.port)
  end
  local err = mqttClient:connect(nodeId)
  if err then
    print("ERROR. Could not connect to mqtt. Connection id: ", nodeId)
    print("Hint: check if id is not unique")
  end
  print(mqttClient:subscribe(cfg.mqtt.events))
end

-- BTN functions

--[[
  Recebe:
    "point", obj com as chaves x,y
    "obj", obj com as chaves x,y,width e height
    "xTolerance" tolerancia aceita em x
    "yTolerance" tolerancia aceita em y (para que o hitbox)
  retorna:
    true: se o ponto está dentro do obj (considerando a tolerancia)
    false: se não
]]
local function pointIsOn(point, obj, xTolerance, yTolerance)
  local xTol = xTolerance or 2
  local yTol = yTolerance or 2
  local function isWhithin(pPosition, objPosition, objLenth, tol)
    return (pPosition + tol >= objPosition) and (pPosition - tol <= objPosition + objLenth)
  end
  return isWhithin(point.x, obj.x, obj.width, xTol) and isWhithin(point.y, obj.y, obj.height, yTol)
end

local function createBtn(x, y, width, height, color, text, callback)
  local btn = {}
  btn.x = x
  btn.y = y
  btn.width = width
  btn.height = height
  btn.color = color
  btn.text = text

  btn.draw = function()
    local mode = "line"
    if events[btn.text] ~= nil then mode = "fill" end
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(btn.color)
    love.graphics.rectangle(mode, x, y, width, height)
    love.graphics.setColor(colors.white)
    love.graphics.printf(btn.text, btn.x, btn.y, btn.width)
    if events[btn.text] ~= nil then
      love.graphics.printf("dist-src: "..events[btn.text].hops .. "-" .. events[btn.text].source, btn.x, btn.y+10, btn.width)
    end
    love.graphics.setColor(r, g, b, a)
  end

  btn.checkClick = function(mx, my)
    if pointIsOn({x = mx, y = my}, {x = x, y = y, width = width, height = height}) then callback(text) end
  end
  return btn
end

-- Initialization functions

local function queryBtnCallback(name)
  local event = split(name,"-")[2] -- TODO: melhorar forma de pegar
  local hops
  local to
  
  if events[event] ~= nil then -- has seen the event
    hops = events[event].hops
    to = events[event].source
    if hops == 0 then
      log.add("I am the event source, no need for a query")
      return
    else -- i have a route, will not decrease query ttl
      log.add("Has route to event. Distance: " .. hops)
    end
  else -- didint see the event, must create a query to a random neighbour
    to = getRandomneighbourId() -- will send the query to a random node
    log.add("I never seen the event, will ask the random node")
  end
  
  log.add("Creating query for event " .. name .. "to: " .. to)
  local msg = json.encode({
    from = nodeId,
    to = to,
    type = "query",
    name = event,
    path = { [1] = nodeId },
    ttl = cfg.query.ttl,
    hops=0,
    seen= {[nodeId]=true}
  })
  mqttClient:publish(name, msg)
end

local function eventBtnCallback(name)
  events[name] = {hops = 0, source = nodeId}
  if math.random() < cfg.agent.probability then -- check if agent will be created
    local to = getRandomneighbourId()

    log.add("Creating agent for event " .. name .. "to: " .. to)
    local msg = json.encode({
      from = nodeId,
      to = to,
      type = "agent",
      name = name,
      events = events,
      ttl = cfg.agent.ttl,
      seen= {[nodeId]=true},
      hops=0
    })
    mqttClient:publish(name, msg)
  else
    log.add("Agent will not be created for event " .. name)
  end
end

local function initializeInterface()
  local hSpace = 20
  local wSpace = 20

  -- adding btns
  for i, b in ipairs(cfg.window.btn) do -- each event will have a button to trigger it a a node
    local btnW = b.width or 100
    local btnH = b.height or (3 * (btnW / 4))
    local x = (i * wSpace) + (i - 1) * btnW
    local callback
    if string.sub(b.title,1,1) == "q" then -- its a query TODO: find a better way to check if is query or event
      callback = queryBtnCallback
    else
      callback = eventBtnCallback
    end
    local btn = createBtn(x, hSpace, btnW, btnH, colors[b.color], cfg.window.btn[i].title, callback)
    table.insert(objList, btn)
  end

  local w, h = love.window.getDesktopDimensions()
  w = w / cfg.matrix.collums
  h = (h - 120) / cfg.matrix.lines -- minus 120 to account for windows title + ubuntu top screen
  love.window.setMode(w, h, {resizable = true})
  love.window.setTitle('node: ' .. nodeId)
end

local function setInitialPosition(id, colums, height, width)
  local yMultiplier = math.floor(id / colums)
  local xMultiplier = id % colums

  local x, y = xMultiplier * width, yMultiplier * height
  love.window.setPosition(x, y)
end

-- zero based matrix, first element is on line 0, collum 0
-- will not include diagonals
local function initializeNeighbours()
  local line = math.floor(nodeId / cfg.matrix.collums)
  local collum = nodeId % cfg.matrix.collums

  local pontentialNeighbours = {
    {line = line - 1, col = collum}, {line = line + 1, col = collum}, {line = line, col = collum - 1},
    {line = line, col = collum + 1}
  }
  for _, v in ipairs(pontentialNeighbours) do
    -- check if line is between [0-num_lines) e collum [0-num-collums)
    if v.line >= 0 and v.line < cfg.matrix.lines and v.col >= 0 and v.col < cfg.matrix.lines then
      local neighbourId = (v.line * cfg.matrix.collums) + (v.col % cfg.matrix.collums)
      neighbours[tostring(neighbourId)] = true
      neighboursCount = neighboursCount + 1
    end
  end

end

-- Love functions

function love.load(arg)
  nodeId = arg[1]
  log = logBuilder.creteLog(logSize, true, cfg.log.path, cfg.log.baseName .. nodeId, nodeId)
  log.add("Initializing simulation for node **********")
  mqttIntialize()
  initializeNeighbours()
  initializeInterface()
  setInitialPosition(nodeId, cfg.matrix.collums, cfg.window.height, cfg.window.width)
end

function love.draw()
  for _, value in pairs(objList) do value.draw() end
  local r, g, b, a = love.graphics.getColor()
  love.graphics.setColor(colors.white)
  local w = love.window.getMode()
  love.graphics.printf(log.getText(), cfg.window.log.x, cfg.window.log.y, w - 20)
  love.graphics.setColor(r, g, b, a)
end

function love.update(dt)
  if cfg.event.timeToReset ~= nil then
    elapsedTime = elapsedTime + dt
    if elapsedTime > cfg.event.timeToReset then
      elapsedTime = 0
      log.add("Reseting event tables")
      events = {}
    end
  end
  if mqttClient.connected == true then
    mqttClient:handler()
  end
end

-- shutdown
function love.quit()
  log.add("Shutting down\n\n")
  log.close()
  
  if quiting == false then
    mqttClient:publish(cfg.mqtt.events[1], json.encode({type="close"}))  
  end
  if mqttClient.connected == true then
    mqttClient:disconnect()
  end
end

function love.mousepressed()
  local x, y = love.mouse.getPosition()
  for _, obj in pairs(objList) do obj.checkClick(x, y) end
end
