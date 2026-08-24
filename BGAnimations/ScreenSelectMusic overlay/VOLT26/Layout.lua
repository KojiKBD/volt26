-- Standalone VOLT26 SongSelect composition.

local H = {
	W = 854,
	H = 480,
	Font = "P5hatty",
	P1 = color("#ed1c24"),
	P2 = color("#1687ff"),
	Black = color("#050505"),
	White = color("#f5f5f2"),
	Muted = color("#a9a9a9"),
	Dash = "--",
	ChartCache = {},
}

H.Scale = math.min(_screen.w/H.W, _screen.h/H.H)
H.Left = _screen.cx - H.W*H.Scale/2
H.Top = _screen.cy - H.H*H.Scale/2

function H.SelectedType()
	local screen = SCREENMAN:GetTopScreen()
	local wheel = screen and screen.GetMusicWheel and screen:GetMusicWheel()
	return wheel and wheel:GetSelectedType() or nil
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

function H.Accent(player)
	return player == PLAYER_1 and H.P1 or H.P2
end

function H.PlayerName(player)
	if not GAMESTATE:IsHumanPlayer(player) then return "" end
	local profile = PROFILEMAN:GetProfile(player)
	local name = profile and profile:GetDisplayName() or ""
	if name == "" then name = ToEnumShortString(player) end
	return name
end

function H.Avatar(player)
	return GAMESTATE:IsHumanPlayer(player) and GetPlayerAvatarPath(player) or nil
end

function H.Title(item)
	if not item then return "" end
	if item.GetDisplayFullTitle then return item:GetDisplayFullTitle() end
	if item.GetDisplayMainTitle then return item:GetDisplayMainTitle() end
	return ""
end

function H.Artist(item)
	if not item then return "" end
	if item.GetDisplayArtist then return item:GetDisplayArtist() end
	if item.GetDescription then return item:GetDescription() end
	return ""
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
	if not H.Item() then return H.Dash end
	local ok, text = pcall(function()
		return StringifyDisplayBPMs(player, chart, VOLT26.MusicSelection.GetMusicRate())
	end)
	return ok and text and text ~= "" and text or H.Dash
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
	-- ITGmania exposes cached, timing-aware NPS values per measure but does not
	-- expose note timestamps cheaply to theme Lua. Plot those real samples
	-- across the chart instead of fabricating fixed-second density bins.
	local okNps, nps = pcall(function() return steps:GetNpsPerMeasure(player) end)
	if okNps and nps then
		for _, value in ipairs(nps) do
			value = tonumber(value) or 0
			data.nps[#data.nps+1] = value
			data.peak = math.max(data.peak, value)
		end
	end
	-- Adapter for engine-provided tech classifications. Only categories
	-- reported by GetTechCounts() are shown; none are inferred.
	local okTech, tech = pcall(function() return steps:GetTechCounts(player) end)
	if okTech and tech then
		local keys = {
			{"JACKS", "TechCountsCategory_Jacks"},
			{"CROSSOVERS", "TechCountsCategory_Crossovers"},
			{"FOOTSWITCHES", "TechCountsCategory_Footswitches"},
			{"SIDESWITCHES", "TechCountsCategory_Sideswitches"},
			{"BRACKETS", "TechCountsCategory_Brackets"},
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

function H.GradeText(grade)
	if not grade then return H.Dash end
	local key = ToEnumShortString(grade)
	if THEME:HasString("Grade", key) then return THEME:GetString("Grade", key) end
	return key:gsub("Tier", "T")
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

function H.Polygon(points, tint)
	local vertices = {}
	for _, point in ipairs(points) do vertices[#vertices+1] = {{point[1], point[2], 0}, tint} end
	return Def.ActorMultiVertex{
		InitCommand=function(self)
			self:SetDrawState({Mode="DrawMode_Fan"}):SetVertices(vertices)
		end,
	}
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
			wheel:xy(H.Left + 15*H.Scale, H.Top + 242*H.Scale):rotationz(-1.5)
		end
		self._refreshElapsed = 0
		self._refreshKey = ""
		self:SetUpdateFunction(function(frame, delta)
			frame._refreshElapsed = frame._refreshElapsed + delta
			if frame._refreshElapsed < 0.10 then return end
			frame._refreshElapsed = 0
			local key = table.concat({
				tostring(H.SelectedType()), tostring(H.Item()),
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
}

local componentPath = function(file)
	return THEME:GetPathB("ScreenSelectMusic", "overlay/VOLT26/"..file)
end

af[#af+1] = LoadActor(componentPath("Frame.lua"), H)
af[#af+1] = LoadActor(componentPath("Banner.lua"), H)
af[#af+1] = LoadActor(componentPath("PlayerChart.lua"), {H=H, Player=PLAYER_1, Y=164})
af[#af+1] = LoadActor(componentPath("PlayerChart.lua"), {H=H, Player=PLAYER_2, Y=266})
af[#af+1] = LoadActor(componentPath("Leaderboard.lua"), H)
af[#af+1] = LoadActor(componentPath("PlayerCard.lua"), {H=H, Player=PLAYER_1, Y=390})
af[#af+1] = LoadActor(componentPath("PlayerCard.lua"), {H=H, Player=PLAYER_2, Y=430})
af[#af+1] = LoadActor(componentPath("Controls.lua"), H)

return af
