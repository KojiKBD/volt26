-- VOLT26 CORE: Evaluation contexts and evaluation input.
-- Loaded after SL_Init.lua, which creates the VOLT26 namespace and state.

VOLT26.Evaluation = {}

function VOLT26.Evaluation.GetStageCount()
	return math.max(0, tonumber(VOLT26.State.Global.Stages.PlayedThisGame) or 0)
end

function VOLT26.Evaluation.GetStageContext(stageIndex)
	local context = VOLT26.State.Global.Stages.Stats[stageIndex]
	return type(context) == "table" and DeepCopy(context) or nil
end

function VOLT26.Evaluation.GetPlayerStageSnapshot(player, stageIndex)
	local state = VOLT26.Core.GetPlayerState(player)
	local stage = state and state.Stages.Stats[stageIndex] or nil
	if type(stage) ~= "table" then return nil end
	return DeepCopy(stage.result_snapshot or stage)
end

function VOLT26.Evaluation.GetProfilesUsed(player)
	local profiles, seen = {}, {}
	for stageIndex=1,VOLT26.Evaluation.GetStageCount() do
		local snapshot = VOLT26.Evaluation.GetPlayerStageSnapshot(player, stageIndex)
		local profile = snapshot and snapshot.profile or nil
		if profile and not seen[profile] then
			profiles[#profiles + 1] = profile
			seen[profile] = true
		end
	end
	return profiles
end

function VOLT26.Evaluation.BuildPlayerSnapshot(player)
	local pn = ToEnumShortString(player)
	local modifiers = VOLT26.Options.GetPlayerModifiers(player)
	local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
	local result = VOLT26.Results.GetCurrent(player)
	local judgments = DeepCopy(result.judgments)
	local showEx = (modifiers.ShowFaPlusWindow and modifiers.ShowFaPlusPane) or modifiers.ShowExScore
	if showEx then
		judgments.W0 = result.exJudgments.W0 or 0
		judgments.W1 = result.exJudgments.W1 or 0
	end

	local steps, difficulty, meter, stepartist
	if GAMESTATE:IsCourseMode() then
		steps = GAMESTATE:GetCurrentTrail(player)
		if steps then
			difficulty = steps:GetDifficulty()
			meter = steps:GetMeter()
		end
		local course = GAMESTATE:GetCurrentCourse(player)
		stepartist = course and course:GetScripter() or nil
	else
		steps = GAMESTATE:GetCurrentSteps(player)
		local playedSteps = pss:GetPlayedSteps()[1] or steps
		if playedSteps then
			difficulty = playedSteps:GetDifficulty()
			meter = playedSteps:GetMeter()
			stepartist = playedSteps:GetAuthorCredit()
		end
	end

	return {
		schema_version=1,
		profile=PROFILEMAN:IsPersistentProfile(pn)
			and PROFILEMAN:GetProfile(player):GetDisplayName() or "[GUEST]",
		grade=result.grade,
		score=result.percentDP,
		exscore=result.exPercent,
		judgments=judgments,
		showex=modifiers.ShowExScore == true,
		steps=steps,
		difficulty=difficulty,
		meter=meter,
		stepartist=stepartist,
		timingwindows=DeepCopy(modifiers.TimingWindows),
	}
end

function VOLT26.Evaluation.StorePlayerSnapshot(player)
	local stage = VOLT26.Gameplay.GetPlayerStageState(player)
	if not stage then return nil end
	local snapshot = VOLT26.Evaluation.BuildPlayerSnapshot(player)
	stage.result_snapshot = DeepCopy(snapshot)
	-- Compatibility aliases for inherited actors that are outside EVAL-01.
	for key, value in pairs(snapshot) do
		-- DeepCopy walks its argument with pairs(), so only tables go through it.
		stage[key] = type(value) == "table" and DeepCopy(value) or value
	end
	return DeepCopy(snapshot)
end

function VOLT26.Evaluation.AllPlayersFailed()
	local players = GAMESTATE:GetHumanPlayers()
	if #players == 0 then return false end
	for player in ivalues(players) do
		if not STATSMAN:GetCurStageStats():GetPlayerStageStats(player):GetFailed() then
			return false
		end
	end
	return true
end

function VOLT26.Evaluation.StoreStageContext()
	local stageIndex = VOLT26.Gameplay.GetActiveStageIndex()
	local existing = VOLT26.State.Global.Stages.Stats[stageIndex] or {}
	local item = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or GAMESTATE:GetCurrentSong()
	local musicRate = VOLT26.MusicSelection.GetMusicRate()
	VOLT26.State.Global.Stages.Stats[stageIndex] = {
		schema_version=1,
		item=item,
		music_rate=musicRate,
		completed=existing.completed == true,
		-- Compatibility aliases for inherited actors that are outside EVAL-01.
		song=item,
		MusicRate=musicRate,
	}
	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		VOLT26.Session.MarkStageCompleted(player, GetTimeSinceStart())
	end
	return VOLT26.Evaluation.GetStageContext(stageIndex)
end

function VOLT26.Evaluation.CompleteStage()
	local stageIndex = VOLT26.Gameplay.GetActiveStageIndex()
	local context = VOLT26.State.Global.Stages.Stats[stageIndex]
	if type(context) ~= "table" or context.completed == true then return false end
	context.completed = true
	VOLT26.State.Global.Stages.PlayedThisGame = math.max(
		VOLT26.Evaluation.GetStageCount(), stageIndex
	)
	return true
end

VOLT26.EvaluationInput = {}

function VOLT26.EvaluationInput.GetPanePreferences(player)
	local state = VOLT26.Core.GetPlayerState(player)
	return state.EvalPanePrimary or 1, state.EvalPaneSecondary or 1
end

function VOLT26.EvaluationInput.FindPaneIndex(availablePaneNumbers, preferredPane)
	for index, paneNumber in ipairs(availablePaneNumbers or {}) do
		if paneNumber == preferredPane then return index end
	end
	return #availablePaneNumbers > 0 and 1 or nil
end

function VOLT26.EvaluationInput.NewCallbackController()
	local active = {}
	local controller = {}

	function controller:Activate(name, callback)
		if not callback or active[name] == callback then return end
		if active[name] then SCREENMAN:GetTopScreen():RemoveInputCallback(active[name]) end
		active[name] = callback
		SCREENMAN:GetTopScreen():AddInputCallback(callback)
	end

	function controller:Deactivate(name)
		if not active[name] then return end
		SCREENMAN:GetTopScreen():RemoveInputCallback(active[name])
		active[name] = nil
	end

	function controller:Clear()
		local names = {}
		for name in pairs(active) do names[#names + 1] = name end
		for _, name in ipairs(names) do self:Deactivate(name) end
	end

	return controller
end

function VOLT26.EvaluationInput.CanUseReplayPracticeShortcuts()
	return ThemePrefs.Get("KeyboardFeatures")
		and PREFSMAN:GetPreference("EventMode")
		and not GAMESTATE:IsCourseMode()
end

function VOLT26.EvaluationInput.CreateReplayPracticeHandler()
	local controlHeld = false
	return function(event)
		if not event or not event.DeviceInput then return false end
		local button = event.DeviceInput.button
		local isControl = button == "DeviceButton_left ctrl" or button == "DeviceButton_right ctrl"
		if isControl then
			if event.type == "InputEventType_FirstPress" then controlHeld = true end
			if event.type == "InputEventType_Release" then controlHeld = false end
			return false
		end
		if event.type ~= "InputEventType_FirstPress" or not controlHeld then return false end

		local destination, message
		if button == "DeviceButton_r" then
			destination, message = Branch.GameplayScreen(), "Replaying Song"
		elseif button == "DeviceButton_p" then
			destination, message = "ScreenPractice", "Entering Practice Mode"
		end
		if destination then
			-- The evaluated stage remains complete; replay/practice starts a new route.
			VOLT26.Util.SystemMessage(message)
			SCREENMAN:GetTopScreen():SetNextScreenName(destination):StartTransitioningScreen("SM_GoToNextScreen")
		end
		return false
	end
end

function VOLT26.EvaluationInput.CreateScreenshotHandler(requestCapture)
	local held = {MenuLeft=false, MenuRight=false}
	local chordCaptured = false
	local selectHeld = false
	return function(event)
		if not event or not event.PlayerNumber then return false end
		if PREFSMAN:GetPreference("ThreeKeyNavigation") then
			if held[event.GameButton] == nil then return false end
			held[event.GameButton] = event.type ~= "InputEventType_Release"
			if held.MenuLeft and held.MenuRight and not chordCaptured then
				chordCaptured = true
				requestCapture(event.PlayerNumber)
			elseif not held.MenuLeft or not held.MenuRight then
				chordCaptured = false
			end
		elseif event.GameButton == "Select" then
			if event.type == "InputEventType_Release" then
				selectHeld = false
			elseif event.type == "InputEventType_FirstPress" and not selectHeld then
				selectHeld = true
				requestCapture(event.PlayerNumber)
			end
		end
		return false
	end
end

function VOLT26.EvaluationInput.BuildScreenshotPrefix(title)
	local month = ("%02d-%s"):format(
		MonthOfYear() + 1,
		THEME:GetString("Months", "Month"..MonthOfYear() + 1)
	)
	local safeTitle = (title or "Evaluation"):utf8sub(1, 10):gsub("%W", "_")
	return "VOLT26/" .. Year() .. "/" .. month .. "/" .. safeTitle .. "_"
end

function VOLT26.EvaluationInput.CaptureScreenshot(player)
	local item = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or GAMESTATE:GetCurrentSong()
	local title = item and item:GetDisplayFullTitle() or "Evaluation"
	local prefix = VOLT26.EvaluationInput.BuildScreenshotPrefix(title)
	local ok, success, path = pcall(SaveScreenshot, player, false, false, prefix)
	if not ok then
		Trace("VOLT26 screenshot error: "..tostring(success))
		return false, tostring(success)
	end
	Trace(("VOLT26 screenshot %s: %s"):format(success and "saved" or "failed", tostring(path)))
	return success == true, path
end

function VOLT26.EvaluationInput.SetScreenshotTexture(texture)
	VOLT26.Core.GetGlobalState().ScreenshotTexture = texture
end

function VOLT26.EvaluationInput.GetScreenshotTexture()
	return VOLT26.Core.GetGlobalState().ScreenshotTexture
end
