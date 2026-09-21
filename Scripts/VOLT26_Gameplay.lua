-- VOLT26 CORE: Gameplay mode, gameplay statistics, target score, course speed, and versus state.
-- Loaded after SL_Init.lua, which creates the VOLT26 namespace and state.

VOLT26.Gameplay = {}

function VOLT26.Gameplay.GetMode()
	return VOLT26.State.Global.GameMode
end

function VOLT26.Gameplay.GetCurrentStageIndex()
	return VOLT26.State.Global.Stages.PlayedThisGame + 1
end

function VOLT26.Gameplay.GetActiveStageIndex()
	return VOLT26.State.Global.Stages.ActiveIndex or VOLT26.Gameplay.GetCurrentStageIndex()
end

function VOLT26.Gameplay.GetPlayerStageState(player)
	local state = VOLT26.Core.GetPlayerState(player)
	return state.Stages.Stats[VOLT26.Gameplay.GetActiveStageIndex()]
end

function VOLT26.Gameplay.BeginPlayerStage(player)
	local state = VOLT26.Core.GetPlayerState(player)
	local stageIndex = VOLT26.Gameplay.GetCurrentStageIndex()
	VOLT26.State.Global.Stages.ActiveIndex = stageIndex
	state.Stages.Stats[stageIndex] = {}
	return VOLT26.Gameplay.GetPlayerStageState(player)
end

function VOLT26.Gameplay.StorePlayerOptions(player)
	VOLT26.Core.GetPlayerState(player).PlayerOptionsString =
		GAMESTATE:GetPlayerState(player):GetPlayerOptionsString("ModsLevel_Preferred")
end

function VOLT26.Gameplay.IsReload()
	return VOLT26.State.Global.GameplayReloadCheck == true
end

function VOLT26.Gameplay.MarkIntroComplete()
	VOLT26.State.Global.GameplayReloadCheck = true
end

function VOLT26.Gameplay.LeaveScreen()
	VOLT26.State.Global.GameplayReloadCheck = false
end

VOLT26.GameplayStats = {}

function VOLT26.GameplayStats.SetPeakNPS(player, value)
	local key = ToEnumShortString(player)
	local peak = math.max(0, tonumber(value) or 0)
	VOLT26.State.Global.GameplayStats.PeakNPS[key] = peak
	return peak
end

function VOLT26.GameplayStats.GetPeakNPS(player)
	return VOLT26.State.Global.GameplayStats.PeakNPS[ToEnumShortString(player)]
end

function VOLT26.GameplayStats.GetPeakScale(player, otherPlayer)
	local mine = VOLT26.GameplayStats.GetPeakNPS(player) or 0
	local theirs = VOLT26.GameplayStats.GetPeakNPS(otherPlayer) or 0
	if mine <= 0 or theirs <= 0 or mine >= theirs then return 1 end
	return mine / theirs
end

function VOLT26.GameplayStats.GetDigitCount(value, minimum)
	value = math.floor(math.max(0, tonumber(value) or 0))
	local digits = value > 0 and math.floor(math.log10(value)) + 1 or 1
	return math.max(math.max(1, tonumber(minimum) or 1), digits)
end

function VOLT26.GameplayStats.SetMeasureSegments(player, segments)
	local state = VOLT26.Core.GetPlayerState(player)
	state.GameplayStats.MeasureSegments = DeepCopy(segments or {})
	return VOLT26.GameplayStats.GetMeasureSegments(player)
end

function VOLT26.GameplayStats.GetMeasureSegments(player)
	local state = VOLT26.Core.GetPlayerState(player)
	return DeepCopy(state.GameplayStats.MeasureSegments or {})
end

function VOLT26.GameplayStats.IsEndOfSegment(currentMeasure, segments, segmentIndex)
	local segment = segments and segments[segmentIndex] or nil
	if not segment then return false end
	local length = segment.streamEnd - segment.streamStart
	local count = math.floor(currentMeasure - segment.streamStart) + 1
	return count > length
end

function VOLT26.GameplayStats.GetMeasureText(currentMeasure, segments, segmentIndex, isLookAhead)
	segments = segments or {}
	if currentMeasure < 0 then
		local first = segments[1]
		if not first then return "" end
		if not isLookAhead then
			local negativeSpace = math.floor(currentMeasure * -1) + 1
			if not first.isBreak then return "(" .. negativeSpace .. ")" end
			return "(" .. negativeSpace + first.streamEnd - first.streamStart .. ")"
		elseif not first.isBreak then
			segmentIndex = segmentIndex - 1
		end
	end
	local segment = segments[segmentIndex]
	if not segment then return "" end
	local length = segment.streamEnd - segment.streamStart
	local count = math.floor(currentMeasure - segment.streamStart) + 1
	if segment.isBreak then
		return "(" .. (isLookAhead and length or length - count + 1) .. ")"
	end
	if not isLookAhead and count ~= 0 then return count .. "/" .. length end
	return tostring(length)
end

