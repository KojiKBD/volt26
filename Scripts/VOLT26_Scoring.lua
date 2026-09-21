-- VOLT26 CORE: Judgment telemetry and scoring.
-- Loaded after SL_Init.lua, which creates the VOLT26 namespace and state.

VOLT26.Telemetry = {}

local ex_count_keys = { "W0", "W1", "W2", "W3", "W4", "W5", "Miss", "HitMine", "Held", "LetGo" }

local function new_ex_counts()
	local counts = {}
	for key in ivalues(ex_count_keys) do counts[key] = 0 end
	counts.W0_total = 0
	return counts
end

function VOLT26.Telemetry.IsEnabled()
	return true
end

function VOLT26.Telemetry.GetStage(player)
	return VOLT26.Gameplay.GetPlayerStageState(player)
end

function VOLT26.Telemetry.GetSnapshot(player)
	local stage = VOLT26.Telemetry.GetStage(player)
	return stage and stage.telemetry or nil
end

function VOLT26.Telemetry.Begin(player)
	local stage = VOLT26.Telemetry.GetStage(player)
	if not stage then return nil end

	local columns = {}
	for index=1,GAMESTATE:GetCurrentStyle():ColumnsPerPlayer() do
		columns[index] = {
			W0=0, W1=0, W2=0, W3=0, W4=0, W5=0, Miss=0,
			MissBecauseHeld=0,
			Early={ W0=0, W1=0, W2=0, W3=0, W4=0, W5=0 },
		}
	end

	stage.telemetry = {
		ex_counts = new_ex_counts(),
		offsets = {},
		column_judgments = columns,
	}

	-- Compatibility fields for evaluation actors that have not migrated yet.
	stage.ex_counts = stage.telemetry.ex_counts
	stage.sequential_offsets = {}
	stage.column_judgments = stage.telemetry.column_judgments
	return stage.telemetry
end

function VOLT26.Telemetry.Ensure(player)
	return VOLT26.Telemetry.GetSnapshot(player) or VOLT26.Telemetry.Begin(player)
end

function VOLT26.Telemetry.RecordExJudgment(player, params)
	if params.Player ~= player or IsAutoplay(player) then return nil end
	local telemetry = VOLT26.Telemetry.Ensure(player)
	if not telemetry then return nil end

	local stats = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
	local counts = telemetry.ex_counts
	local key, is_w0 = VOLT26.Scoring.NormalizeJudgment(
		params.TapNoteScore,
		params.HoldNoteScore,
		VOLT26.Gameplay.GetMode(),
		params.TapNoteScore and VOLT26.Scoring.IsW0Judgment(params, player) or false)
	if not VOLT26.Scoring.ApplyJudgment(counts, key, stats:GetFailed(), is_w0) then return nil end
	local ex_score, actual_points, actual_possible = VOLT26.Scoring.CalculateExScore(player, counts)
	return {
		Player=player,
		ExCounts=DeepCopy(counts),
		ExScore=ex_score,
		ActualPoints=actual_points,
		ActualPossible=actual_possible,
	}
end

local function current_course_offset(player)
	if not GAMESTATE:IsCourseMode() then return 0 end
	local offset = 0
	local entries = GAMESTATE:GetCurrentTrail(player):GetTrailEntries()
	for index=1,GAMESTATE:GetCourseSongIndex() do
		offset = offset + entries[index]:GetSong():GetLastSecond()
	end
	return offset
end

function VOLT26.Telemetry.NormalizeOffsetSample(score, tapNoteOffset, position, isAutohit)
	local offset = (score == "TapNoteScore_Miss" or score == "TapNoteScore_CheckpointMiss")
		and "Miss" or tapNoteOffset
	if offset ~= "Miss" and type(offset) ~= "number" then return nil end
	return {
		position=tonumber(position) or 0,
		offset=offset,
		is_autohit=isAutohit == true,
	}
end

