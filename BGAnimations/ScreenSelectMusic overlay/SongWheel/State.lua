-- Read-only views of the engine state the Song Select panels show.  Every
-- reader is defensive: the panels refresh while the wheel is still settling,
-- and some engine objects (a course Trail, a section row) do not answer every
-- question a song does.
local K = ...

local S = {}

function S.IsCourseMode()
	return GAMESTATE:IsCourseMode()
end

-- The song or course under the wheel's highlight, or nil on a section row.
function S.Item()
	local wheel = K.Wheel()
	local selected = wheel and wheel:GetSelectedType() or nil
	if S.IsCourseMode() then
		return selected == "WheelItemDataType_Course" and GAMESTATE:GetCurrentCourse() or nil
	end
	return selected == "WheelItemDataType_Song" and GAMESTATE:GetCurrentSong() or nil
end

function S.Chart(player)
	if S.IsCourseMode() then return GAMESTATE:GetCurrentTrail(player) end
	return GAMESTATE:GetCurrentSteps(player)
end

function S.Rate()
	return VOLT26.MusicSelection.GetMusicRate()
end

-- The pack the wheel is showing.
function S.Pack()
	local song = not S.IsCourseMode() and GAMESTATE:GetCurrentSong() or nil
	if song then
		local ok, group = pcall(function() return song:GetGroupName() end)
		if ok and type(group) == "string" and group ~= "" then return group end
	end
	local wheel = K.Wheel()
	local ok, section = pcall(function() return wheel and wheel:GetSelectedSection() or nil end)
	return ok and section or ""
end

-- 1-based position of the highlight in the wheel and the number of rows; with
-- the song wheel showing one pack, that is the song's place in the pack.
function S.Position()
	local wheel = K.Wheel()
	if not wheel then return nil end
	local ok, index, total = pcall(function() return wheel:GetCurrentIndex(), wheel:GetNumItems() end)
	if not ok or not tonumber(index) or not tonumber(total) or total <= 0 then return nil end
	return index + 1, total
end

function S.BPMText(item)
	if not item then return K.Dash end
	local ok, random = pcall(function() return item.IsDisplayBpmRandom and item:IsDisplayBpmRandom() end)
	if ok and random then return "???" end
	local okBpms, bpms = pcall(function() return item:GetDisplayBpms() end)
	if not okBpms or type(bpms) ~= "table" or not tonumber(bpms[1]) or not tonumber(bpms[2]) then
		return K.Dash
	end
	local rate = S.Rate()
	local low = math.floor(bpms[1] * rate + 0.5)
	local high = math.floor(bpms[2] * rate + 0.5)
	if low <= 0 and high <= 0 then return K.Dash end
	if low == high then return tostring(low) end
	return string.format("%d - %d", low, high)
end

function S.LengthText(item)
	if not item then return K.Dash end
	local seconds
	if S.IsCourseMode() then
		local trail = S.Chart(GAMESTATE:GetMasterPlayerNumber())
		local ok, value = pcall(function() return trail and trail:GetLengthSeconds() or nil end)
		seconds = ok and value or nil
	else
		local ok, value = pcall(function() return item:MusicLengthSeconds() end)
		seconds = ok and value or nil
	end
	seconds = tonumber(seconds)
	if not seconds then return K.Dash end
	return K.Clock(seconds / S.Rate())
end

local function chartSort(a, b)
	local oa, ob = K.DifficultyOrder(a:GetDifficulty()), K.DifficultyOrder(b:GetDifficulty())
	if oa ~= ob then return oa < ob end
	return (tonumber(a:GetMeter()) or 0) < (tonumber(b:GetMeter()) or 0)
end

