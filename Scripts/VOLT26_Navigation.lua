local Navigation = VOLT26.Navigation

function Navigation.HasCreditsToContinue()
	if PREFSMAN:GetPreference("CoinMode") ~= "CoinMode_Pay" then return true end
	local credits = GetCredits().Credits
	local premium = ToEnumShortString(GAMESTATE:GetPremium())
	local style = ToEnumShortString(GAMESTATE:GetCurrentStyle():GetStyleType())
	if premium == "2PlayersFor1Credit" then return credits > 0 end
	if premium == "DoubleFor1Credit" then
		return credits > ((style == "TwoPlayersTwoSides" or style == "TwoPlayersSharedSides") and 1 or 0)
	end
	if premium == "Off" then return credits > (style == "OnePlayerOneSide" and 0 or 1) end
	return false
end

function Navigation.SelectMusicOrCourse()
	if GAMESTATE:IsCourseMode() then return "ScreenSelectCourse" end
	return "ScreenSelectMusic"
end

function Navigation.AfterScreenRankingDouble()
	if Navigation.ShouldShowPaidPlayDemonstration() then return "ScreenDemonstration" end
	return PREFSMAN:GetPreference("MemoryCards") and "ScreenMemoryCard" or "ScreenRainbow"
end

function Navigation.IsPaidPlayWithoutCredits()
	if GAMESTATE:GetCoinMode() ~= "CoinMode_Pay" then return false end
	local credits = GetCredits()
	return credits and (tonumber(credits.Credits) or 0) <= 0
end

function Navigation.ShouldShowPaidPlayDemonstration()
	return Navigation.IsPaidPlayWithoutCredits() and SONGMAN:GetNumSongs() > 0
end

function Navigation.AfterScreenDemonstration()
	return PREFSMAN:GetPreference("MemoryCards") and "ScreenMemoryCard" or "ScreenRainbow"
end

function Navigation.AllowScreenSelectProfile()
	return VOLT26.ThemePrefs.Get("AllowScreenSelectProfile")
		and "ScreenSelectProfile" or Navigation.AfterSelectProfile()
end

function Navigation.AfterSelectProfile()
	return Navigation.AllowScreenSelectColor()
end

function Navigation.AllowScreenSelectColor()
	if VOLT26.ThemePrefs.Get("AllowScreenSelectColor") and not VOLT26.ThemePrefs.Get("RainbowMode") then
		return "ScreenSelectColor"
	end
	return Navigation.AfterScreenSelectColor()
end

function Navigation.AfterScreenSelectColor()
	if THEME:GetMetric("Common", "AutoSetStyle") then
		local styles = {"single", "versus"}
		GAMESTATE:SetCurrentStyle(styles[math.max(GAMESTATE:GetNumSidesJoined(), 1)])
		return Navigation.AllowScreenSelectPlayMode()
	end

	local preferredStyle = VOLT26.ThemePrefs.Get("PreferredStyle")
	if preferredStyle ~= "none" and preferredStyle ~= "auto"
		and GAMESTATE:GetCoinMode() ~= "CoinMode_Pay" then
		if preferredStyle == "versus" then
			GAMESTATE:JoinPlayer(PLAYER_1)
			GAMESTATE:JoinPlayer(PLAYER_2)
		elseif preferredStyle == "single" and GAMESTATE:GetNumSidesJoined() == 2 then
			GAMESTATE:UnjoinPlayer(PLAYER_2)
		end
		GAMESTATE:SetCurrentStyle(preferredStyle)
		return Navigation.AllowScreenSelectPlayMode()
	end
	return "ScreenSelectStyle"
end

function Navigation.AllowScreenSelectPlayMode()
	VOLT26.State.Global.GameMode = "ITG"
	return Navigation.AllowScreenSelectPlayMode2()
end

function Navigation.AllowScreenSelectPlayMode2()
	VOLT26.ThemePrefs.ApplyGameMode()
	THEME:ReloadMetrics()
	if VOLT26.Gameplay.GetMode() == "ITG" and VOLT26.ThemePrefs.Get("AllowScreenSelectPlayMode2") then
		return "ScreenSelectPlayMode2"
	end
	return "ScreenProfileLoad"
end

function Navigation.AfterEvaluationStage()
	return "ScreenProfileSave"
end

function Navigation.AfterSelectPlayMode()
	return Navigation.SelectMusicOrCourse()
end

function Navigation.AfterGameplay()
	if THEME:GetMetric("ScreenHeartEntry", "HeartEntryEnabled") then
		for _, player in ipairs(GAMESTATE:GetEnabledPlayers()) do
			local profile = PROFILEMAN:GetProfile(player)
			if profile and profile:GetIgnoreStepCountCalories() then return "ScreenHeartEntry" end
		end
	end
	return Navigation.AfterHeartEntry()
end

function Navigation.AfterHeartEntry()
	local playMode = ToEnumShortString(GAMESTATE:GetPlayMode())
	if playMode == "Regular" then return "ScreenEvaluationStage" end
	if playMode == "Nonstop" then return "ScreenEvaluationNonstop" end
