local composer = require("composer")
local physics = require("physics")
physics.start()
physics.setGravity(0,9.8)
physics.setDrawMode("normal")
local scene = composer.newScene(  )
display.setDefault( "background", 0.2,0.5,1.0 )

local screenW = display.contentWidth
local screenH = display.contentHeight
local halfW = display.contentWidth * 0.5
local halfH = display.contentHeight * 0.5

local bg = nil
local group = display.newGroup()

local nextBarrel = nil
local nextBarrelPosY = screenH * 0.30
local catcher = nil
local isBallAboveBarrel = false

local item = nil
local barrel = nil
local barrelSpeed = 1500
local smoke = nil
local isAlive = true
local lives = 3
local livesImage = {}
local itemImage = nil
local ballID = -1

local obtainableScore = 40
local currentScore = 0
local scoreText = nil
local wind = 0
local windText = nil
local cloud = nil
local cloudSpeed = 0
local prevTime = 0

local sqlite3 = require("sqlite3")
local path = system.pathForFile( "game.db",system.DocumentsDirectory )
local db = sqlite3.open(path)
local userID = -1
local hasScore = false
local hsText = nil

local bgSound = nil
local fireSound = nil
local scoreSound = nil
local deadSound = nil
local gameoverSound = nil

local barrelWings = nil
local nextWings = nil
local wingsSheet = graphics.newImageSheet("images/wings.png",{width=385,height=200,numFrames=4})
local wingSeq = {sheet=wingsSheet,start=1,count=4,time=500,loopCount=0,loopDirection="bounce"}

local function onSystemEvent (event)
  if event.type == "applicationExit" then
    db:close()
  end
end

local createTable = [[CREATE TABLE IF NOT EXISTS tblScore (UserID INTEGER PRIMARY KEY AUTOINCREMENT, Score INTEGER);]]
db:exec(createTable)

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

local function playSoundOnce( soundID )
  audio.play(soundID)
  return true
end

local function updateHighScore(  )
  if hasScore == false then
    local query = [[INSERT INTO tblScore(Score) VALUES(]]..currentScore..[[);]]
    db:exec(query)
    hsText.text = "Highscore : "..currentScore
  end
  local hs = GetScore()
  if(currentScore > hs) then
    local query = [[UPDATE tblScore Set Score=]]..currentScore..[[ WHERE UserID=]]..userID
    db:exec(query)
    hsText.text = "Highscore : "..currentScore
  end
end

local function transBarrel( )
  local dir = nil
  if(barrel.x == 60)then
    dir = screenW - 60
  else
    dir = 60
  end
  transition.to( barrel, { time=barrelSpeed, x = dir, onComplete=transBarrel } )
  transition.to(barrelWings,{time=barrelSpeed,x=dir})
end

local function updateScore( score )
  if ((currentScore + score)%100) > (currentScore%100) and barrelSpeed > 700 then
    barrelSpeed = barrelSpeed - 100
  end
  currentScore = currentScore + score
  scoreText.text = currentScore
  updateHighScore()
end

local function createCatcher( )
  if catcher == nil then
    catcher = display.newLine(-45,-60,-45,60,40,60,40,-60)
    catcher.strokeWidth = 4
    catcher.x = nextBarrel.x - 43
    catcher.y = nextBarrel.y - 65
    catcher.alpha = 0
    group:insert(catcher)
    physics.addBody(catcher,"static",{isBullet = true})
  end
end

local function createNextBarrel( )
  local nextBarrelSheet = graphics.newImageSheet( "images/shrink.png",  {width=200,height=247,numFrames=8})
  local barrelSequence = {name="barrel",sheet=nextBarrelSheet,start=1,count=8,time=300,loopCount=1,loopDirection="bounce"}
  nextBarrel = display.newSprite(nextBarrelSheet,barrelSequence)
  nextBarrel.y = (nextBarrel == nil and nextBarrelPosY or -(barrel.y - nextBarrel.y))
  nextBarrel.x = math.random(60,screenW - 60)
  nextBarrel.xScale = 0.6
  nextBarrel.yScale = 0.6
  nextWings = display.newSprite(wingsSheet,wingSeq)
  nextWings.x = nextBarrel.x
  nextWings.y = nextBarrel.y
  nextWings.xScale = 0.7
  nextWings.yScale = 0.7
  nextWings:play()
  group:insert(nextWings)
  group:insert(nextBarrel)
  transition.to(nextBarrel,{time=1000,y=nextBarrelPosY})
  transition.to(nextWings,{time=1000,y=nextBarrelPosY})
  --[[nextBarrel = display.newImageRect("images/barrel.png",120,150)
  nextBarrel.y = screenH * 0.30
  nextBarrel.x = math.random(60,screenW - 60)
  group:insert(nextBarrel)]]
  --assert(group[1] == nextBarrel)
