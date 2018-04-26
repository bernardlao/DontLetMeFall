display.setStatusBar( display.HiddenStatusBar )
local composer = require("composer")
local scene = composer.newScene()
display.setDefault( "background", 0,0,0 )
local screenW = display.contentWidth
local screenH = display.contentHeight
local halfW = display.contentWidth * 0.5
local halfH = display.contentHeight * 0.5
local group = display.newGroup()
local score = 0

local function doMessage(  )
	local options = {
		text = "GAME OVER",
		x = halfW,
		y =  -200,
		width = 800,
		font = native.systemBoldFont,
		fontSize = 100,
		align ="center"
	}
	local message = display.newText(options)
	message:setFillColor(1,0,0)
	options = {
		text = "Your score : "..score,
		x = halfW,
		y = message.y + 100,
		width = 800,
		font = native.systemBoldFont,
		fontSize = 50,
		align ="center"
	}
	local scoredText = display.newText(options)
	scoredText:setFillColor(1,0,0)
	group:insert(message)
	group:insert(scoredText)
	local function follow(  )
		transition.to(scoredText,{time=1000,y=message.y + 100})
	end
	transition.to(message,{time=1000,y=halfH - message.height,onComplete=follow})
end

local function goBack(  )
	audio.stop()
	group:removeSelf()
	group=nil
	composer.removeScene("scenes.maingame")
	composer.gotoScene("scenes.menu")
end
function scene:show( event )
    local sceneGroup = self.view
    score = event.params.scoredVal
    doMessage()
end

timer.performWithDelay(5000,goBack)
scene:addEventListener( "show" )
return scene