end

function Navigation.AfterSelectMusic()
	MESSAGEMAN:Broadcast("SongSelected")
	if SCREENMAN:GetTopScreen():GetGoToOptions() then return "ScreenPlayerOptions" end
	local style = GAMESTATE:GetCurrentStyle()
	if style and style:GetName() == "routine" then return "ScreenGameplayShared" end
	return Branch.GameplayScreen()
end

function Navigation.CancelMusicSelection()
	if GAMESTATE:GetCurrentStageIndex() > 0 then return Navigation.AllowScreenEvalSummary() end
	return Branch.TitleMenu()
end

function Navigation.AllowScreenNameEntry()
	return VOLT26.ThemePrefs.Get("AllowScreenNameEntry")
		and "ScreenNameEntryTraditional" or "ScreenProfileSaveSummary"
end

function Navigation.AllowScreenEvalSummary()
	return VOLT26.ThemePrefs.Get("AllowScreenEvalSummary")
		and "ScreenEvaluationSummary" or Navigation.AllowScreenNameEntry()
end

function Navigation.ReconcileStageCost()
	local state = VOLT26.Core.GetGlobalState()
	local song = GAMESTATE:GetCurrentSong()
	if not song then return end
	local engineCost = song:IsMarathon() and 3 or (song:IsLong() and 2 or 1)
	state.Stages.Remaining = state.Stages.Remaining - engineCost

	local rate = VOLT26.MusicSelection.GetMusicRate()
	if rate ~= 1 then
		local duration = song:GetLastSecond() / rate
		local actualCost = duration > PREFSMAN:GetPreference("MarathonVerSongSeconds") and 3
			or (duration > PREFSMAN:GetPreference("LongVerSongSeconds") and 2 or 1)
		state.Stages.Remaining = state.Stages.Remaining + engineCost - actualCost
	end

	local master = GAMESTATE:GetMasterPlayerNumber()
	local engineRemaining = GAMESTATE:GetNumStagesLeft(master)
	if engineRemaining < state.Stages.Remaining then
		for player in ivalues(GAMESTATE:GetHumanPlayers()) do
			for _=1,state.Stages.Remaining-engineRemaining do GAMESTATE:AddStageToPlayer(player) end
		end
	end
end

function Navigation.AfterProfileSave()
	if PREFSMAN:GetPreference("EventMode") then return Navigation.SelectMusicOrCourse() end
	if GAMESTATE:IsCourseMode() then return Navigation.AllowScreenNameEntry() end

	Navigation.ReconcileStageCost()
	local state = VOLT26.Core.GetGlobalState()
	local setOver = state.Stages.Remaining <= 0
	if VOLT26.ThemePrefs.Get("AllowFailingOutOfSet") then
		setOver = setOver or STATSMAN:GetCurStageStats():AllFailed()
	end
	if not setOver then return Navigation.SelectMusicOrCourse() end
	if PREFSMAN:GetPreference("CoinMode") ~= "CoinMode_Home"
		and state.ContinuesRemaining > 0 and Navigation.HasCreditsToContinue() then
		return "ScreenPlayAgain"
	end
	return Navigation.AllowScreenEvalSummary()
end

function Navigation.AfterProfileSaveSummary()
	return VOLT26.ThemePrefs.Get("AllowScreenGameOver") and "ScreenGameOver" or Branch.AfterInit()
end

-- Engine metrics still resolve the fallback Branch table. Keep these as thin adapters.
Branch.AfterScreenRankingDouble = Navigation.AfterScreenRankingDouble
Branch.AfterScreenDemonstration = Navigation.AfterScreenDemonstration
Branch.AllowScreenSelectProfile = Navigation.AllowScreenSelectProfile
Branch.AfterSelectProfile = Navigation.AfterSelectProfile
Branch.AllowScreenSelectColor = Navigation.AllowScreenSelectColor
Branch.AfterScreenSelectColor = Navigation.AfterScreenSelectColor
Branch.AllowScreenSelectPlayMode = Navigation.AllowScreenSelectPlayMode
Branch.AllowScreenSelectPlayMode2 = Navigation.AllowScreenSelectPlayMode2
Branch.AfterEvaluationStage = Navigation.AfterEvaluationStage
Branch.AfterSelectPlayMode = Navigation.AfterSelectPlayMode
Branch.AfterGameplay = Navigation.AfterGameplay
Branch.AfterHeartEntry = Navigation.AfterHeartEntry
Branch.AfterSelectMusic = Navigation.AfterSelectMusic
Branch.SSMCancel = Navigation.CancelMusicSelection
Branch.AllowScreenNameEntry = Navigation.AllowScreenNameEntry
Branch.AllowScreenEvalSummary = Navigation.AllowScreenEvalSummary
Branch.AfterProfileSave = Navigation.AfterProfileSave
Branch.AfterProfileSaveSummary = Navigation.AfterProfileSaveSummary

SelectMusicOrCourse = Navigation.SelectMusicOrCourse
