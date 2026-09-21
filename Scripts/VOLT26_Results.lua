-- VOLT26 CORE: Normalized results, record policy, timing analysis, and failure snapshots.
-- Loaded after SL_Init.lua, which creates the VOLT26 namespace and state.

VOLT26.Results = {}

local ResultTapWindows = {"W1", "W2", "W3", "W4", "W5", "Miss"}
local ResultRadarCategories = {"Hands", "Holds", "Mines", "Rolls"}

function VOLT26.Results.GetStageStats(player)
	local stageStats = STATSMAN:GetCurStageStats()
	local style = GAMESTATE:GetCurrentStyle()
	if style and ToEnumShortString(style:GetStyleType()) == "TwoPlayersSharedSides" then
		return stageStats:GetRoutineStageStats()
	end
	return stageStats:GetPlayerStageStats(player)
end

function VOLT26.Results.GetCurrent(player)
	local stats = VOLT26.Results.GetStageStats(player)
	local modifiers = VOLT26.Options.GetPlayerModifiers(player)
	local telemetry = VOLT26.Telemetry.GetSnapshot(player) or {}
	local judgments = {}
	for _, window in ipairs(ResultTapWindows) do
		judgments[window] = stats:GetTapNoteScores("TapNoteScore_"..window)
	end

	local capturedExJudgments = VOLT26.Scoring.GetExCounts(player) or {}
	local exJudgments = DeepCopy(capturedExJudgments)
	local radar = {actual={}, possible={}}
	for _, category in ipairs(ResultRadarCategories) do
		radar.actual[category] = stats:GetRadarActual():GetValue("RadarCategory_"..category)
		radar.possible[category] = stats:GetRadarPossible():GetValue("RadarCategory_"..category)
	end
	if VOLT26.Gameplay.GetMode() == "ITG" then
		exJudgments.W0 = capturedExJudgments.W0_total or 0
		exJudgments.W1 = math.max(0, judgments.W1 - exJudgments.W0)
		for _, window in ipairs({"W2", "W3", "W4", "W5", "Miss"}) do
			exJudgments[window] = judgments[window]
		end
		if not modifiers.TimingWindows[4] then exJudgments.W4 = nil end
		if not modifiers.TimingWindows[5] then exJudgments.W5 = nil end
	end
	local stepsOrTrail = GAMESTATE:IsCourseMode()
		and GAMESTATE:GetCurrentTrail(player) or GAMESTATE:GetCurrentSteps(player)
	local chartRadar = stepsOrTrail and stepsOrTrail:GetRadarValues(player) or nil
	if chartRadar then
		exJudgments.totalSteps = chartRadar:GetValue("RadarCategory_TapsAndHolds")
		for _, category in ipairs({"Holds", "Mines", "Rolls"}) do
			local possible = chartRadar:GetValue("RadarCategory_"..category)
			exJudgments["total"..category] = possible
			exJudgments[category] = radar.actual[category]
		end
		local options = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
		if options:NoMines() then
			exJudgments.Mines, exJudgments.totalMines = 0, 0
		else
			exJudgments.Mines = exJudgments.totalMines - radar.actual.Mines
		end
	end

	local exPercent = VOLT26.Scoring.CalculateExScore(player)
	local grade = stats:GetGrade()
	local song = GAMESTATE:GetCurrentSong()
	if song and song:GetDisplayFullTitle() == "D" then grade = "Grade_Tier99" end
	if exPercent == 100 then grade = "Grade_Tier00" end

	return {
		failed = stats:GetFailed(),
		percentDP = stats:GetPercentDancePoints(),
		exPercent = exPercent,
		grade = grade,
		judgments = judgments,
		exJudgments = exJudgments,
		columnJudgments = DeepCopy(telemetry.column_judgments or {}),
		radar = radar,
		showEx = modifiers.ShowExScore == true,
		timingWindows = DeepCopy(modifiers.TimingWindows),
	}
end

function VOLT26.Scoring.GetDetailedJudgments(player)
	return DeepCopy(VOLT26.Results.GetCurrent(player).exJudgments)
end

