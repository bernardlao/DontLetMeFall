display.setStatusBar( display.HiddenStatusBar )
local composer = require("composer")
display.setDefault( "background", 0.2,0.5,1.0 )
local scene = composer.newScene(  )
local screenW = display.contentWidth
local screenH = display.contentHeight
local halfW = display.contentWidth * 0.5
local halfH = display.contentHeight * 0.5

local sqlite3 = require("sqlite3")
local path = system.pathForFile( "game.db",system.DocumentsDirectory )
local db = sqlite3.open(path)
local userID = -1
local ballID = -1
local createTable = [[CREATE TABLE IF NOT EXISTS tblScore (UserID INTEGER PRIMARY KEY AUTOINCREMENT, Score INTEGER);]]
db:exec(createTable)


local cloud = nil
local barrel = nil
local group = display.newGroup()

local function playClicked(  )
	audio.stop({channel=2})
	group:removeSelf()
	group = nil
	--local stage = display.getCurrentStage()while stage.numChildren > 0 do	local obj = stage[1]	obj:removeSelf()	obj = nil end
	composer.gotoScene("scenes.maingame")
end

local function GetScore ()
  for row in db:nrows("SELECT UserID FROM tblScore") do
    if row.UserID == nil then
      hasScore = false
    else
      hasScore = true
      userID = row.UserID
    end
  end
  for row in db:nrows("SELECT Score FROM tblScore WHERE UserID="..userID) do
    if row.Score == nil then
      return 0
    else
      return row.Score
    end
  end
  return 0
end
local function getBall( )
  for row in db:nrows("SELECT ballID FROM tblBall") do
    if row.ballID == nil then
      ballID = -1
    else
      ballID = row.ballID
    end
  end
  for row in db:nrows("SELECT ballName FROM tblBall WHERE ballID="..ballID) do
    if row.ballName == nil then
      return "default_egg.png"
    else
      return row.ballName
    end
  end
  return "default_egg.png"
end
audio.setVolume(1.0)
local backgroundMusic = audio.loadStream("sound/main.wav")
local soundOpt = {
channel = 2,
loops= -1,
fadeIn = 5000
}
bgSound = audio.play(backgroundMusic,soundOpt)

--end sound




cloud = {}
cloud[1] = display.newImageRect("images/cloud1.png",150,100)
cloud[1].x = math.random(screenW * 0.40,screenW * 0.50)
cloud[1].y = 75
cloud[2] = display.newImageRect("images/cloud2.png",150,100)
cloud[2].x = math.random(75,screenW * 0.20)
cloud[2].y = 200
cloud[3] = display.newImageRect("images/cloud3.png",150,100)
cloud[3].x = math.random(screenW * 0.80,screenW * 0.90)
cloud[3].y = 325
cloud[4] = display.newImageRect("images/cloud3.png",150,100)
cloud[4].x = math.random(screenW * 0.20,screenW * 0.40)
cloud[4].y = 400
cloud[5] = display.newImageRect("images/cloud3.png",150,100)
cloud[5].x = math.random(screenW * 0.50,screenW * 0.70)
cloud[5].y = 550
group:insert(cloud[1])
group:insert(cloud[2])
group:insert(cloud[3])
group:insert(cloud[4])
group:insert(cloud[5])
local options = {
  text = "BEST SCORE \n "..GetScore(),
  x = halfW,
  y = halfH * 0.30,
  width = screenW,
  font = "Broadway",
  fontSize = 50,
  align ="center"
}
local hsText = display.newText(options)
hsText:setFillColor(0,1,1)
group:insert(hsText)
options = {
  text = "Don't Let Me Fall",
  x = halfW,
  y = halfH * 0.60,
  width = screenW,
  font = "Jokerman",
  fontSize = 90,
  align ="center"
}
local title = display.newText(options)
title:setFillColor(0,0,0)
group:insert(title)
local wingsSheet = graphics.newImageSheet("images/wings.png",{width=385,height=200,numFrames=4})
local wingSeq = {sheet=wingsSheet,start=1,count=4,time=500,loopCount=0,loopDirection="bounce"}
barrel = display.newImageRect("images/barrel.png",120,150)
barrel.x = halfW
barrel.y = halfH + (halfH * 0.3)
group:insert(barrel)
local barrelWings = display.newSprite(wingsSheet,wingSeq)
barrelWings.x = barrel.x
barrelWings.y = barrel.y
barrelWings.xScale = 0.7
barrelWings.yScale = 0.7
barrelWings:play()
group:insert(barrelWings)
barrel:toFront()
barrel:addEventListener("tap",playClicked)
local bg = display.newImageRect("images/bg.png",screenW,screenH)
bg.x = halfW
bg.y = halfH + (halfH * 0.4)
group:insert(bg)

