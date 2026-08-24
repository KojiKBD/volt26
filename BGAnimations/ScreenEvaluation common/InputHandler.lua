local af, numPanes = unpack(...)
if not af or type(numPanes) ~= "number" then return end

local style = ToEnumShortString(GAMESTATE:GetCurrentStyle():GetStyleType())
local players = GAMESTATE:GetHumanPlayers()
local masterPlayer = GAMESTATE:GetMasterPlayerNumber()
local masterController = PlayerNumber:Reverse()[masterPlayer] + 1
local panes, paneNumbers, activePane = {}, {}, {}

for controller=1,2 do
	panes[controller], paneNumbers[controller] = {}, {}
	for paneNumber=1,numPanes do
		local pane = af:GetChild("Panes"):GetChild(("Pane%i_SideP%i"):format(paneNumber, controller))
		if pane then
			panes[controller][#panes[controller] + 1] = pane
			paneNumbers[controller][#paneNumbers[controller] + 1] = paneNumber
			pane:visible(false)
		end
	end
end

local primaryPreference, secondaryPreference = VOLT26.EvaluationInput.GetPanePreferences(masterPlayer)
for controller=1,2 do
	local preferred
	if #players == 1 then
		preferred = controller == masterController and primaryPreference or secondaryPreference
	else
		preferred = select(1, VOLT26.EvaluationInput.GetPanePreferences("P"..controller))
	end
	activePane[controller] = VOLT26.EvaluationInput.FindPaneIndex(paneNumbers[controller], preferred)
end

local function isFullWidth(controller, index)
	local pane = index and panes[controller][index]
	local content = pane and pane:GetChild("")
	return content and content:GetCommand("ExpandForDouble") ~= nil
end

local function hideAll()
	for controller=1,2 do
		for _, pane in ipairs(panes[controller]) do pane:visible(false) end
	end
end

local function chooseCompactPane(controller, excludedPaneNumber)
	for index, paneNumber in ipairs(paneNumbers[controller]) do
		if paneNumber ~= excludedPaneNumber and not isFullWidth(controller, index) then
			activePane[controller] = index
			return
		end
	end
end

local function showBoth()
	hideAll()
	for controller=1,2 do
		if activePane[controller] then panes[controller][activePane[controller]]:visible(true) end
	end
end

local isDoubleLayout = style == "OnePlayerTwoSides" or style == "TwoPlayersSharedSides"
if isDoubleLayout and isFullWidth(masterController, activePane[masterController]) then
	hideAll()
	panes[masterController][activePane[masterController]]:visible(true)
elseif isDoubleLayout then
	local otherController = masterController % 2 + 1
	if isFullWidth(otherController, activePane[otherController]) then
		chooseCompactPane(otherController, paneNumbers[masterController][activePane[masterController]])
	end
	showBoth()
else
	showBoth()
end

local function cyclePane(controller, direction)
	local count = #panes[controller]
	if count == 0 then return end
	local other = controller % 2 + 1
	repeat
		activePane[controller] = ((activePane[controller] - 1 + direction) % count) + 1
	until #players > 1 or count == 1
		or paneNumbers[controller][activePane[controller]] ~= paneNumbers[other][activePane[other]]
end

return function(event)
	if not (event and event.PlayerNumber and event.controller) then return false end
	if event.type ~= "InputEventType_FirstPress" then return false end
	if event.GameButton ~= "MenuRight" and event.GameButton ~= "MenuLeft" then return false end

	local controller = tonumber(ToEnumShortString(event.controller))
	if not controller or not activePane[controller] then return false end
	local other = controller % 2 + 1
	cyclePane(controller, event.GameButton == "MenuRight" and 1 or -1)

	if isDoubleLayout then
		if isFullWidth(controller, activePane[controller]) then
			hideAll()
			panes[controller][activePane[controller]]:visible(true)
		else
			if isFullWidth(other, activePane[other]) then
				chooseCompactPane(other, paneNumbers[controller][activePane[controller]])
			end
			showBoth()
		end
	else
		showBoth()
	end

	af:queuecommand("PaneSwitch")
	return false
end