-- The charts the players can choose for the current item, easiest first.
function S.Charts(item)
	local charts = {}
	if not item then return charts end
	local style = GAMESTATE:GetCurrentStyle()
	local stepsType = style and style:GetStepsType() or nil

	if S.IsCourseMode() then
		local ok, trails = pcall(function() return item:GetAllTrails() end)
		if ok and type(trails) == "table" then
			for _, trail in ipairs(trails) do
				local okType, trailType = pcall(function() return trail:GetStepsType() end)
				if not stepsType or not okType or trailType == stepsType then charts[#charts+1] = trail end
			end
		end
	else
		local ok, steps = pcall(function()
			if SongUtil and SongUtil.GetPlayableSteps then return SongUtil.GetPlayableSteps(item) end
			return nil
		end)
		if not ok or type(steps) ~= "table" then
			ok, steps = pcall(function() return item:GetStepsByStepsType(stepsType) end)
		end
		if ok and type(steps) == "table" then
			for _, chart in ipairs(steps) do charts[#charts+1] = chart end
		end
	end

	local okSort = pcall(function() table.sort(charts, chartSort) end)
	if not okSort then return charts end
	return charts
end

function S.Radar(chart, player, category)
	if not chart then return nil end
	local ok, value = pcall(function() return chart:GetRadarValues(player):GetValue(category) end)
	if not ok or not tonumber(value) or value < 0 then return nil end
	return math.floor(value + 0.5)
end

local function topPercent(profile, item, chart)
	if not profile or not item or not chart then return nil end
	local ok, value = pcall(function()
		local list = profile:GetHighScoreList(item, chart)
		local scores = list and list:GetHighScores() or nil
		local best = scores and scores[1] or nil
		return best and best:GetPercentDP() or nil
	end)
	return ok and tonumber(value) or nil
end

local function percentText(value)
	if not value then return K.Dash end
	return string.format("%.2f%%", value * 100)
end

function S.PersonalBest(player, item, chart)
	if not PROFILEMAN:IsPersistentProfile(player) then return K.Dash end
	return percentText(topPercent(PROFILEMAN:GetProfile(player), item, chart))
end

function S.MachineBest(item, chart)
	return percentText(topPercent(PROFILEMAN:GetMachineProfile(), item, chart))
end

function S.PlayerName(player)
	local ok, name = pcall(function() return PROFILEMAN:GetPlayerName(player) end)
	if ok and type(name) == "string" and name ~= "" then return name end
	return ToEnumShortString(player)
end

-- Chart readings for the info panel: the NPS of every measure (the density
-- graph), the tech counts and the notes radar built from them, and how much of
-- the chart is stream.  A course reads every chart of its trail as one.
-- Cached per player until that player's chart changes.
local techCategories = {
	{ "Crossovers",   "TechCountsCategory_Crossovers" },
	{ "Footswitches", "TechCountsCategory_Footswitches" },
	{ "Sideswitches", "TechCountsCategory_Sideswitches" },
	{ "Brackets",     "TechCountsCategory_Brackets" },
	{ "Jacks",        "TechCountsCategory_Jacks" },
}

local function appendChartData(data, steps, player)
	if not steps then return end
	local okNps, nps = pcall(function() return steps:GetNpsPerMeasure(player) end)
	if okNps and type(nps) == "table" then
		for _, value in ipairs(nps) do
			value = tonumber(value) or 0
			data.nps[#data.nps+1] = value
			data.peak = math.max(data.peak, value)
		end
	end
	local okTech, tech = pcall(function() return steps:GetTechCounts(player) end)
	if okTech and tech then
		data.techAvailable = true
		for _, pair in ipairs(techCategories) do
			local value = tonumber(tech:GetValue(pair[2])) or 0
			if value > 0 then
				data.techCounts[pair[1]] = (data.techCounts[pair[1]] or 0) + math.floor(value + 0.5)
			end
		end
	end
end

-- The chart's fastest BPM, the reference for what counts as a stream measure.
local function chartBpm(chart, item)
	local ok, bpm = pcall(function()
		local timing = chart.GetTimingData and chart:GetTimingData() or nil
		if not timing or not timing.GetActualBPM then return nil end
		local _, fastest = timing:GetActualBPM()
		return fastest
	end)
	if ok and tonumber(bpm) and bpm > 0 then return bpm end
	local okDisplay, bpms = pcall(function() return item and item:GetDisplayBpms() or nil end)
	if okDisplay and type(bpms) == "table" and tonumber(bpms[2]) and bpms[2] > 0 then return bpms[2] end
	return nil
end

local chartCache = {}

function S.ChartData(player)
	local chart = S.Chart(player)
	local cached = chartCache[player]
	if cached and cached.chart == chart then return cached.data end
	local data = { chart=chart, nps={}, peak=0, techCounts={}, techAvailable=false,
		notes=0, stream=0, streamMeasures=0 }
	if chart then
		if S.IsCourseMode() and chart.GetTrailEntries then
			for _, entry in ipairs(chart:GetTrailEntries()) do appendChartData(data, entry:GetSteps(), player) end
		else
			appendChartData(data, chart, player)
		end
		data.notes = S.Radar(chart, player, "RadarCategory_TapsAndHolds") or 0
		local bpm = chartBpm(chart, S.Item())
		data.stream = VOLT26.ChartRadar.ComputeStream(data.nps, bpm)
		-- Every stream measure lies inside the span ComputeStream measures, so
		-- the count is simply the measures that reach the stream speed.
		if bpm and bpm > 0 then
			local threshold = bpm / 15 * 0.97
			for _, value in ipairs(data.nps) do
				if value >= threshold then data.streamMeasures = data.streamMeasures + 1 end
			end
		end
		data.radar = VOLT26.ChartRadar.Build{
			TechCounts = data.techCounts,
			Stream = data.stream,
			TotalNotes = data.notes,
		}
	end
	chartCache[player] = { chart=chart, data=data }
	return data
end

-- The chart's credit: its author, else its description.
function S.StepArtist(chart)
	if not chart then return "" end
	for _, getter in ipairs({ "GetAuthorCredit", "GetDescription", "GetChartName" }) do
		local ok, value = pcall(function() return chart[getter] and chart[getter](chart) or nil end)
		if ok and type(value) == "string" and value ~= "" then return value end
	end
	return ""
end

-- The player's best on a chart: PercentDP (ITG), ExPercent and Grade, or nil.
function S.Best(player, item, chart)
	if not item or not chart or not VOLT26.ScoreIndex then return nil end
	local ok, best = pcall(function() return VOLT26.ScoreIndex.GetBest(player, item, chart) end)
	return ok and best or nil
end

return S
