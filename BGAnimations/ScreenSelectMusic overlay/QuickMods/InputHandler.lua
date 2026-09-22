local args = ...
local state = args.State
local rows = args.Rows

-- Input while the Quick Mods panel is open.
--
-- Each player drives their own half, and neither reaches the other's.
--
--   left / right   change the setting under the cursor
--   start, up/down move to another setting
--   back           return to the menu the panel was raised from
--
-- Start walks the list the way it walks an options screen, so a cabinet with
-- only three menu buttons can reach everything.  The last entry is not a
-- setting but the way out: left and right choose between closing and going back
-- to the top of the list, and Start does the one showing.

-- One past the settings: the entry that closes the panel.
local exitIndex = #rows + 1

local function available(index, player)
	if index == exitIndex then return true end
	local row = rows[index]
	if not row then return false end
	local definition = row.Definition
	return definition.Available == nil or definition.Available(player) ~= false
end

-- Settings a style cannot offer -- a note skin with no variants, an asset the
-- game does not ship -- are drawn greyed out so the list keeps its shape, and
-- stepped over rather than stopped on.
local function move(player, delta)
	local pn = ToEnumShortString(player)
	local index = state[pn].Index
	for _ = 1, exitIndex do
		index = (index - 1 + delta) % exitIndex + 1
		if available(index, player) then break end
	end
	state[pn].Index = index
end

-- What Start does on a setting: the next one down, without wrapping, because
-- running off the end is what puts the cursor on the way out.
local function advance(player)
	local pn = ToEnumShortString(player)
	for index = state[pn].Index + 1, exitIndex do
		if available(index, player) then
			state[pn].Index = index
			return
		end
	end
	state[pn].Index = exitIndex
end

local function change(player, delta)
	local pn = ToEnumShortString(player)
	local index = state[pn].Index
	if index == exitIndex then
		state[pn].ExitChoice = (state[pn].ExitChoice == "Top") and "Close" or "Top"
		return true
	end
	if not available(index, player) then return false end
	rows[index].Definition.Change(player, delta)
	return true
end

local function sound(overlay, name)
	local sortmenu = overlay and overlay:GetChild("SortMenu")
	local actor = sortmenu and sortmenu:GetChild(name)
	if actor then actor:play() end
end

local input = function(event)
	if not (event and event.PlayerNumber and event.button) then return false end
	if event.type == "InputEventType_Release" then return false end

	local player = event.PlayerNumber
	if not GAMESTATE:IsHumanPlayer(player) then return false end
	local pn = ToEnumShortString(player)

	local screen = SCREENMAN:GetTopScreen()
	local overlay = screen and screen:GetChild("Overlay")
	if not overlay then return false end
	local sortmenu = overlay:GetChild("SortMenu")

	-- Start and Back act once per press.  The Start that opened this panel is
	-- often still held, and its repeats would walk straight through the list.
	local firstPress = event.type == "InputEventType_FirstPress"
	local button = event.GameButton
	local acted = false

	if button == "MenuUp" or button == "MenuDown" then
		move(player, button == "MenuUp" and -1 or 1)
		sound(overlay, "change_sound")
		acted = true

	elseif button == "MenuLeft" or button == "MenuRight" then
		if change(player, button == "MenuLeft" and -1 or 1) then
			sound(overlay, "change_sound")
			acted = true
		end

	elseif button == "Start" and firstPress then
		if state[pn].Index == exitIndex then
			sound(overlay, "start_sound")
			if state[pn].ExitChoice == "Top" then
				state[pn].Index = 1
				acted = true
			else
				overlay:queuecommand("DirectInputToEngine")
			end
		else
			advance(player)
			sound(overlay, "change_sound")
			acted = true
		end

	elseif (button == "Back" or button == "Select") and firstPress then
		if sortmenu then
			sortmenu:queuecommand("DirectInputToSortMenu")
		else
			overlay:queuecommand("DirectInputToEngine")
		end
	end

	-- One message for every press that did something: it repaints the list and
	-- brings it back to full strength.
	if acted then MESSAGEMAN:Broadcast("VOLT26QuickModsChanged") end
	return false
end

return input