function VOLT26.GameplayStats.BuildCumulativeSeconds(durations, musicRate)
	local rate = VOLT26.MusicSelection.NormalizeMusicRate(musicRate)
	local result, total = {}, 0
	for _, duration in ipairs(durations or {}) do
		total = total + math.max(0, tonumber(duration) or 0) / rate
		result[#result + 1] = total
	end
	return result
end

function VOLT26.GameplayStats.GetRemainingSeconds(totalSeconds, elapsedOffset, currentSeconds, musicRate)
	local total = math.max(0, tonumber(totalSeconds) or 0)
	local offset = math.max(0, tonumber(elapsedOffset) or 0)
	local current = math.max(0, tonumber(currentSeconds) or 0)
	local rate = VOLT26.MusicSelection.NormalizeMusicRate(musicRate)
	return clamp(total - offset - current / rate, 0, total)
end

function VOLT26.GameplayStats.InterpolateVertex(first, second, offset)
	local x1, x2 = first[1][1], second[1][1]
	if x1 == x2 then return {{offset, first[1][2], 0}, DeepCopy(first[2])} end
	local ratio = clamp((offset - x1) / (x2 - x1), 0, 1)
	return {
		{offset, first[1][2] * (1 - ratio) + second[1][2] * ratio, 0},
		lerp_color(ratio, first[2], second[2]),
	}
end

VOLT26.TargetScore = {}

function VOLT26.TargetScore.ResolveTarget(index, machineBest, personalBest, gradeThresholds, fallbackIndex)
	index = tonumber(index) or 11
	local target
	if index == 17 then target = tonumber(machineBest)
	elseif index == 18 then target = tonumber(personalBest)
	else target = gradeThresholds and tonumber(gradeThresholds[index]) end
	if not target or target <= 0 then
		target = gradeThresholds and tonumber(gradeThresholds[fallbackIndex or 11]) or 0
	end
	return clamp(target or 0, 0, 1)
end

function VOLT26.TargetScore.CalculateProgress(actual, currentPossible, totalPossible, target)
	actual = tonumber(actual) or 0
	currentPossible = math.max(0, tonumber(currentPossible) or 0)
	totalPossible = math.max(0, tonumber(totalPossible) or 0)
	target = clamp(tonumber(target) or 0, 0, 1)
	local difference = totalPossible > 0 and (actual - target * currentPossible) / totalPossible or 0
	difference = math.max(difference, -target)
	local places = 2
	while math.abs(difference) < 0.1995 / math.pow(10, places)
		and totalPossible >= 2 * math.pow(10, places + 2) and places < 4 do
		places = places + 1
	end
	return {
		difference=difference,
		places=places,
		missed=(currentPossible - actual) > totalPossible * (1 - target),
	}
end

function VOLT26.TargetScore.NewTracker()
	return {missed=false}
end

function VOLT26.TargetScore.UpdateTracker(tracker, actual, currentPossible, totalPossible, target)
	local progress = VOLT26.TargetScore.CalculateProgress(actual, currentPossible, totalPossible, target)
	local newlyMissed = progress.missed and tracker.missed ~= true
	tracker.missed = tracker.missed or progress.missed
	return progress, newlyMissed
end

function VOLT26.TargetScore.GetMissedAction(player, eventMode)
	if eventMode ~= true then return nil end
	local action = VOLT26.Options.GetPlayerModifiers(player).ActionOnMissedTarget
	if action == "Fail" or action == "Restart" then return action end
	return nil
end

VOLT26.CourseSpeed = {
	Increment = {XMod=0.25, MMod=10, CMod=10},
	UpperLimit = {XMod=10, MMod=2000, CMod=2000},
}

function VOLT26.CourseSpeed.Adjust(kind, value, direction)
	local increment = VOLT26.CourseSpeed.Increment[kind]
	local upper = VOLT26.CourseSpeed.UpperLimit[kind]
	value = tonumber(value)
	if not increment or not upper or not value or (direction ~= -1 and direction ~= 1) then return nil end
	local adjusted = value + increment * direction
	return adjusted > 0 and adjusted <= upper and adjusted or value
end

function VOLT26.CourseSpeed.Format(kind, value)
	if kind == "XMod" then return ("mod,%.2fx"):format(value) end
	if kind == "MMod" then return ("mod,m%d"):format(value) end
	if kind == "CMod" then return ("mod,c%d"):format(value) end
	return nil
end

function VOLT26.CourseSpeed.GetActive(playerOptions)
	if not playerOptions then return nil end
	local cmod, mmod, xmod = playerOptions:CMod(), playerOptions:MMod(), playerOptions:XMod()
	if cmod ~= nil then return "CMod", cmod end
	if mmod ~= nil then return "MMod", mmod end
	if xmod ~= nil then return "XMod", xmod end
	return nil
end

VOLT26.Versus = {}

function VOLT26.Versus.CanCompare(firstModifiers, secondModifiers)
	return firstModifiers and secondModifiers
		and firstModifiers.ShowExScore == secondModifiers.ShowExScore
end

function VOLT26.Versus.NewScoreState()
	return {[PLAYER_1]=0, [PLAYER_2]=0}
end

function VOLT26.Versus.CalculateDancePointRatio(actual, possible)
	possible = tonumber(possible) or 0
	return possible > 0 and (tonumber(actual) or 0) / possible or 0
end

function VOLT26.Versus.UpdateScore(state, player, score)
	if player ~= PLAYER_1 and player ~= PLAYER_2 then return "Tie" end
	state[player] = tonumber(score) or 0
	if state[PLAYER_1] == state[PLAYER_2] then return "Tie" end
	return state[PLAYER_1] > state[PLAYER_2] and PLAYER_1 or PLAYER_2
end
