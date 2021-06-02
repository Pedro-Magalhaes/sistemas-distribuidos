local number = 0
local dtSum = 0
local objList = {}

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
local function pointIsOn(point,obj, xTolerance, yTolerance)
  local xTol = xTolerance or 2
  local yTol = yTolerance or 2
  local function isWhithin(pPosition,objPosition,objLenth, tol)
    return (pPosition + tol >= objPosition) and (pPosition - tol <= objPosition+objLenth)
  end
  return isWhithin(point.x,obj.x,obj.width, xTol) and isWhithin(point.y, obj.y,obj.height, yTol)
end

local function createBtn(x, y, width, height, color, text)
  local btn = {}
  btn.x = x
  btn.y = y
  btn.width = width
  btn.height = height
  btn.color = color
  btn.text = text

  btn.draw = function ()
    love.graphics.rectangle("fill", btn.x, btn.y, btn.width, btn.height)
  end

  btn.checkClick = function (x,y)
    if pointIsOn({x = x, y = y}, btn) then
      print("Hit on " .. btn.text)
    end
  end
  return btn
end

local function initializeInterface()
  local hSpace = 20
  local wSpace = 20
  local btnW = 100
  -- local btnH = 80
  local btnH = 3 * (btnW / 4)
  local btn1 = createBtn(wSpace,hSpace,btnW,btnH,"green", "btn1")
  table.insert(objList,btn1)
end


function love.load()
  objList = {}

  -- Remember: camelCasing!
  initializeInterface()
end

function love.draw()
  for _, value in pairs(objList) do
    value.draw()
  end
end

function love.update(dt)
  dtSum = dtSum + dt
  if dtSum > 1 then
    dtSum = 0
    number = number + 1
  end
end

function love.keypressed(key)
  -- print(key)
  if key == "space" then
    print("space pressed")
    print(number)
  elseif key == "escape" then
    love.event.quit()
  end
end

function love.mousepressed()
  local x,y = love.mouse.getPosition()
  print(x,y)
  for _, obj in pairs(objList) do
    obj.checkClick(x,y)
  end
end