function VOLT26.Telemetry.RecordOffset(player, params, require_step_on_hold_heads)
	local isMiss = params.TapNoteScore == "TapNoteScore_Miss"
		or params.TapNoteScore == "TapNoteScore_CheckpointMiss"
	if params.Player ~= player or params.HoldNoteScore or (not params.TapNoteOffset and not isMiss) then return end
	local telemetry = VOLT26.Telemetry.Ensure(player)
	if not telemetry then return end

	local score = params.TapNoteScore
	local is_autohit = score == "TapNoteScore_CheckpointHit"
	if not is_autohit and not require_step_on_hold_heads and params.Notes then
		local only_hold_heads, found_note = true, false
		for _, tapnote in pairs(params.Notes) do
			found_note = true
			if tapnote:GetTapNoteType() ~= "TapNoteType_HoldHead" then
				only_hold_heads = false
				break
			end
		end
		is_autohit = found_note and only_hold_heads
	end

	local position = current_course_offset(player) + GAMESTATE:GetCurMusicSeconds()
	local sample = VOLT26.Telemetry.NormalizeOffsetSample(score, params.TapNoteOffset, position, is_autohit)
	if not sample then return end
	telemetry.offsets[#telemetry.offsets+1] = sample
	local stage = VOLT26.Telemetry.GetStage(player)
	stage.sequential_offsets[#stage.sequential_offsets+1] = { sample.position, sample.offset, sample.is_autohit }
end

function VOLT26.Telemetry.RecordColumnJudgment(player, params)
	if params.Player ~= player or not params.Notes or not params.TapNoteScore then return end
	if GAMESTATE:GetPlayerState(player):GetHealthState() == "HealthState_Dead" then return end
	local telemetry = VOLT26.Telemetry.Ensure(player)
	if not telemetry then return end
	local modifiers = VOLT26.Options.GetPlayerModifiers(player)

	for column, tapnote in pairs(params.Notes) do
		local columnData = telemetry.column_judgments[column]
		local note_type = ToEnumShortString(tapnote:GetTapNoteType())
		if columnData and (note_type == "Tap" or note_type == "HoldHead" or note_type == "Lift") then
			local judgment = ToEnumShortString(params.TapNoteScore)
			if params.EarlyTapNoteScore then
				local early = ToEnumShortString(params.EarlyTapNoteScore)
				if early ~= "None" then
					if VOLT26.Scoring.IsW0Judgment(params, player) then
						columnData.Early.W0 = columnData.Early.W0 + 1
					elseif judgment ~= "W4" and judgment ~= "W5" and judgment ~= "Miss" and columnData.Early[judgment] then
						columnData.Early[judgment] = columnData.Early[judgment] + 1
					end
					if columnData.Early[early] then columnData.Early[early] = columnData.Early[early] + 1 end
				end
			end
			if modifiers.ShowFaPlusWindow and modifiers.ShowFaPlusPane and VOLT26.Scoring.IsW0Judgment(params, player) then
				judgment = "W0"
			end
			if not columnData[judgment] then return end
			columnData[judgment] = columnData[judgment] + 1
			if note_type ~= "Lift" and judgment == "Miss" and tapnote:GetTapNoteResult():GetHeld() then
				columnData.MissBecauseHeld = columnData.MissBecauseHeld + 1
			end
		end
	end
end

VOLT26.Scoring = {}

VOLT26.Scoring.ExCountKeys = ex_count_keys

function VOLT26.Scoring.NewExCounts()
	return new_ex_counts()
end

function VOLT26.Scoring.IsW0Judgment(params, player)
	if params.Player ~= player or params.HoldNoteScore then return false end
	if params.TapNoteScore ~= "TapNoteScore_W1" or VOLT26.Gameplay.GetMode() ~= "ITG" then return false end
	if type(params.TapNoteOffset) ~= "number" then return false end
	local prefs = VOLT26.Preferences["FA+"]
	local scale = PREFSMAN:GetPreference("TimingWindowScale")
	local window = prefs.TimingWindowSecondsW1 * scale + prefs.TimingWindowAdd
	return math.abs(params.TapNoteOffset) <= window
end

function VOLT26.Scoring.NormalizeJudgment(tapNoteScore, holdNoteScore, gameMode, isW0)
	if holdNoteScore then
		local key = ToEnumShortString(holdNoteScore)
		if key == "MissedHold" then key = "LetGo" end
		if key == "Held" or key == "LetGo" then return key, false end
		return nil, false
	end
	if not tapNoteScore then return nil, false end

	local key = ToEnumShortString(tapNoteScore)
	if gameMode == "ITG" and key == "W1" and isW0 then return "W0", true end
	if gameMode ~= "ITG" then
		local tier = key:match("W(%d)")
		if tier then key = "W"..(tonumber(tier)-1) end
	end
	return key, false
end

function VOLT26.Scoring.ApplyJudgment(counts, key, failed, isW0)
	if type(counts) ~= "table" or counts[key] == nil then return false end
	if isW0 then counts.W0_total = (counts.W0_total or 0) + 1 end
	if failed then return false end
	counts[key] = counts[key] + 1
	return true
end

function VOLT26.Scoring.GetExCounts(player)
	local telemetry = VOLT26.Telemetry.GetSnapshot(player)
	return telemetry and telemetry.ex_counts or nil
end

function VOLT26.Scoring.GetExSnapshot(player)
	return DeepCopy(VOLT26.Scoring.GetExCounts(player) or VOLT26.Scoring.NewExCounts())
end

function VOLT26.Scoring.CalculateExFromRadar(counts, radar, weights, noMines)
	weights = weights or VOLT26.ExWeights
	radar = radar or {}
	local totalPossible = (radar.TapsAndHolds or 0) * (weights.W0 or 0)
		+ ((radar.Holds or 0) + (radar.Rolls or 0)) * (weights.Held or 0)
	local totalPoints = noMines and (radar.Mines or 0) * (weights.HitMine or 0) or 0
	for _, key in ipairs(ex_count_keys) do
		totalPoints = totalPoints + ((counts and counts[key]) or 0) * (weights[key] or 0)
	end
	if totalPossible <= 0 then return 0, totalPoints, totalPossible end
	local percent = math.max(0, math.floor(totalPoints / totalPossible * 10000) / 100)
	return percent, totalPoints, totalPossible
end

function VOLT26.Scoring.CalculateExScore(player, ex_counts, use_actual_w0_weight)
	local steps_or_trail = GAMESTATE:IsCourseMode()
		and GAMESTATE:GetCurrentTrail(player) or GAMESTATE:GetCurrentSteps(player)
	if not steps_or_trail then return 0 end

	local sourceRadar = steps_or_trail:GetRadarValues(player)
	local radar = {
		TapsAndHolds = sourceRadar:GetValue("RadarCategory_TapsAndHolds"),
		Holds = sourceRadar:GetValue("RadarCategory_Holds"),
		Rolls = sourceRadar:GetValue("RadarCategory_Rolls"),
		Mines = sourceRadar:GetValue("RadarCategory_Mines"),
	}
	local weights = DeepCopy(VOLT26.ExWeights)
	if use_actual_w0_weight then weights.W0 = 3.5 end
	local player_options = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
	local counts = ex_counts or VOLT26.Scoring.GetExCounts(player)
	return VOLT26.Scoring.CalculateExFromRadar(counts, radar, weights, player_options:NoMines())
end