local function EventMachineRecordIndex(player, stats, machineHighScores)
	local current = stats:GetHighScore()
	local profile = PROFILEMAN:GetProfile(player)
	local lastUsedName = profile and profile:GetLastUsedHighScoreName() or ""
	for index, highScore in ipairs(machineHighScores) do
		local nameMatches = current:GetName() == lastUsedName
		if #GAMESTATE:GetHumanPlayers() == 1 and current:GetName() == "EVNT" then nameMatches = true end
		if not nameMatches and #GAMESTATE:GetHumanPlayers() > 1 then
			local playedStage = STATSMAN:GetPlayedStageStats(1)
			local otherStats = playedStage and playedStage:GetPlayerStageStats(OtherPlayer[player]) or nil
			nameMatches = otherStats == nil or highScore:GetScore() ~= otherStats:GetHighScore():GetScore()
		end
		if not nameMatches and #GAMESTATE:GetHumanPlayers() > 1 then
			local playedStage = STATSMAN:GetPlayedStageStats(1)
			local otherStats = playedStage and playedStage:GetPlayerStageStats(OtherPlayer[player]) or nil
			nameMatches = otherStats == nil or highScore:GetScore() ~= otherStats:GetHighScore():GetScore()
		end
		if current:GetScore() == highScore:GetScore()
			and current:GetDate() == highScore:GetDate()
			and nameMatches then
			return index - 1
		end
	end
	return -1
end

