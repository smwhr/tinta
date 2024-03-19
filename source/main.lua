import "CoreLibs/graphics"
dump = import('libs/dump')
local gfx <const> = playdate.graphics
local storyDefinition = import "tests/testjson"
Story = import "engine/story"
local story = Story(storyDefinition)
local choices
local selectedChoiceIndex = 1

local function loadGame()
	playdate.display.setRefreshRate(50) -- Sets framerate to 50 fps
	gfx.setFont(font)

	-- ink initialization

	story:Continue()
	choices = story:currentChoices()
end

local function updateGame()
	if playdate.buttonJustPressed(playdate.kButtonUp) and #choices > 0 then
		selectedChoiceIndex = selectedChoiceIndex - 1;
		if selectedChoiceIndex <= 0 then selectedChoiceIndex = 1 end
	end
	if playdate.buttonJustPressed(playdate.kButtonDown) and #choices > 0 then
		selectedChoiceIndex = selectedChoiceIndex + 1;
		if selectedChoiceIndex > #choices then selectedChoiceIndex = #choices end
	end
	if playdate.buttonJustPressed(playdate.kButtonA) then
		if #choices > 0 then
			local choice = selectedChoiceIndex
			print("Choosing " .. choice)
			story:ChooseChoiceIndex(choice)
		end
		if story:canContinue() then
			story:Continue()
			choices = story:currentChoices()
			selectedChoiceIndex = 1
		end
	end
	if playdate.buttonJustPressed(playdate.kButtonB) then
		if story:currentFlowIsDefaultFlow() then
			story:SwitchFlow("goont")
			--story:ChoosePathString("murder_scene",false)
		    if story:canContinue() then
				story:Continue()
				choices = story:currentChoices()
				selectedChoiceIndex = 1
			end
		else
			story:RemoveFlow("goont")
		end
		choices = story:currentChoices()
		selectedChoiceIndex = 1
	end

	if playdate.buttonJustPressed(playdate.kButtonLeft) then
		playdate.datastore.write(story.state:save())
		choices = story:currentChoices()
	end

	if playdate.buttonJustPressed(playdate.kButtonRight) then
		local saveData = playdate.datastore.read()
		story.state:load(saveData)
		choices = story:currentChoices()
	end
end

local function drawGame()
	gfx.clear() -- Clears the screen
	-- Output text to the player
	local height = 30
	gfx.drawText(story:currentText(), 10, height)
	height += 15

	if #choices > 0 then
		for i, a in ipairs(choices) do
			if i == selectedChoiceIndex then
				gfx.drawCircleAtPoint(5, height + 8, 2)
			end
			gfx.drawText("[" .. i .. "] " .. a.text, 10, height)
			height += 15
		end
	end
end

loadGame()

function playdate.update()
	updateGame()
	drawGame()
	playdate.drawFPS(0, 0) -- FPS widget
end
