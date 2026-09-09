-- VOLT26 Song Select composition.

local H = {
	W = 854,
	H = 480,
	Font = "Helvetica Normal",
	FontBold = "Helvetica Bold",
	FontZoom = 116 / 28,
	FontBoldZoom = 116 / 29,
	P1 = color("#ff0000"),
	P2 = color("#6f9fb5"),
	Black = color("#f6eeee"),
	White = color("#ffffff"),
	Muted = color("#bdaeb0"),
	Line = color("#8c5d61"),
	Surface = color("#181818"),
	SurfaceAlpha = 0.88,
	Dash = "--",
	ChartCache = {},
	LastStepsPlayer = PLAYER_1,
}

function H.NormalZoom(value) return value * H.FontZoom end
function H.BoldZoom(value) return value * H.FontBoldZoom end

H.Scale = math.min(_screen.w/H.W, _screen.h/H.H)
H.Left = _screen.cx - H.W*H.Scale/2
H.Top = _screen.cy - H.H*H.Scale/2

function H.SelectedType()
	local screen = SCREENMAN:GetTopScreen()
	local wheel = screen and screen.GetMusicWheel and screen:GetMusicWheel()
	return wheel and wheel:GetSelectedType() or nil
end

function H.SelectedSection()
	local screen = SCREENMAN:GetTopScreen()
	local wheel = screen and screen.GetMusicWheel and screen:GetMusicWheel()
	return wheel and wheel:GetSelectedSection() or nil
end

function H.Item()
	local selected = H.SelectedType()
	if GAMESTATE:IsCourseMode() then
		return selected == "WheelItemDataType_Course" and GAMESTATE:GetCurrentCourse() or nil
	end
	return selected == "WheelItemDataType_Song" and GAMESTATE:GetCurrentSong() or nil
end

function H.Chart(player)
	if GAMESTATE:IsCourseMode() then return GAMESTATE:GetCurrentTrail(player) end
	return GAMESTATE:GetCurrentSteps(player)
end

function H.Accent(player) return player == PLAYER_1 and H.P1 or H.P2 end

function H.PlayerName(player)
	if not GAMESTATE:IsHumanPlayer(player) then return "" end
	local profile = PROFILEMAN:GetProfile(player)
	local name = profile and profile:GetDisplayName() or ""
	return name ~= "" and name or ToEnumShortString(player)
end

function H.Title(item)
	if not item then return "" end
	if item.GetDisplayFullTitle then return item:GetDisplayFullTitle() end
	if item.GetDisplayMainTitle then return item:GetDisplayMainTitle() end
	return ""
end

function H.Artist(item)
	return item and item.GetDisplayArtist and item:GetDisplayArtist() or ""
end

function H.Length()
	local item = H.Item()
	if not item then return H.Dash end
	local seconds
	if GAMESTATE:IsCourseMode() then
		local master = GAMESTATE:GetMasterPlayerNumber()
		seconds = master and TotalCourseLength(master) or nil
	elseif item.MusicLengthSeconds then
		seconds = item:MusicLengthSeconds() / VOLT26.MusicSelection.GetMusicRate()
	end
	return seconds and SecondsToMSS(seconds) or H.Dash
end

function H.BPM(player, chart)
	if not chart then return H.Dash end
	local ok, value = pcall(function()
		return StringifyDisplayBPMs(player, chart, VOLT26.MusicSelection.GetMusicRate())
	end)
	return ok and value and value ~= "" and value or H.Dash
end

function H.Radar(chart, player, category)
	if not chart or not chart.GetRadarValues then return 0 end
	local ok, value = pcall(function()
		return chart:GetRadarValues(player):GetValue(category)
	end)
	return ok and value and value >= 0 and math.floor(value + 0.5) or 0
end

