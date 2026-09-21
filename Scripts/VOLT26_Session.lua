-- VOLT26 CORE: Session accounting.
-- Loaded after SL_Init.lua, which creates the VOLT26 namespace and state.

VOLT26.Session = {}

local sessionTapJudgments = { "W0", "W1", "W2", "W3", "W4", "W5" }

local function sessionTime(value)
	return math.max(0, tonumber(value) or 0)
end

function VOLT26.Session.NewTimer(now)
	now = sessionTime(now)
	return {
		schema_version=1,
		screen_started_at=now,
		active_started_at=now,
		active_seconds=0,
		paused=false,
		finished=false,
		completed=false,
	}
end

function VOLT26.Session.SetTimerPaused(timer, paused, now)
	if type(timer) ~= "table" or timer.finished then return false end
	paused = paused == true
	if timer.paused == paused then return false end
	now = sessionTime(now)
	if paused then
		timer.active_seconds = sessionTime(timer.active_seconds)
		if timer.active_started_at then
			timer.active_seconds = timer.active_seconds + math.max(0, now - sessionTime(timer.active_started_at))
		end
		timer.active_started_at = nil
	else
		timer.active_started_at = now
	end
	timer.paused = paused
	return true
end

function VOLT26.Session.FinishTimer(timer, now)
	if type(timer) ~= "table" then return nil end
	if timer.finished then return DeepCopy(timer) end
	now = sessionTime(now)
	timer.active_seconds = sessionTime(timer.active_seconds)
	if not timer.paused and timer.active_started_at then
		timer.active_seconds = timer.active_seconds + math.max(0, now - sessionTime(timer.active_started_at))
	end
	timer.active_started_at = nil
	timer.screen_seconds = math.max(0, now - sessionTime(timer.screen_started_at))
	timer.active_seconds = math.min(timer.screen_seconds, math.max(0, timer.active_seconds))
	timer.finished = true
	return DeepCopy(timer)
end

function VOLT26.Session.BeginGameplay(player, now)
	local stage = VOLT26.Gameplay.GetPlayerStageState(player)
	if not stage then return nil end
	stage.session = VOLT26.Session.NewTimer(now)
	return DeepCopy(stage.session)
end

function VOLT26.Session.SetGameplayPaused(player, paused, now)
	local stage = VOLT26.Gameplay.GetPlayerStageState(player)
	return stage and VOLT26.Session.SetTimerPaused(stage.session, paused, now) or false
end

function VOLT26.Session.FinishGameplay(player, now)
	local stage = VOLT26.Gameplay.GetPlayerStageState(player)
	if not stage then return nil end
	return VOLT26.Session.FinishTimer(stage.session, now)
end

function VOLT26.Session.MarkStageCompleted(player, now)
	local stage = VOLT26.Gameplay.GetPlayerStageState(player)
	if not stage or not stage.session then return false end
	if not stage.session.finished then VOLT26.Session.FinishTimer(stage.session, now) end
	stage.session.completed = true
	return true
end

function VOLT26.Session.CountTapHits(columnJudgments)
	local total = 0
	for _, judgments in pairs(type(columnJudgments) == "table" and columnJudgments or {}) do
		if type(judgments) == "table" then
			for _, judgment in ipairs(sessionTapJudgments) do
				total = total + math.max(0, tonumber(judgments[judgment]) or 0)
			end
		end
	end
	return total
end

function VOLT26.Session.SummarizeStages(stages)
	local summary = {songs_played=0, tap_hits=0, screen_seconds=0, active_seconds=0}
	for _, stage in pairs(type(stages) == "table" and stages or {}) do
		if type(stage) == "table" then
			local session = type(stage.session) == "table" and stage.session or nil
			local screenSeconds = session and session.screen_seconds or stage.duration
			local columnJudgments = stage.telemetry and stage.telemetry.column_judgments
				or stage.column_judgments
			local include = session and session.completed == true
				or (not session and (screenSeconds ~= nil or columnJudgments ~= nil))
			if include then
				summary.songs_played = summary.songs_played + 1
				summary.screen_seconds = summary.screen_seconds + sessionTime(screenSeconds)
				summary.active_seconds = summary.active_seconds
					+ sessionTime(session and session.active_seconds or screenSeconds)
				summary.tap_hits = summary.tap_hits + VOLT26.Session.CountTapHits(columnJudgments)
			end
		end
	end
	return summary
end

function VOLT26.Session.GetSummary(player)
	local state = VOLT26.Core.GetPlayerState(player)
	return VOLT26.Session.SummarizeStages(state and state.Stages.Stats or nil)
end

function VOLT26.Session.FormatDuration(seconds)
	local total = math.floor(sessionTime(seconds) + 0.5)
	local hours = math.floor(total / 3600)
	local minutes = math.floor(total % 3600 / 60)
	return {hours=hours, minutes=minutes, seconds=total % 60}
end

function VOLT26.Session.GetProfileSummary(player)
	if not PROFILEMAN:IsPersistentProfile(player) then return nil end
	local profile = PROFILEMAN:GetProfile(player)
	if not profile then return nil end
	return {
		display_name=profile:GetDisplayName(),
		calories=profile:GetIgnoreStepCountCalories() and nil or round(profile:GetCaloriesBurnedToday()),
		total_songs=profile:GetNumTotalSongsPlayed(),
	}
end