end

local function spinImage( )
  local deg = 0
  if wind > 0 then
    deg = 360
  elseif wind < 0 then
    deg = -360
  end
  if item ~= nil then
    transition.to( item, { rotation = item.rotation+deg, time=1000, onComplete=spinImage } )
  end
end

local function createSmoke(  )
  local smokeSheet = graphics.newImageSheet("images/smoke.png",{width=333,height = 333,numFrames = 9})
  local smokeSeq = {sheet=smokeSheet,start=1,count=9,time=700,loopCount=1}
  smoke = display.newSprite(smokeSheet,smokeSeq)
  smoke.x = barrel.x
  smoke.y = barrel.y - 20
  smoke:play()

  local function mySpriteListener( event )

    if ( event.phase == "ended" ) then
      smoke:removeSelf()
      smoke = nil
    end
  end

  smoke:addEventListener( "sprite", mySpriteListener ) 
end

local function getDeltaTime ()
  local currentTime = system.getTimer()
  local deltaTime = currentTime - prevTime
  prevTime = currentTime
  return deltaTime
end

local function moveClouds( )
  if #cloud ~= 0 then
    local delta = getDeltaTime()
    cloud[1].x = cloud[1].x + (cloudSpeed * 50)
    cloud[2].x = cloud[2].x + (cloudSpeed * 50)
    cloud[3].x = cloud[3].x + (cloudSpeed * 50)
  end
end

local function changeWind( )
  local nextWind = 0
  local rand = math.random(1,60)
  if rand > 30 then
    nextWind = (rand - 60)
  else
    nextWind = rand
  end
  if (nextBarrel ~= nil and nextWind ~= 0) then
    if (nextBarrel.x > halfW) then
      nextWind = (nextWind < 0 and -(nextWind) or nextWind)
    else
      nextWind = (nextWind < 0 and nextWind or -(nextWind))
    end
  end
  wind = nextWind / 10
  physics.setGravity(wind,9.8)
  cloudSpeed = wind / 10
  moveClouds()
  windText.text = "Wind : "..wind
  if ((rand >= 20 and rand <= 30) or (rand >= 30 and rand <= 40)) then
    windText:setFillColor(255,0,0)
  elseif ((rand >= 10 and rand <= 19) or (rand >= 41 and rand <= 50)) then
    windText:setFillColor(255,204,0)
  elseif ((rand >= 0 and rand <= 9) or (rand >= 51 and rand <= 60)) then
    windText:setFillColor(0,204,0)
  end
end

local function reduceObtainScore(  )
  if obtainableScore > 5 then
    obtainableScore = obtainableScore - 2
  end
end

local tmWind = timer.performWithDelay(5000,changeWind,0)
moveCloudsTime = timer.performWithDelay(100,moveClouds,0)
reduceScoreTime = timer.performWithDelay(2000,reduceObtainScore,0)
local function removeBonus( obj )
  obj:removeSelf()
  obj=nil
end
local function getBonusScore( val )
  local retVal = 0
  if(val > 2.0 or val < -2.0) then
    retVal = 10
  elseif ((val > 1.0 or val < -1.0) and (val < 2.0 or val > -2.0)) then
    retVal = 5
  end
  if retVal ~= 0 then
    local options = {
      text = "Wind Bonus! + "..retVal,
      x = halfW,
      y = scoreText.y + 300,
      width = 800,
      font = "Forte",
      fontSize = 30,
      align ="center"
    }
    local bonus = display.newText(options)
    bonus:setFillColor(0,204,0)
    transition.to(bonus,{time=500,y=scoreText.y,onComplete=removeBonus})
  end
  return retVal
end