function VOLT26.Results.GetRecordStatus(player)
	local stats = VOLT26.Results.GetStageStats(player)
	local songOrCourse = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or GAMESTATE:GetCurrentSong()
	local stepsOrTrail = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player) or GAMESTATE:GetCurrentSteps(player)
	local machineHighScores = PROFILEMAN:GetMachineProfile():GetHighScoreList(songOrCourse, stepsOrTrail):GetHighScores()
	local maxMachine = PREFSMAN:GetPreference("MaxHighScoresPerListForMachine")
	local machineIndex = stats:GetMachineHighScoreIndex()
	local personalIndex = stats:GetPersonalHighScoreIndex()
	local eligibleScore = stats:GetPercentDancePoints() >= 0.01

	if GAMESTATE:IsEventMode() then
		machineIndex = EventMachineRecordIndex(player, stats, machineHighScores)
	end

	local earnedMachine = eligibleScore and machineIndex >= 0
	if GAMESTATE:IsEventMode() and eligibleScore then
		if #machineHighScores == 0 then
			earnedMachine = true
		else
			local cutoff = machineHighScores[math.min(maxMachine, #machineHighScores)]
			earnedMachine = cutoff ~= nil and stats:GetHighScore():GetPercentDP() >= cutoff:GetPercentDP()
		end
	end

	local result = {
		machineIndex = machineIndex,
		personalIndex = personalIndex,
		earnedMachine = earnedMachine,
		earnedPersonal = eligibleScore and personalIndex >= 0,
		earnedTopTwoPersonal = personalIndex >= 0 and personalIndex < 2,
	}
	result.enteringName = result.earnedMachine or result.earnedPersonal
	return result
end

function VOLT26.Results.ApplyNameEntryEligibility(player)
	local status = VOLT26.Results.GetRecordStatus(player)
	-- Eligibility accumulates across the set: a later stage without a record must
	-- not cancel a record earned earlier.  The flag resets with the player state.
	local highScores = VOLT26.Core.GetPlayerState(player).HighScores
	highScores.EnteringName = highScores.EnteringName or status.enteringName
	return status
end

VOLT26.Analysis = {
	MaxScatterVerticesPerBatch = 16000,
}

function VOLT26.Analysis.GetTimingOffsets(player)
	local telemetry = VOLT26.Telemetry.GetSnapshot(player)
	return DeepCopy(telemetry and telemetry.offsets or {})
end

function VOLT26.Analysis.GetWorstJudgment(offsets)
	local worst = 1
	for _, sample in ipairs(offsets or {}) do
		if sample.offset ~= "Miss" then
			worst = math.max(worst, DetermineTimingWindow(sample.offset))
		end
	end
	return worst
end

function VOLT26.Analysis.AnalyzeTiming(offsets)
	local valid = {}
	local distribution = {}
	local signedSum, absoluteSum, maxError = 0, 0, 0
	for _, sample in ipairs(offsets or {}) do
		local value = sample.offset
		if value ~= "Miss" and not sample.is_autohit then
			valid[#valid + 1] = value
			signedSum = signedSum + value
			absoluteSum = absoluteSum + math.abs(value)
			maxError = math.max(maxError, math.abs(value))
			local bucket = round(value, 3)
			distribution[bucket] = (distribution[bucket] or 0) + 1
		end
	end

	local count = #valid
	local meanSeconds = count > 0 and signedSum / count or 0
	local sigmaSeconds = 0
	if count > 1 then
		local squaredDifferenceSum = 0
		for _, value in ipairs(valid) do
			squaredDifferenceSum = squaredDifferenceSum + math.pow(value - meanSeconds, 2)
		end
		sigmaSeconds = math.sqrt(squaredDifferenceSum / (count - 1))
	end

	return {
		count = count,
		meanAbsoluteMs = count > 0 and absoluteSum / count * 1000 or 0,
		meanOffsetMs = meanSeconds * 1000,
		sigmaMs = sigmaSeconds * 1000,
		threeSigmaMs = sigmaSeconds * 3000,
		maxErrorMs = maxError * 1000,
		worstOffsetSeconds = maxError,
		distribution = distribution,
	}
end

function VOLT26.Analysis.SmoothDistribution(distribution, worstWindow)
	local smoothed = {}
	local weights = {0.045, 0.090, 0.180, 0.370, 0.180, 0.090, 0.045}
	local highestCount = 0
	for _, count in pairs(distribution or {}) do highestCount = math.max(highestCount, count) end
	local millisecondLimit = math.floor(worstWindow * 1000 + 0.5)
	for millisecond=-millisecondLimit,millisecondLimit do
		local value = 0
		for offset=-3,3 do
			local source = round(clamp(millisecond + offset, -millisecondLimit, millisecondLimit) / 1000, 3)
			value = value + (distribution[source] or 0) * weights[offset + 4]
		end
		smoothed[round(millisecond / 1000, 3)] = value
	end
	return {values=smoothed, highestCount=highestCount}
end

function VOLT26.Analysis.GetTimeline(player)
	if GAMESTATE:IsCourseMode() then
		local segments, elapsed = {}, 0
		local trail = GAMESTATE:GetCurrentTrail(player)
		for _, entry in ipairs(trail and trail:GetTrailEntries() or {}) do
			local duration = entry:GetSong():GetLastSecond()
			segments[#segments + 1] = {startSecond=elapsed, endSecond=elapsed + duration}
			elapsed = elapsed + duration
		end
		return {firstSecond=0, lastSecond=elapsed, segments=segments}
	end

	local steps = GAMESTATE:GetCurrentSteps(player)
	local song = GAMESTATE:GetCurrentSong()
	local firstSecond = steps and math.min(steps:GetTimingData():GetElapsedTimeFromBeat(0), 0) or 0
	return {firstSecond=firstSecond, lastSecond=song and song:GetLastSecond() or 0, segments={}}
end

function VOLT26.Analysis.BuildScatterBatches(offsets, timeline, width, height, worstWindow)
	local batches = {{}}
	local maxPoints = math.floor(VOLT26.Analysis.MaxScatterVerticesPerBatch / 4)
	local lastSecond = math.max(timeline.lastSecond, timeline.firstSecond + 0.001)
	for _, sample in ipairs(offsets or {}) do
		local batch = batches[#batches]
		if #batch >= maxPoints then batch = {}; batches[#batches + 1] = batch end
		local isMiss = sample.offset == "Miss"
		local noteSecond = sample.position - (isMiss and worstWindow or sample.offset)
		batch[#batch + 1] = {
			x = clamp(scale(noteSecond, timeline.firstSecond, lastSecond + 0.05, 0, width), 0, width),
			y = isMiss and 0 or clamp(scale(sample.offset, worstWindow, -worstWindow, 0, height), 0, height),
			offset = sample.offset,
			isMiss = isMiss,
		}
	end
	return batches
end

VOLT26.Failure = {}

function VOLT26.Failure.GetSnapshot(player)
	local stage = VOLT26.Gameplay.GetPlayerStageState(player)
	local failure = stage and stage.failure or nil
	return failure and DeepCopy(failure) or nil
end

function VOLT26.Failure.GetCourseCumulativeLengths(player)
	if not GAMESTATE:IsCourseMode() then return nil end
	local result, seconds = {}, 0
	local trail = GAMESTATE:GetCurrentTrail(player)
	if not trail then return result end
	local rate = VOLT26.MusicSelection.GetMusicRate()
	for _, entry in ipairs(trail:GetTrailEntries()) do
		seconds = seconds + entry:GetSong():GetLastSecond() / rate
		result[#result+1] = seconds
	end
	return result
end

function VOLT26.Failure.GetCurrentPosition(player)
	local seconds = GAMESTATE:GetPlayerState(player):GetSongPosition():GetMusicSecondsVisible()
		/ VOLT26.MusicSelection.GetMusicRate()
	if GAMESTATE:IsCourseMode() then
		local cumulative = VOLT26.Failure.GetCourseCumulativeLengths(player)
		local course_index = GAMESTATE:GetCourseSongIndex()
		if course_index > 0 then seconds = seconds + (cumulative[course_index] or 0) end
	end
	return seconds
end

function VOLT26.Failure.GetTotalLength(player)
	local seconds = 0
	if GAMESTATE:IsCourseMode() then
		local trail = GAMESTATE:GetCurrentTrail(player)
		if trail then seconds = trail:GetLengthSeconds() end
	else
		local song = GAMESTATE:GetCurrentSong()
		if song then seconds = song:GetLastSecond() end
	end
	return math.max(0, seconds) / VOLT26.MusicSelection.GetMusicRate()
end

function VOLT26.Failure.Record(player)
	local stage = VOLT26.Gameplay.GetPlayerStageState(player)
	if not stage then return end
	local player_state = GAMESTATE:GetPlayerState(player)
	local death_second = VOLT26.Failure.GetCurrentPosition(player)
	local total_seconds = VOLT26.Failure.GetTotalLength(player)
	local graph_denominator = total_seconds
	local graph_label = total_seconds - death_second

	if GAMESTATE:IsCourseMode() then
		local cumulative = VOLT26.Failure.GetCourseCumulativeLengths(player)
		graph_denominator = cumulative[GAMESTATE:GetCourseSongIndex()+1] or total_seconds
		graph_label = total_seconds > 0 and death_second / total_seconds or 0
	end

	local failure = VOLT26.Failure.BuildSnapshot(death_second, total_seconds, graph_denominator, graph_label)

	local current_measure = math.floor(player_state:GetSongPosition():GetSongBeatVisible() / 4)
	local streams = VOLT26.Core.GetPlayerState(player).Streams
	if streams and streams.NotesPerMeasure and (streams.NotesPerMeasure[current_measure+1] or 0) >= 16 then
		for _, stream in ipairs(VOLT26.GameplayStats.GetMeasureSegments(player)) do
			if current_measure >= stream.streamStart and current_measure < stream.streamEnd then
				local run = current_measure - stream.streamStart + 1
				local total = stream.streamEnd - stream.streamStart
				failure.death_measures = string.format("%s/%s", run, total)
				break
			end
		end
	end

	stage.failure = failure
	-- Compatibility fields for the existing Evaluation graph.
	stage.TotalSeconds = failure.total_seconds
	stage.DeathSecond = failure.death_second
	stage.GraphPercentage = failure.graph_percentage
	stage.GraphLabel = failure.graph_label
	stage.DeathMeasures = failure.death_measures
	return DeepCopy(failure)
end

function VOLT26.Failure.BuildSnapshot(deathSecond, totalSeconds, graphDenominator, graphLabel)
	local total = math.max(0, tonumber(totalSeconds) or 0)
	local death = clamp(tonumber(deathSecond) or 0, 0, total)
	local denominator = math.max(0, tonumber(graphDenominator) or total)
	return {
		total_seconds=total,
		death_second=death,
		graph_percentage=denominator > 0 and clamp(death / denominator, 0, 1) or 0,
		graph_label=math.max(0, tonumber(graphLabel) or (total - death)),
	}
end

function VOLT26.Failure.NewExitGuard()
	return { used_autoplay = { [PLAYER_1]=false, [PLAYER_2]=false } }
end

function VOLT26.Failure.ObserveJudgment(guard, params)
	if params.Player and IsAutoplay(params.Player) then
		guard.used_autoplay[params.Player] = true
	end
end

function VOLT26.Failure.WasPrematureExit()
	local stage_stats = STATSMAN:GetCurStageStats()
	local premature
	if stage_stats.GaveUp then
		premature = stage_stats:GaveUp()
	else
		local song = GAMESTATE:GetCurrentSong()
		premature = song and GAMESTATE:GetCurMusicSeconds() < song:GetLastSecond() or false
	end

	if GAMESTATE:IsCourseMode() then
		local course = GAMESTATE:GetCurrentCourse()
		if course and GAMESTATE:GetCourseSongIndex() + 1 < course:GetNumCourseEntries() then
			premature = true
		end
	end
	return premature
end

function VOLT26.Failure.ReconcileExit(guard)
	local premature = VOLT26.Failure.WasPrematureExit()
	local reconciled = {}
	for player in ivalues(GAMESTATE:GetEnabledPlayers()) do
		local shouldFail = VOLT26.Failure.ShouldFailAttempt(premature, guard.used_autoplay[player])
		if shouldFail then
			STATSMAN:GetCurStageStats():GetPlayerStageStats(player):FailPlayer()
		end
		reconciled[player] = shouldFail
	end
	return reconciled
end

function VOLT26.Failure.ShouldFailAttempt(premature, usedAutoplay)
	return premature == true or usedAutoplay == true
end
