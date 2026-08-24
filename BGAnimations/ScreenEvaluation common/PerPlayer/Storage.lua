local player = ...
local pn = ToEnumShortString(player)
local playerState = VOLT26.Core.GetPlayerState(player)
local mods = playerState.ActiveModifiers

return Def.Actor{
	OnCommand=function(self)
		-- this SL[pn].Stages.Stats subtable was initialized in ./BGAnimations/ScreenGameplay overlay/default.lua
		-- One new table like this gets appended to SL[pn].Stages.Stats, indexed by stage number, to store
		-- lots of information (like below) so that it can persist between screens.
		--
		-- Here, we are storing things like letter grade, percent score, judgment counts, stepchart difficulty, etc.
		-- so that we can more easily display it on ScreenEvaluationSummary when this game cycle ends.
		local storage = VOLT26.Gameplay.GetPlayerStageState(player)

		-- a PlayerStageStats object from the engine
		-- see: http://quietly-turning.github.io/Lua-For-SM5/LuaAPI#Actors-PlayerStageStats
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
		local result = VOLT26.Results.GetCurrent(player)

		if PROFILEMAN:IsPersistentProfile(pn) then
			storage.profile = PROFILEMAN:GetProfile(player):GetDisplayName()
		else
			storage.profile = '[GUEST]'
		end

		storage.grade = result.grade
		storage.score = result.percentDP
		storage.exscore = result.exPercent
		storage.judgments = DeepCopy(result.judgments)
		
		if (mods.ShowFaPlusWindow and mods.ShowFaPlusPane) or mods.ShowExScore then
			storage.judgments.W0 = result.exJudgments.W0 or 0
			storage.judgments.W1 = result.exJudgments.W1 or 0
			storage.showex = mods.ShowExScore
		else
			storage.showex = false
		end

		if GAMESTATE:IsCourseMode() then
			storage.steps      = GAMESTATE:GetCurrentTrail(player)
			storage.difficulty = storage.steps:GetDifficulty()
			storage.meter      = storage.steps:GetMeter()
			storage.stepartist = GAMESTATE:GetCurrentCourse(player):GetScripter()
		else
			storage.steps      = GAMESTATE:GetCurrentSteps(player)
			storage.difficulty = pss:GetPlayedSteps()[1]:GetDifficulty()
			storage.meter      = pss:GetPlayedSteps()[1]:GetMeter()
			storage.stepartist = pss:GetPlayedSteps()[1]:GetAuthorCredit()
		end

		storage.timingwindows = playerState.ActiveModifiers.TimingWindows
	end
}
