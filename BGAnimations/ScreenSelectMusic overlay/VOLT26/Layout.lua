-- VOLT26 Song Select composition.

local H = {
	W = 854,
	H = 480,
	Font = "Helvetica Normal",
	FontBold = "Helvetica Bold",
	FontZoom = 116 / 28,
	FontBoldZoom = 116 / 29,
	P1 = color("#d9666b"),
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
		local keys = {
			{"FS", "TechCountsCategory_Footswitches"},
			{"XO", "TechCountsCategory_Crossovers"},
			{"SW", "TechCountsCategory_Sideswitches"},
			{"BR", "TechCountsCategory_Brackets"},
			{"JA", "TechCountsCategory_Jacks"},
		}
		for _, pair in ipairs(keys) do
			local value = tech:GetValue(pair[2]) or 0
			if value > 0 then data.tech[#data.tech+1] = pair[1].." "..math.floor(value+0.5) end
		end
	end
end

function H.ChartData(player)
	local chart = H.Chart(player)
	local cached = H.ChartCache[player]
	if cached and cached.chart == chart then return cached.data end
	local data = {chart=chart, nps={}, peak=0, tech={}}
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
af[#af+1] = LoadActor(componentPath("PreviewBackdrop.lua"), H)
af[#af+1] = LoadActor(componentPath("SongInfo.lua"), H)
af[#af+1] = LoadActor(componentPath("ChartPreview.lua"), H)
af[#af+1] = LoadActor(componentPath("GroupPreview.lua"), H)
af[#af+1] = LoadActor(componentPath("DifficultyStrip.lua"), H)
af[#af+1] = LoadActor(componentPath("PlayerChart.lua"), {H=H, Player=PLAYER_1})
af[#af+1] = LoadActor(componentPath("PlayerChart.lua"), {H=H, Player=PLAYER_2})
af[#af+1] = LoadActor(componentPath("PlayerName.lua"), {H=H, Player=PLAYER_1})
af[#af+1] = LoadActor(componentPath("PlayerName.lua"), {H=H, Player=PLAYER_2})

return af
