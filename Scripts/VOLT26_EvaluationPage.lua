-- VOLT26.EvaluationPage: what the P5 evaluation page ("WANTED") shows for one
-- player, as plain data.  No actors, no coordinates: the screen
-- (BGAnimations/ScreenEvaluationStage overlay/Wanted/) draws it.
--
--   Page.GetCard(player)      name, level, modifiers, EX and ITG scores, grade,
--                             the seven judgment rows, holds/mines/rolls
--   Page.GetGraph(player)     the end-of-song graph, as Simply Love draws it:
--                             note density per measure, the life line, the
--                             judgment offsets and the point of failure, all
--                             on one timeline normalised to 0..1
--   Page.PageCount()          how many pages a player can cycle through

VOLT26.EvaluationPage = VOLT26.EvaluationPage or {}
local Page = VOLT26.EvaluationPage

-- The judgment rows, top to bottom: the 10/15 ms Fantastic, the rest of the
-- Fantastic window, then Excellent .. Miss.
Page.RowKeys = { "W0", "W1", "W2", "W3", "W4", "W5", "Miss" }
Page.RowLabels = {
	W0 = "Fantastic", W1 = "Fantastic", W2 = "Excellent", W3 = "Great",
	W4 = "Decent", W5 = "Way Off", Miss = "Miss",
}

-- Number of pages each player can show: the WANTED page first, then the
-- inherited Simply Love panes until they are redesigned.
Page.InheritedPanes = 8

local function floorPercent(value)
	return ("%.2f"):format(math.floor(value * 100 + 1e-6) / 100)
end

local function stepsOrTrail(player)
	if GAMESTATE:IsCourseMode() then return GAMESTATE:GetCurrentTrail(player) end
	return GAMESTATE:GetCurrentSteps(player)
end

local function playerName(player)
	local name = PROFILEMAN:GetPlayerName(player)
	if not name or name == "" then name = ToEnumShortString(player) end
	return name
end