options = {
  text = "Tap the Barrel to Play",
  x = halfW,
  y = barrel.y + 80,
  width = screenW,
  font = "Broadway",
  fontSize = 30,
  align ="center"
}
local helpText = display.newText(options)
helpText:setFillColor(0,1,0)
group:insert(helpText)

options = {
  text = "Select your Ball Below",
  x = halfW,
  y = helpText.y + 80,
  width = screenW,
  font = "Broadway",
  fontSize = 40,
  align ="center"
}
local selectBall = display.newText(options)
selectBall:setFillColor(0,1,0)
group:insert(selectBall)

local function getBallIndex(ball)
  if ball == "default_egg.png" then
    return 1
  elseif ball == "golden_egg.png" then
    return 2
  elseif ball == "ball.png" then
    return 3
  elseif ball == "steelball.png" then
    return 4
  end
end
local shader = nil
local balls = {}
local function imageClicked( event )
  local name = event.target.name
  local index = getBallIndex(name)
  shader.x = balls[index].x
  shader.y = balls[index].y
  local query = [[UPDATE tblBall SET ballName=']]..name..[[' WHERE ballID=]]..ballID
  db:exec(query)
  print(name..ballID)
end
function scene:create( event )
  local ballTable = [[CREATE TABLE IF NOT EXISTS tblBall (ballID INTEGER PRIMARY KEY AUTOINCREMENT, ballName TEXT);]]
  db:exec(ballTable)
  local ballName = getBall()
  if(ballName == "default_egg.png" and ballID == -1) then
    local query = [[INSERT INTO tblBall(ballName) VALUES('default_egg.png');]]
    db:exec(query)
    print("created 1")
  end
  ballName = getBall()
  balls[1] = display.newImageRect("images/default_egg.png",65,65)
  balls[1].x = screenW * 0.20
  balls[1].y = selectBall.y + 100
  balls[1].name = "default_egg.png"
  balls[2] = display.newImageRect("images/golden_egg.png",65,65)
  balls[2].x = screenW * 0.40
  balls[2].y = selectBall.y + 100
  balls[2].name = "golden_egg.png"
  balls[3] = display.newImageRect("images/ball.png",65,65)
  balls[3].x = screenW * 0.60
  balls[3].y = selectBall.y + 100
  balls[3].name = "ball.png"
  balls[4] = display.newImageRect("images/steelball.png",65,65)
  balls[4].x = screenW * 0.80
  balls[4].y = selectBall.y + 100
  balls[4].name = "steelball.png"
  group:insert(balls[1])
  group:insert(balls[2])
  group:insert(balls[3])
  group:insert(balls[4])
  local ballIndex = getBallIndex(ballName)
  shader = display.newCircle(balls[ballIndex].x,balls[ballIndex].y,50)
  shader.alpha = 0.4
  group:insert(shader)

  balls[1]:addEventListener("tap",imageClicked)
  balls[2]:addEventListener("tap",imageClicked)
  balls[3]:addEventListener("tap",imageClicked)
  balls[4]:addEventListener("tap",imageClicked)
end
--ballSelector



scene:addEventListener("create",scene)
composer.removeScene("scenes.gameover")
return scene
--composer.gotoScene("scenes.maingame")
