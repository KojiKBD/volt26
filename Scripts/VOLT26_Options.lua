-- VOLT26 CORE: Player and operator options policy.
-- Loaded after SL_Init.lua, which creates the VOLT26 namespace and state.

VOLT26.Options = {}

function VOLT26.Options.GetPlayerModifiers(player)
	return VOLT26.Core.GetPlayerState(player).ActiveModifiers
end

function VOLT26.Options.GetGlobalModifiers()
	return VOLT26.State.Global.ActiveModifiers
end

-- Perspective.
--
-- The engine does not keep a perspective by name: `mod,distant` and the rest
-- set two numbers on PlayerOptions, a vanishing-point skew and a tilt, and
-- those are all that can be read back.  These are the five combinations the
-- options screen offers, in the order it offers them.
local perspectives = {
	{Name = "Overhead", Skew = 0, Tilt =  0},
	{Name = "Hallway",  Skew = 0, Tilt = -1},
	{Name = "Distant",  Skew = 0, Tilt =  1},
	{Name = "Incoming", Skew = 1, Tilt = -1},
	{Name = "Space",    Skew = 1, Tilt =  1},
}

function VOLT26.Options.GetPerspectives()
	return perspectives
end

-- GetPerspective(player) -> name, tilt, skew
--
-- The two numbers come back alongside the name because anything drawing a note
-- field needs them rather than the name: the tilt is the angle the field is
-- rotated through and the skew is where the vanishing point sits.
function VOLT26.Options.GetPerspective(player)
	local options = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
	-- Each getter answers with the value and its rate of approach, so both are
	-- parenthesised down to the value alone.
	local ok, skew, tilt = pcall(function()
		return tonumber((options:Skew())) or 0, tonumber((options:Tilt())) or 0
	end)
	if not ok then return "Overhead", 0, 0 end
	for _, entry in ipairs(perspectives) do
		if math.abs(entry.Skew - skew) < 0.5 and math.abs(entry.Tilt - tilt) < 0.5 then
			return entry.Name, tilt, skew
		end
	end
	return "Overhead", tilt, skew
end

function VOLT26.Options.SetPerspective(player, name)
	GAMESTATE:ApplyGameCommand("mod," .. tostring(name):lower(),
		PlayerNumber:Reverse()[player] + 1)
end

function VOLT26.Options.CanReturnToMusic()
	return VOLT26.State.Global.MenuTimer.ScreenSelectMusic > 1
		and VOLT26.State.Global.MusicWheelLocked ~= true
end

function VOLT26.Options.GetMenuTimer()
	return VOLT26.State.Global.MenuTimer.ScreenPlayerOptions
end

function VOLT26.Options.GetNextScreen(page)
	return VOLT26.State.Global.ScreenAfter["PlayerOptions"..(page == 1 and "" or tostring(page))]
end

function VOLT26.Options.GetReturnChoices(page)
	local choices = {
		[1] = {"Gameplay", "Select Music", "Options2", "Options3"},
		[2] = {"Gameplay", "Select Music", "Options1", "Options3"},
		[3] = {"Gameplay", "Select Music", "Options1", "Options2"},
	}
	local result = DeepCopy(choices[page])
	if not VOLT26.Options.CanReturnToMusic() then table.remove(result, 2) end
	return result
end

function VOLT26.Options.SaveReturnChoice(page, selections)
	local destinations = {
		[1] = {Branch.GameplayScreen(), VOLT26.Navigation.SelectMusicOrCourse(), "ScreenPlayerOptions2", "ScreenPlayerOptions3"},
		[2] = {Branch.GameplayScreen(), VOLT26.Navigation.SelectMusicOrCourse(), "ScreenPlayerOptions", "ScreenPlayerOptions3"},
		[3] = {Branch.GameplayScreen(), VOLT26.Navigation.SelectMusicOrCourse(), "ScreenPlayerOptions", "ScreenPlayerOptions2"},
	}
	if not VOLT26.Options.CanReturnToMusic() then table.remove(destinations[page], 2) end
	for index, selected in ipairs(selections) do
		if selected then
			local key = "PlayerOptions"..(page == 1 and "" or tostring(page))
			VOLT26.State.Global.ScreenAfter[key] = destinations[page][index]
			return
		end
	end
end

function VOLT26.Options.GetOperatorRow(screenName)
	if type(screenName) ~= "string" then return 0 end
	local rows = VOLT26.State.Global.PrevScreenOptionsServiceRow
	return math.max(0, math.floor(tonumber(rows[screenName]) or 0))
end

function VOLT26.Options.RememberOperatorRow(screenName, rowIndex, rowCount)
	if type(screenName) ~= "string" then return 0 end
	local index = math.max(0, math.floor(tonumber(rowIndex) or 0))
	local count = math.max(0, math.floor(tonumber(rowCount) or 0))
	if count > 0 and index >= count - 1 then index = 0 end
	VOLT26.State.Global.PrevScreenOptionsServiceRow[screenName] = index
	return index
end

local OperatorMenuLines = {
	"SystemOptions", "MapControllers", "TestInput", "InputOptions",
	"GraphicsSoundOptions", "VisualOptions", "ArcadeOptions", "Bookkeeping",
	"AdvancedOptions", "MenuTimerOptions", "USBProfileOptions",
	"OptionsManageProfiles", "ThemeOptions", "GrooveStatsOptions", "TournamentModeOptions", "StepManiaCredits", "ClearCredits", "Reload",
}

local ThemeOptionLines = {
	"PerformanceMode", "MusicWheelSpeed", "PreferredStyle", "AllowFailingOutOfSet", "NumberOfContinuesAllowed",
	"SelectProfile", "SelectPlayMode2", "EvalSummary",
	"NameEntry", "GameOver", "HideStockNoteSksins", "DanceSolo", "WriteCustomScores",
	"KeyboardFeatures", "SampleMusicLoops", "SampleMusicStartsImmediately", "RescoreEarlyHits",
	"DefaultSort",
}

local MenuTimerLines = {
	"MenuTimer", "ScreenGrooveStatsLoginMenuTimer", "ScreenSelectMusicMenuTimer", "ScreenPlayerOptionsMenuTimer",
	"ScreenEvaluationMenuTimer", "ScreenEvaluationNonstopMenuTimer",
	"ScreenEvaluationSummaryMenuTimer", "ScreenNameEntryMenuTimer",
}

local function FilterOperatorLines(source, excluded)
	local result = {}
	for _, line in ipairs(source) do
		if not excluded[line] then result[#result + 1] = line end
	end
	return result
end

function VOLT26.Options.GetOperatorMenuLines(customSongsAvailable, coinMode)
	return FilterOperatorLines(OperatorMenuLines, {
		USBProfileOptions = not customSongsAvailable,
		ClearCredits = coinMode ~= "CoinMode_Pay",
	})
end

function VOLT26.Options.GetThemeOptionLines()
	return FilterOperatorLines(ThemeOptionLines, {})
end

function VOLT26.Options.GetMenuTimerLines()
	return FilterOperatorLines(MenuTimerLines, {})
end

function VOLT26.Options.GetOperatorMenuLineNames(customSongsAvailable, coinMode)
	return table.concat(VOLT26.Options.GetOperatorMenuLines(customSongsAvailable, coinMode), ",")
end

function VOLT26.Options.GetThemeOptionLineNames()
	return table.concat(VOLT26.Options.GetThemeOptionLines(), ",")
end

function VOLT26.Options.GetMenuTimerLineNames()
	return table.concat(VOLT26.Options.GetMenuTimerLines(), ",")
end
