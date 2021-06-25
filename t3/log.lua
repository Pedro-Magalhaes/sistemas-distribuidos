local log = {}

-- log functions
log.creteLog = function(bufferSize, saveToDisk, basePath, filename, nodeId)
  local internalBufferSize = bufferSize * 2 -- vou guardar o dobro pra economizar writes
  local textBuffer = {}
  local initialPosition = 1
  local currPosition = internalBufferSize
  local lastSavedPosition = internalBufferSize
  local isOvewriting = false

  -- basePath = basePath or cfg.log.path
  -- filename = filename or cfg.log.baseName .. nodeId
  local filePath = basePath .. "/" .. filename
  local logFile = io.open(filePath, "a+")
  if logFile == nil then
    textBuffer[1] = "ERRO, ARQUIVO DE LOG NÃO CRIADO - path: " .. filePath
    currPosition = 1
    print("ERRO, ARQUIVO DE LOG NÃO CRIADO")
  end

  local function fileIsOpen(fileHandler)
    if io.type(fileHandler) == "file" then return true end
    return false
  end

  local function getText()
    local numberOfLines = bufferSize
    local text = ""
    local pos = initialPosition
    while numberOfLines > 0 do
      numberOfLines = numberOfLines - 1
      if textBuffer[pos] ~= nil then
        text = text .. "\n" .. textBuffer[pos]
        pos = (pos % internalBufferSize) + 1
      end
    end
    return text
  end

  local function nextPos(pos)
    if isOvewriting == false and pos == bufferSize then isOvewriting = true end
    if (pos + 1) <= internalBufferSize then return pos + 1 end
    return 1
  end

  -- get the a string from the buffer [from,stopPosition) (does no include stopPosition)
  -- each entry is separeted by a \n
  local function getStringToSave(from, stopPosition)
    stopPosition = stopPosition or initialPosition
    local stringToSave = ""
    while from ~= stopPosition do
      local s = textBuffer[from]
      from = (from % internalBufferSize) + 1
      if s ~= nil then stringToSave = stringToSave .. s .. "\n" end
    end
    return stringToSave
  end

  local function persist(untilPos)
    if fileIsOpen(logFile) then
      local s = getStringToSave(lastSavedPosition, untilPos)
      logFile:write(s)
    else
      print("COULD NOT PERSIST TO FILE!")
      print(logFile)
    end
  end

  local function checkBufferAndSave()
    if nextPos(currPosition) == lastSavedPosition then -- will overwrite not persisted position in the next "add"
      local pos = lastSavedPosition
      local stringToSave = getStringToSave(pos)
      if saveToDisk then
        persist(initialPosition)
      else
        print("Persisting to console")
        print(stringToSave)
      end
      lastSavedPosition = ((currPosition + bufferSize) % internalBufferSize) + 1
    end
  end

  return {
    getText = getText,
    add = function(s)
      if s then
        local savePosition = nextPos(currPosition)
        textBuffer[savePosition] = os.time() .. " - " .. nodeId .. ": " .. s
        currPosition = savePosition
        if isOvewriting then initialPosition = nextPos(initialPosition) end
        checkBufferAndSave()
      end
    end,
    close = function()
      persist(currPosition + 1) -- save all (persist receives the position we should stop)
      if fileIsOpen(logFile) then logFile:close() end
    end
  }
end

return log