-- Reference BPM for stream detection.  The chart's own timing data is the
-- authority; the song's display BPM is the fallback for anything that does not
-- expose timing data, such as a course Trail.
local function chartBpm(chart)
	local okTiming, bpm = pcall(function()
		local timing = chart.GetTimingData and chart:GetTimingData() or nil
		if not timing or not timing.GetActualBPM then return nil end
		local _, fastest = timing:GetActualBPM()
		return fastest
	end)
	if okTiming and tonumber(bpm) and bpm > 0 then return bpm end

	local item = H.Item()
	local okDisplay, bpms = pcall(function()
		return item and item.GetDisplayBpms and item:GetDisplayBpms() or nil
	end)
	if okDisplay and type(bpms) == "table" and tonumber(bpms[2]) and bpms[2] > 0 then return bpms[2] end
	return nil
end

-- Keys match VOLT26.ChartRadar's axis keys so the counts can be handed straight
-- to it without a second translation table.
local techCategories = {
	{"Crossovers",   "TechCountsCategory_Crossovers"},
	{"Footswitches", "TechCountsCategory_Footswitches"},
	{"Sideswitches", "TechCountsCategory_Sideswitches"},
	{"Brackets",     "TechCountsCategory_Brackets"},
	{"Jacks",        "TechCountsCategory_Jacks"},
}