-- Simply Love's modifier line (GetPlayerOptionsString) without the SL table:
-- the engine's option list, a 1x speed it leaves out, Mini as a percentage,
-- and the timing window scale.
function Page.GetModifierText(player)
	local modifiers = VOLT26.Options.GetPlayerModifiers(player) or {}
	local options = GAMESTATE:GetPlayerState(player):GetPlayerOptionsArray("ModsLevel_Preferred")
	local parts = {}
	if modifiers.SpeedModType == "X" and modifiers.SpeedMod == 1 then parts[#parts+1] = "1x" end
	local renames = { SuperShuffle = "Blender", HyperShuffle = "Random", LRMirror = "LR-Mirror", UDMirror = "UD-Mirror" }
	for _, option in ipairs(options) do
		if option ~= "FailAtEnd" and option ~= "FailImmediateContinue" and option ~= "FailImmediate"
			and not option:find("Lights") then
			if option:match("Mini") and modifiers.Mini then option = tostring(modifiers.Mini) .. " Mini" end
			if option:match("Cover") then option = THEME:GetString("OptionNames", "Cover") end
			parts[#parts+1] = renames[option] or option
		end
	end
	local scale = PREFSMAN:GetPreference("TimingWindowScale")
	if scale ~= 1 then parts[#parts+1] = ("TW %d%%"):format(math.floor(scale * 100 + 0.5)) end
	return table.concat(parts, ", ")
end

-- Grade -> what to draw: a letter (cutout lettering) or a number of stars.
local function gradeShape(grade)
	local letter = VOLT26.Cutout and VOLT26.Cutout.GradeLetters and VOLT26.Cutout.GradeLetters[grade]
	local tier = tonumber((grade or ""):match("Grade_Tier(%d+)"))
	local stars = 0
	if not letter and tier and tier <= 4 then stars = tier == 0 and 5 or 5 - tier end
	return letter, stars
end

local function judgmentRows(result)
	local mode = VOLT26.Gameplay.GetMode()
	local windows = result.timingWindows or {}
	local counts, enabled = {}, {}
	if mode == "FA+" then
		-- FA+ windows: W1 is the 10/15 ms Fantastic, W2 the rest of it; there
		-- is no Way Off.
		counts = { W0 = result.judgments.W1, W1 = result.judgments.W2, W2 = result.judgments.W3,
			W3 = result.judgments.W4, W4 = result.judgments.W5, W5 = 0, Miss = result.judgments.Miss }
		enabled = { W0 = true, W1 = true, W2 = true, W3 = true, W4 = windows[5] ~= false, W5 = false, Miss = true }
	else
		local ex = result.exJudgments or {}
		local w0 = ex.W0 or 0
		counts = { W0 = w0, W1 = math.max(0, (result.judgments.W1 or 0) - w0), W2 = result.judgments.W2,
			W3 = result.judgments.W3, W4 = result.judgments.W4, W5 = result.judgments.W5, Miss = result.judgments.Miss }
		enabled = { W0 = true, W1 = true, W2 = windows[2] ~= false, W3 = windows[3] ~= false,
			W4 = windows[4] ~= false, W5 = windows[5] ~= false, Miss = true }
	end
	local rows = {}
	for _, key in ipairs(Page.RowKeys) do
		rows[#rows+1] = { key = key, label = Page.RowLabels[key], count = counts[key] or 0, enabled = enabled[key] }
	end
	return rows
end

function Page.GetCard(player)
	local result = VOLT26.Results.GetCurrent(player)
	local chart = stepsOrTrail(player)
	local letter, stars = gradeShape(result.grade)
	local function radar(category)
		return {
			actual = math.max(0, math.floor(result.radar.actual[category] or 0)),
			possible = math.max(0, math.floor(result.radar.possible[category] or 0)),
		}
	end
	return {
		player = player,
		name = playerName(player),
		meter = chart and chart:GetMeter() or 0,
		difficulty = chart and chart:GetDifficulty() or nil,
		modifiers = Page.GetModifierText(player),
		ex = floorPercent(result.exPercent or 0),
		itg = floorPercent((result.percentDP or 0) * 100),
		grade = result.grade,
		gradeLetter = letter,
		gradeStars = stars,
		failed = result.failed,
		rows = judgmentRows(result),
		holds = radar("Holds"),
		mines = radar("Mines"),
		rolls = radar("Rolls"),
	}
end

-- ---------------------------------------------------------------------------
-- The graph.  Every u is a position on the play's timeline (0 = its first
-- second, 1 = its last, as VOLT26.Analysis.GetTimeline), every v a height
-- from the bottom (0) to the top (1).

local function densityOf(steps, player, timing, uOf, peak)
	local data = VOLT26.ChartData.Refresh(steps, player)
	local nps = data and data.NPSperMeasure or {}
	local points, started = {}, false
	if not peak or peak <= 0 then return points end
	for i, value in ipairs(nps) do
		if value > 0 then started = true end
		if started then
			points[#points+1] = { uOf(timing:GetElapsedTimeFromBeat((i - 1) * 4)), math.min(1, value / peak) }
		end
	end
	return points
end

local function density(player, timeline)
	local span = math.max(timeline.lastSecond - timeline.firstSecond, 0.001)
	local result = {}
	if not GAMESTATE:IsCourseMode() then
		local steps = GAMESTATE:GetCurrentSteps(player)
		if not steps then return result end
		local data = VOLT26.ChartData.Refresh(steps, player)
		local points = densityOf(steps, player, steps:GetTimingData(),
			function(t) return (t - timeline.firstSecond) / span end, data and data.PeakNPS)
		if #points > 0 then points[#points+1] = { 1, 0 } end
		return points
	end
	-- Course: each song's measures on its own stretch of the course timeline,
	-- all on the course's highest peak.
	local trail = GAMESTATE:GetCurrentTrail(player)
	local entries = trail and trail:GetTrailEntries() or {}
	local peak = 0
	for _, entry in ipairs(entries) do peak = math.max(peak, entry:GetSteps():GetPeakNps(player)) end
	for index, entry in ipairs(entries) do
		local segment = timeline.segments[index]
		if segment then
			local steps = entry:GetSteps()
			local points = densityOf(steps, player, steps:GetTimingData(),
				function(t) return (segment.startSecond + t) / span end, peak)
			for _, point in ipairs(points) do result[#result+1] = point end
			result[#result+1] = { segment.endSecond / span, 0 }
		end
	end
	return result
end

-- The life line: the engine's life record over the steps (from the first
-- note to the end), placed on the timeline as Simply Love's GraphDisplay is.
local LIFE_SAMPLES = 120

local function life(player, timeline)
	local stats = VOLT26.Results.GetStageStats(player)
	local span = math.max(timeline.lastSecond - timeline.firstSecond, 0.001)
	local startU, total = 0, nil
	if not GAMESTATE:IsCourseMode() then
		local song = GAMESTATE:GetCurrentSong()
		local first = song and song:GetFirstSecond() or timeline.firstSecond
		startU = math.max(0, (first - timeline.firstSecond) / span)
		total = (timeline.lastSecond - first) / VOLT26.MusicSelection.GetMusicRate()
	else
		total = span / VOLT26.MusicSelection.GetMusicRate()
	end
	local ok, record = pcall(function() return stats:GetLifeRecord(math.max(total, 0.001), LIFE_SAMPLES) end)
	local points = {}
	if not ok or type(record) ~= "table" then return points end
	local count = #record
	for i, value in ipairs(record) do
		local f = count > 1 and (i - 1) / (count - 1) or 0
		points[#points+1] = { startU + (1 - startU) * f, clamp(value, 0, 1) }
	end
	return points
end

-- Judgment offsets: u, v (v = 0.5 on time, 1 early edge, 0 late edge, as the
-- scatter plot's y runs top to bottom from early to late) and the row key
-- whose colour the point takes.  Misses span the whole height.
local function offsets(player, timeline)
	local samples = VOLT26.Analysis.GetTimingOffsets(player)
	local worst = GetTimingWindow(math.max(2, VOLT26.Analysis.GetWorstJudgment(samples)))
	local fantasticPlus = VOLT26.Gameplay.GetMode() ~= "FA+" and GetTimingWindow(1, "FA+") or nil
	local points = {}
	for _, batch in ipairs(VOLT26.Analysis.BuildScatterBatches(samples, timeline, 1, 1, worst)) do
		for _, point in ipairs(batch) do
			local key = "Miss"
			if not point.isMiss then
				local window = DetermineTimingWindow(point.offset)
				if VOLT26.Gameplay.GetMode() == "FA+" then
					key = ({ "W0", "W1", "W2", "W3", "W4" })[window] or "W5"
				elseif window == 1 then
					key = (fantasticPlus and math.abs(point.offset) > fantasticPlus) and "W1" or "W0"
				else
					key = "W" .. window
				end
			end
			points[#points+1] = { point.x, 1 - point.y, key }
		end
	end
	return points
end

function Page.GetGraph(player)
	local timeline = VOLT26.Analysis.GetTimeline(player)
	local graph = {
		density = density(player, timeline),
		life = life(player, timeline),
		offsets = offsets(player, timeline),
		segments = {},
	}
	local span = math.max(timeline.lastSecond - timeline.firstSecond, 0.001)
	for _, segment in ipairs(timeline.segments or {}) do
		graph.segments[#graph.segments+1] = { segment.startSecond / span, segment.endSecond / span }
	end
	local failure = VOLT26.Failure.GetSnapshot(player)
	if failure and (failure.total_seconds or 0) > 0 then
		graph.failedAt = clamp(failure.death_second / failure.total_seconds, 0, 1)
		graph.secondsLeft = math.max(0, failure.total_seconds - failure.death_second)
	end
	return graph
end

function Page.PageCount()
	return 1 + Page.InheritedPanes
end