local function afterCatch(  )
  item:removeSelf()
  item =nil
  catcher:removeSelf()
  catcher = nil
  local barrelY = barrel.y
  
  transition.to(barrel,{time=1000,y=screenH + barrel.height})
  transition.to(barrelWings,{time=1000,y=screenH + barrel.height})
  barrel = nextBarrel
  barrelWings = nextWings
  transition.to(barrel,{time=1000,y=barrelY,x=60,onComplete=transBarrel})
  transition.to(barrelWings,{time=1000,y=barrelY,x=60,onComplete=transBarrel})
  createNextBarrel()
  local currentWind = wind
  local bonusScore = getBonusScore(currentWind)
  obtainableScore = obtainableScore + bonusScore
  updateScore(obtainableScore)
  changeWind()
  tmWind = timer.performWithDelay(5000,changeWind,0)
  obtainableScore = 40
  transition.to(bg,{y=bg.y + 10,time=1000})
  playSoundOnce(scoreSound)
end
local function doGameOver(  )
  --composer.removeScene("scenes.maingame")
  --composer.gotoScene("scenes.menu")
  Runtime:removeEventListener("enterFrame",onEnterFrame)
  Runtime:removeEventListener("touch",onBackgroundTouch)
  cloud[1]:removeSelf()
  cloud[2]:removeSelf()
  cloud[3]:removeSelf()
  for i = #cloud,1,-1 do
    table.remove(cloud,i)
  end
  physics.pause()
  group:removeSelf()
  group = nil
  local parameter = {scoredVal=currentScore}
  composer.gotoScene("scenes.gameover",{params=parameter})
end
local function doDead(  )
  --audio.setVolume(0.0,{channel=1})
  livesImage[lives]:removeSelf()
  livesImage[lives] = nil
  lives = lives - 1
  print(lives)
  if lives == 0 then
    audio.stop({channel=1})
    playSoundOnce(gameoverSound)
    doGameOver()
  end
  --audio.fadeOut({channel=1,time=500})
  if(lives > 0) then
    transBarrel()
    item:removeSelf()
    item = nil
    tmWind = timer.performWithDelay(5000,changeWind,0)
    changeWind()
    catcher:removeSelf()
    catcher = nil
    playSoundOnce(deadSound)
  end
end

local function createItemAndThrow( _x,_y )
  if item == nil and lives > 0 and barrel.y == screenH - 80 then
    item = display.newImageRect("images/"..itemImage,65,65)
    item.isBullet = true
    item.x = _x
    item.y = _y
    group:insert(item)
  --assert(group[2] == item)
    physics.addBody(item,"dynamic", {density = 1.15})
    item:applyForce(0,-7500,item.x,item.y)
    spinImage()
    playSoundOnce(fireSound)
    createSmoke()
    transition.cancel(barrel)
    transition.cancel(barrelWings)
    timer.cancel(tmWind)
  end
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

local function onBackgroundTouch (event)
  if event.phase == "ended" then
    createItemAndThrow(barrel.x,barrel.y)
  end
  return true
end