local function appendChartData(data, steps, player)
	if not steps then return end
	local okNps, nps = pcall(function() return steps:GetNpsPerMeasure(player) end)
	if okNps and nps then
		for _, value in ipairs(nps) do
			value = tonumber(value) or 0
			data.nps[#data.nps+1] = value
			data.peak = math.max(data.peak, value)
		end
	end
	local okTech, tech = pcall(function() return steps:GetTechCounts(player) end)
	if okTech and tech then
		-- A chart with no tech at all still counts as "available": the radar
		-- should draw an empty hexagon rather than disappear.  Only an engine
		-- that cannot answer at all leaves this false.
		data.techAvailable = true
		for _, pair in ipairs(techCategories) do
			local value = tonumber(tech:GetValue(pair[2])) or 0
			if value > 0 then
				data.techCounts[pair[1]] = (data.techCounts[pair[1]] or 0) + math.floor(value+0.5)
			end
		end
	end
end

function H.ChartData(player)
	local chart = H.Chart(player)
	local cached = H.ChartCache[player]
	if cached and cached.chart == chart then return cached.data end
	local data = {chart=chart, nps={}, peak=0, techCounts={}, techAvailable=false}
	if chart then
		if GAMESTATE:IsCourseMode() and chart.GetTrailEntries then
			for entry in ivalues(chart:GetTrailEntries()) do appendChartData(data, entry:GetSteps(), player) end
		else
			appendChartData(data, chart, player)
		end

		data.notes = H.Radar(chart, player, "RadarCategory_TapsAndHolds")
		data.jumps = H.Radar(chart, player, "RadarCategory_Jumps")
		data.holds = H.Radar(chart, player, "RadarCategory_Holds")
		data.mines = H.Radar(chart, player, "RadarCategory_Mines")
		data.rolls = H.Radar(chart, player, "RadarCategory_Rolls")
		data.hands = H.Radar(chart, player, "RadarCategory_Hands")

		-- Built last: the tech axes are measured against the chart's own note
		-- count, so the radar cannot be assembled before that count is known.
		data.stream = VOLT26.ChartRadar.ComputeStream(data.nps, chartBpm(chart))
		data.radar = VOLT26.ChartRadar.Build{
			TechCounts = data.techCounts,
			Stream = data.stream,
			TotalNotes = data.notes,
		}
	end
	H.ChartCache[player] = {chart=chart, data=data}
	return data
end

function H.PreviewSource()
	local humans = GAMESTATE:GetHumanPlayers()
	if #humans == 0 then return PLAYER_1, nil end
	if #humans == 1 then return humans[1], H.Chart(humans[1]) end
	local p1Chart, p2Chart = H.Chart(PLAYER_1), H.Chart(PLAYER_2)
	if not p1Chart then return PLAYER_2, p2Chart end
	if not p2Chart then return PLAYER_1, p1Chart end
	local p1Meter = tonumber(p1Chart:GetMeter()) or 0
	local p2Meter = tonumber(p2Chart:GetMeter()) or 0
	if p1Meter > p2Meter then return PLAYER_1, p1Chart end
	if p2Meter > p1Meter then return PLAYER_2, p2Chart end
	local player = H.LastStepsPlayer or PLAYER_1
	return player, H.Chart(player)
end

function H.AddRefresh(actor)
	actor.OnCommand=function(self) self:queuecommand("Refresh") end
	actor.CurrentSongChangedMessageCommand=function(self) H.ChartCache={}; self:queuecommand("Refresh") end
	actor.CurrentCourseChangedMessageCommand=function(self) H.ChartCache={}; self:queuecommand("Refresh") end
	actor.CurrentStepsP1ChangedMessageCommand=function(self) H.ChartCache[PLAYER_1]=nil; self:queuecommand("Refresh") end
	actor.CurrentStepsP2ChangedMessageCommand=function(self) H.ChartCache[PLAYER_2]=nil; self:queuecommand("Refresh") end
	actor.CurrentTrailP1ChangedMessageCommand=function(self) H.ChartCache[PLAYER_1]=nil; self:queuecommand("Refresh") end
	actor.CurrentTrailP2ChangedMessageCommand=function(self) H.ChartCache[PLAYER_2]=nil; self:queuecommand("Refresh") end
	actor.PlayerJoinedMessageCommand=function(self) self:queuecommand("Refresh") end
	actor.PlayerUnjoinedMessageCommand=function(self) self:queuecommand("Refresh") end
	actor.PlayerProfileSetMessageCommand=function(self) self:queuecommand("Refresh") end
	actor.VOLT26SongSelectRefreshMessageCommand=function(self) self:queuecommand("Refresh") end
	return actor
end

function H.AddSettledRefresh(actor, delay, offsetX, offsetY)
	delay = delay or 0.35
	offsetX = offsetX or 0
	offsetY = offsetY or 0
	local priorInit = actor.InitCommand
	local function schedule(self)
		self:stoptweening():linear(0.08):diffusealpha(0)
			:sleep(math.max(0,delay-0.08)):queuecommand("SettledRefresh")
	end
	actor.InitCommand=function(self)
		if priorInit then priorInit(self) end
		self._settledX = self:GetX()
		self._settledY = self:GetY()
		self:diffusealpha(0)
	end
	actor.OnCommand=schedule
	actor.SettledRefreshCommand=function(self)
		self:stoptweening():xy(self._settledX or self:GetX(), self._settledY or self:GetY())
		self:playcommand("Refresh")
		self._settledX = self:GetX()
		self._settledY = self:GetY()
		self:xy(self._settledX+offsetX, self._settledY+offsetY):diffusealpha(0)
			:decelerate(0.20):xy(self._settledX,self._settledY):diffusealpha(1)
	end
	actor.CurrentSongChangedMessageCommand=function(self) H.ChartCache={}; schedule(self) end
	actor.CurrentCourseChangedMessageCommand=function(self) H.ChartCache={}; schedule(self) end
	actor.CurrentStepsP1ChangedMessageCommand=function(self) H.ChartCache[PLAYER_1]=nil; schedule(self) end
	actor.CurrentStepsP2ChangedMessageCommand=function(self) H.ChartCache[PLAYER_2]=nil; schedule(self) end
	actor.CurrentTrailP1ChangedMessageCommand=function(self) H.ChartCache[PLAYER_1]=nil; schedule(self) end
	actor.CurrentTrailP2ChangedMessageCommand=function(self) H.ChartCache[PLAYER_2]=nil; schedule(self) end
	actor.PlayerJoinedMessageCommand=schedule
	actor.PlayerUnjoinedMessageCommand=schedule
	actor.PlayerProfileSetMessageCommand=schedule
	actor.VOLT26SongSelectRefreshMessageCommand=schedule
	return actor
end

local af = Def.ActorFrame{
	Name="VOLT26SongSelect",
	InitCommand=function(self) self:xy(H.Left, H.Top):zoom(H.Scale) end,
	OnCommand=function(self)
		local screen = SCREENMAN:GetTopScreen()
		local wheel = screen and screen.GetMusicWheel and screen:GetMusicWheel()
		if wheel then
			if not GAMESTATE:IsCourseMode() and GAMESTATE:GetSortOrder() ~= "SortOrder_Group" then
				wheel:ChangeSort("SortOrder_Group")
			end
			wheel:xy(H.Left + 32*H.Scale, H.Top + 240*H.Scale)
		end
		self._refreshElapsed = 0
		self._refreshKey = ""
		self:SetUpdateFunction(function(frame, delta)
			frame._refreshElapsed = frame._refreshElapsed + delta
			if frame._refreshElapsed < 0.10 then return end
			frame._refreshElapsed = 0
			local key = table.concat({
				tostring(H.SelectedType()), tostring(H.SelectedSection()), tostring(H.Item()),
				tostring(H.Chart(PLAYER_1)), tostring(H.Chart(PLAYER_2)),
				tostring(#GAMESTATE:GetHumanPlayers())
			}, "|")
			if key ~= frame._refreshKey then
				frame._refreshKey = key
				H.ChartCache = {}
				MESSAGEMAN:Broadcast("VOLT26SongSelectRefresh")
			end
		end)
	end,
	CurrentStepsP1ChangedMessageCommand=function(self) H.LastStepsPlayer=PLAYER_1 end,
	CurrentStepsP2ChangedMessageCommand=function(self) H.LastStepsPlayer=PLAYER_2 end,
}

local function componentPath(file)
	return THEME:GetPathB("ScreenSelectMusic", "overlay/VOLT26/"..file)
end

af[#af+1] = LoadActor(componentPath("Frame.lua"), H)
af[#af+1] = LoadActor(componentPath("FocusedBanner.lua"), H)
af[#af+1] = LoadActor(componentPath("SongInfo.lua"), H)
local chartPreviewLayer = Def.ActorFrame{
	Name="ChartPreviewLayer",
	InitCommand=function(self) self:diffusealpha(0.001) end,
	-- Modal overlays (sort menu, song search, leaderboard, input test) own the
	-- screen while they are open. The preview notefield is drawn after them, so
	-- stop drawing it entirely instead of relying on draw order.
	VOLT26ModalOverlayOpenedMessageCommand=function(self) self:visible(false) end,
	VOLT26ModalOverlayClosedMessageCommand=function(self) self:visible(true) end,
}
chartPreviewLayer[#chartPreviewLayer+1] = LoadActor(componentPath("PreviewBackdrop.lua"), H)
chartPreviewLayer[#chartPreviewLayer+1] = LoadActor(componentPath("ChartPreview.lua"), H)
af[#af+1] = chartPreviewLayer
af[#af+1] = LoadActor(componentPath("GroupPreview.lua"), H)
af[#af+1] = LoadActor(componentPath("DifficultyStrip.lua"), H)
af[#af+1] = LoadActor(componentPath("PlayerChart.lua"), {H=H, Player=PLAYER_1})
af[#af+1] = LoadActor(componentPath("PlayerChart.lua"), {H=H, Player=PLAYER_2})
af[#af+1] = LoadActor(componentPath("PlayerName.lua"), {H=H, Player=PLAYER_1})
af[#af+1] = LoadActor(componentPath("PlayerName.lua"), {H=H, Player=PLAYER_2})

-- Use Song Select idle time to prepare the small shared gameplay/evaluation
-- textures before the player confirms a chart.
af[#af+1] = VOLT26.Warmup.CreateActor("Play", {Interval=0.12})

return af
