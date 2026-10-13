-- Page input for an evaluation screen that draws its own first page (the
-- stage evaluation's WANTED page, ScreenEvaluationStage overlay/Wanted/).
--
-- Each side of the screen (P1 left, P2 right) shows one of the screen's own
-- pages (VOLT26.EvaluationPage.Pages), counted from 0.  MenuLeft / MenuRight
-- turn a side's page, wrapping around.  With two players each controller
-- turns its own side; with one player the page is always on the left side
-- and either controller turns it.  The inherited Simply Love panes stay
-- loaded (GrooveStats submission writes into them) but are never shown.
--
-- Every change is broadcast as VOLT26EvaluationPage {Side=PlayerNumber,
-- Page=number, Count=number}; the screen hides or shows its own actors from it.
-- Returns the input callback (the caller activates it).
local af, numPanes = unpack(...)
if not af or type(numPanes) ~= "number" then return end

local players = GAMESTATE:GetHumanPlayers()
local sides = {}
if #players == 1 then
	sides[1] = PLAYER_1
else
	for _, player in ipairs(players) do sides[#sides+1] = player end
end

local page = { [PLAYER_1] = 0, [PLAYER_2] = 0 }
local count = VOLT26.EvaluationPage.PageCount()
local paneFrames = af:GetChild("Panes")
if paneFrames then paneFrames:visible(false) end

local function used(side)
	for _, s in ipairs(sides) do if s == side then return true end end
	return false
end

local function show(side)
	MESSAGEMAN:Broadcast("VOLT26EvaluationPage", { Side = side, Page = page[side], Count = count })
end

-- Start every used side on the screen's own page.
for _, side in ipairs(sides) do show(side) end

return function(event)
	if not (event and event.PlayerNumber and event.controller) then return false end
	if event.type ~= "InputEventType_FirstPress" then return false end
	if event.GameButton ~= "MenuRight" and event.GameButton ~= "MenuLeft" then return false end

	local side
	if #players > 1 then
		side = ("PlayerNumber_P%s"):format(ToEnumShortString(event.controller):match("%d") or "1")
	else
		side = PLAYER_1
	end
	if not used(side) then return false end

	local direction = event.GameButton == "MenuRight" and 1 or -1
	page[side] = (page[side] + direction) % count
	show(side)
	af:queuecommand("PaneSwitch")
	return false
end