function scene:create (event)
  --sound
  composer.removeScene("scenes.menu")
  itemImage = getBall()
  audio.setVolume(2.0)
  local backgroundMusic = audio.loadStream("sound/bg.wav")
  local soundOpt = {
    channel = 1,
    loops= -1,
    fadeIn = 3000
  }
  bgSound = audio.play(backgroundMusic,soundOpt)
  fireSound = audio.loadSound("sound/fire.wav")
  scoreSound = audio.loadSound("sound/score.wav")
  deadSound = audio.loadSound("sound/dead.wav")
  gameoverSound = audio.loadSound("sound/gameover.wav")
  --end sound

  local sceneGroup = self.view
  bg = display.newImageRect("images/bg.png",screenW,screenH)
  bg.x = display.contentCenterX
  bg.y = display.contentCenterY

  cloud = {}
  cloud[1] = display.newImageRect("images/cloud1.png",150,100)
  cloud[1].x = math.random(screenW * 0.40,screenW * 0.50)
  cloud[1].y = 75
  cloud[2] = display.newImageRect("images/cloud2.png",150,100)
  cloud[2].x = math.random(75,screenW * 0.20)
  cloud[2].y = 250
  cloud[3] = display.newImageRect("images/cloud3.png",150,100)
  cloud[3].x = math.random(screenW * 0.80,screenW * 0.90)
  cloud[3].y = 375
  

  barrel = display.newImageRect("images/barrel.png",120,150)
  barrel.x = halfW
  barrel.y = halfH + (halfH * 0.5)
  barrelWings = display.newSprite(wingsSheet,wingSeq)
  barrelWings.x = barrel.x
  barrelWings.y = barrel.y
  barrelWings.xScale = 0.7
  barrelWings.yScale = 0.7
  barrelWings:play()
  transition.to( barrelWings, { time=500, x = 60, y = screenH - 80 } )
  transition.to( barrel, { time=500, x = 60, y = screenH - 80, onComplete=transBarrel } )

  local options = {
    text = currentScore,
    x = halfW,
    y = 100,
    width = 800,
    font = "Forte",
    fontSize = 80,
    align ="center"
  }
  scoreText = display.newText(options)
  scoreText:setFillColor(0,102,255)
  options = {
    text = "Highscore : "..GetScore(),
    x = halfW,
    y = 30,
    width = screenW,
    font = "Forte",
    fontSize = 30,
    align ="center"
  }
  hsText = display.newText(options)
  hsText:setFillColor(255,102,0)
  options = {
    text = "Wind : "..wind,
    x = (screenW-100),
    y = 30,
    width = 800,
    font = "Forte",
    fontSize = 30,
    align ="center"
  }
  windText = display.newText(options)
  windText:setFillColor(0,0,0)

  createNextBarrel()

  --lives
  livesImage[1] = display.newImageRect("images/"..itemImage,30,30)
  livesImage[1].x = 40
  livesImage[1].y = 40
  livesImage[2] = display.newImageRect("images/"..itemImage,30,30)
  livesImage[2].x = livesImage[1].x + 40
  livesImage[2].y = 40
  livesImage[3] = display.newImageRect("images/"..itemImage,30,30)
  livesImage[3].x = livesImage[2].x + 40
  livesImage[3].y = 40
  --end

  sceneGroup:insert(bg)
  sceneGroup:insert(livesImage[1])
  sceneGroup:insert(livesImage[2])
  sceneGroup:insert(livesImage[3])
  sceneGroup:insert(cloud[1])
  sceneGroup:insert(cloud[2])
  sceneGroup:insert(cloud[3])
  sceneGroup:insert(scoreText)
  sceneGroup:insert(hsText)
  sceneGroup:insert(windText)
  sceneGroup:insert(barrelWings)
  sceneGroup:insert(barrel)

  changeWind()
end



function onEnterFrame (event)
  cloud[1].y = 75
  cloud[2].y = 250
  cloud[3].y =375
  for i = 1, 3, 1 do
    if (cloud[i].x < -cloud[i].width) then
      cloud[i].x = screenW + cloud[i].width
    elseif cloud[i].x > (screenW + cloud[i].width) then
      cloud[i].x = -cloud[i].width
    end
  end
  if(item ~= nil) then
    if item.y < (nextBarrel.y - 60 - item.height) then
      isBallAboveBarrel = true
      createCatcher()
    end
    if item.y > (nextBarrel.contentBounds.yMin) and isBallAboveBarrel == true then
      nextBarrel:toFront()
      isBallAboveBarrel = false
    end
  end
  if item ~= nil then
    if catcher ~= nil then
      if item.x > catcher.contentBounds.xMin and item.x < catcher.contentBounds.xMax and item.y > nextBarrel.y and item.y < catcher.contentBounds.yMax then
        nextBarrel:play()
        afterCatch()
      end
    end
  end
  if item ~= nil  then
    if item.y > screenH + item.height and isAlive then
      doDead()
      isAlive = (lives > 0 and true or false)
    end
  end
end

function scene:show (event)
  local phase = event.phase
  if phase =="did" then
    prevTime = system.getTimer()
    Runtime:addEventListener("enterFrame",onEnterFrame)
    Runtime:addEventListener("touch",onBackgroundTouch)
  end
end




scene:addEventListener("create",scene)
scene:addEventListener("show",scene)

return scene

--[[back and front
local group = display.newGroup()
group:insert(do2) -- do2 is on the bottom
group:insert(do1) -- do1 is on the top (front)

-- Move do2 to front by re-inserting it - only one instance will exist in group
group:insert(do2)

assert(group[1] == do1) -- do1 is on the bottom
assert(group[2] == do2) -- do2 is on the top (front)

-- Move do2 to the front

do2:toFront()

assert(group[1] == do1) -- do1 is on the bottom
assert(group[2] == do2) -- do2 is on the top (front)

-- Move do2 to the back

do2:toBack()

assert(group[1] == do2) -- do2 is on the bottom
assert(group[2] == do1) -- do1 is on the top (front)]]
