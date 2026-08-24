-- Legacy prototype retained for reference; the production layout is componentized
-- in Layout.lua and its sibling actors below.
--[=[
-- Persona-inspired song/course selection presentation used only by VOLT26.
-- All coordinates are authored against Simply Love's 854x480 widescreen canvas.

local scale = math.min(_screen.w/854, _screen.h/480)
local left = _screen.cx - 427*scale
local top = _screen.cy - 240*scale
local font = "P5hatty"
local fontScale = 0.14
local dash = "—"
local maxDifficultySlots = 10

local function renderMarquee(frame)
	local actor = frame:GetChild("Text")
	if not actor then return end
	local full = frame._volt26Text or ""
	local length = frame._volt26Length or 0
	local window = frame._volt26Window or 24
	if length <= window then
		actor:settext(full)
	else
		local loop = full .. "   " .. full
		local first = frame._volt26Position or 1
		actor:settext(loop:utf8sub(first, first+window-1))
	end
end

local function setMarquee(self, text)
	text = text or ""
	self._volt26Text = text
	self._volt26Length = text:utf8len()
	self._volt26Position = 1
	self._volt26Elapsed = 0
	renderMarquee(self)
end

local function selectedType()
	local screen = SCREENMAN:GetTopScreen()
	local wheel = screen and screen.GetMusicWheel and screen:GetMusicWheel()
	return wheel and wheel:GetSelectedType() or nil
end

local function getItem()
	local kind = selectedType()
	if GAMESTATE:IsCourseMode() then
		return kind == "WheelItemDataType_Course" and GAMESTATE:GetCurrentCourse() or nil
	end
	return kind == "WheelItemDataType_Song" and GAMESTATE:GetCurrentSong() or nil
end

local function getChart(player)
	return GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player) or GAMESTATE:GetCurrentSteps(player)
end

local function getTitle(item)
	if not item then return "" end
	if item.GetDisplayFullTitle then return item:GetDisplayFullTitle() end
	if item.GetDisplayMainTitle then return item:GetDisplayMainTitle() end
	return ""
end

local function getGroupText()
	local screen = SCREENMAN:GetTopScreen()
	local wheel = screen and screen.GetMusicWheel and screen:GetMusicWheel()
	if selectedType() == "WheelItemDataType_Section" then
		return wheel and wheel:GetSelectedSection() or ""
	end
	local song = GAMESTATE:GetCurrentSong()
	if song and song.GetGroupName then return song:GetGroupName() end
	return wheel and wheel:GetSelectedSection() or ""
end

local function getBannerPath()
	local item = getItem()
	if item and item.HasBanner and item:HasBanner() then return item:GetBannerPath() end

	-- Sections are not songs, so GAMESTATE:GetCurrentSong() is intentionally
	-- ignored here.  Resolve the selected pack's own banner from SongManager.
	if selectedType() == "WheelItemDataType_Section" then
		local group = getGroupText()
		if group ~= "" and SONGMAN.GetSongGroupBannerPath then
			local path = SONGMAN:GetSongGroupBannerPath(group)
			if path and path ~= "" then return path end
		end
	end
	return nil
end

local function getCharts()
	local item = getItem()
	if not item then return {} end
	local charts = {}
	if GAMESTATE:IsCourseMode() then
		if item.GetAllTrails then
			for trail in ivalues(item:GetAllTrails()) do charts[#charts+1] = trail end
		end
	else
		for steps in ivalues(SongUtil.GetPlayableSteps(item) or {}) do charts[#charts+1] = steps end
	end
	table.sort(charts, function(a,b)
		local ad = Difficulty:Reverse()[a:GetDifficulty()] or 99
		local bd = Difficulty:Reverse()[b:GetDifficulty()] or 99
		if ad == bd then return a:GetMeter() < b:GetMeter() end
		return ad < bd
	end)
	return charts
end

local function windowCharts(charts)
	if #charts <= maxDifficultySlots then return charts end
	local selected = {}
	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		for i, chart in ipairs(charts) do
			if chart == getChart(player) then selected[#selected+1] = i end
		end
	end
	local center = selected[1] or 1
	local first = math.max(1, math.min(#charts-maxDifficultySlots+1, center-math.floor(maxDifficultySlots/2)))
	if selected[2] then
		first = math.min(first, selected[2])
		first = math.max(first, selected[2]-maxDifficultySlots+1)
		first = math.max(1, math.min(#charts-maxDifficultySlots+1, first))
	end
	local result = {}
	for i=first, first+maxDifficultySlots-1 do result[#result+1] = charts[i] end
	-- Extremely edit-heavy packs can put the two selections more than ten
	-- places apart. Preserve both selections by reserving the last slot.
	if selected[2] and math.abs(selected[2]-(selected[1] or selected[2])) >= maxDifficultySlots then
		result[maxDifficultySlots] = charts[selected[2]]
	end
	return result
end

local radarKeys = {
	{"T", "RadarCategory_TapsAndHolds"}, {"J", "RadarCategory_Jumps"},
	{"H", "RadarCategory_Holds"}, {"M", "RadarCategory_Mines"},
	{"R", "RadarCategory_Rolls"}, {"A", "RadarCategory_Hands"},
}

local function safeRadar(chart, player, key)
	if not chart or not chart.GetRadarValues then return dash end
	local rv = chart:GetRadarValues(player)
	if not rv then return dash end
	local value = rv:GetValue(key)
	return value and value >= 0 and tostring(math.floor(value+0.5)) or dash
end

local function appendChartData(data, steps, player)
	if not steps then return end
	local nps = steps:GetNpsPerMeasure(player) or {}
	for _, value in ipairs(nps) do
		data.nps[#data.nps+1] = value
		data.peak = math.max(data.peak, value)
	end
	local notes = steps:GetNotesPerMeasure(player) or {}
	for _, value in ipairs(notes) do
		data.measures = data.measures + 1
		if value >= 16 then data.stream = data.stream + 1 end
	end
	local tech = steps:GetTechCounts(player)
	if tech then
		data.xo = data.xo + (tech:GetValue("TechCountsCategory_Crossovers") or 0)
		data.fs = data.fs + (tech:GetValue("TechCountsCategory_Footswitches") or 0)
		data.ss = data.ss + (tech:GetValue("TechCountsCategory_Sideswitches") or 0)
		data.jk = data.jk + (tech:GetValue("TechCountsCategory_Jacks") or 0)
		data.br = data.br + (tech:GetValue("TechCountsCategory_Brackets") or 0)
	end
end

local function playerData(player)
	local chart = getChart(player)
	local data = { chart=chart, nps={}, peak=0, stream=0, measures=0, xo=0, fs=0, ss=0, jk=0, br=0 }
	if not chart then return data end
	if GAMESTATE:IsCourseMode() and chart.GetTrailEntries then
		for entry in ivalues(chart:GetTrailEntries()) do appendChartData(data, entry:GetSteps(), player) end
	else
		appendChartData(data, chart, player)
		ParseChartInfo(chart, ToEnumShortString(player))
	end
	return data
end

local function chartCredit(chart)
	if not chart then return dash end
	if chart.GetAuthorCredit and chart:GetAuthorCredit() ~= "" then return chart:GetAuthorCredit() end
	if chart.GetChartName and chart:GetChartName() ~= "" then return chart:GetChartName() end
	if chart.GetDescription and chart:GetDescription() ~= "" then return chart:GetDescription() end
	return dash
end

local function shortText(text, limit)
	text = text or dash
	if text:utf8len() <= limit then return text end
	return text:utf8sub(1, limit-3) .. "..."
end

local function addRefreshCommands(actor)
	actor.OnCommand=function(self) self:queuecommand("Refresh") end
	actor.CurrentSongChangedMessageCommand=function(self) self:queuecommand("Refresh") end
	actor.CurrentCourseChangedMessageCommand=function(self) self:queuecommand("Refresh") end
	actor.CurrentStepsP1ChangedMessageCommand=function(self) self:queuecommand("Refresh") end
	actor.CurrentStepsP2ChangedMessageCommand=function(self) self:queuecommand("Refresh") end
	actor.CurrentTrailP1ChangedMessageCommand=function(self) self:queuecommand("Refresh") end
	actor.CurrentTrailP2ChangedMessageCommand=function(self) self:queuecommand("Refresh") end
	actor.PlayerJoinedMessageCommand=function(self) self:queuecommand("Refresh") end
	actor.PlayerUnjoinedMessageCommand=function(self) self:queuecommand("Refresh") end
	actor.DisplayLanguageChangedMessageCommand=function(self) self:queuecommand("Refresh") end
	actor.ChartParsedMessageCommand=function(self) self:queuecommand("Refresh") end
	return actor
end

local af = Def.ActorFrame{
	Name="VOLT26Layout",
	InitCommand=function(self) self:xy(left, top):zoom(scale) end,
	OnCommand=function(self)
		-- Rotate and place the real MusicWheel as one unit.  The stock item
		-- transform remains untouched, so engine scrolling stays reliable.
		local screen = SCREENMAN:GetTopScreen()
		local wheel = screen and screen.GetMusicWheel and screen:GetMusicWheel()
		if wheel then
			-- VOLT26 presents packs directly.  The user's global/default sort is
			-- left untouched; only this screen changes away from Series nesting.
			if not GAMESTATE:IsCourseMode() and GAMESTATE:GetSortOrder() ~= "SortOrder_Group" then
				wheel:ChangeSort("SortOrder_Group")
			end
			wheel:xy(left + 24*scale, top + 220*scale):rotationz(-6)
		end

		self._volt26_refresh_elapsed = 0
		self._volt26_refresh_key = ""
		self:SetUpdateFunction(function(frame, delta)
			frame._volt26_refresh_elapsed = frame._volt26_refresh_elapsed + delta
			if frame._volt26_refresh_elapsed < 0.08 then return end
			frame._volt26_refresh_elapsed = 0
			local key = table.concat({
				tostring(selectedType()), tostring(getItem()), tostring(getGroupText()),
				tostring(getChart(PLAYER_1)), tostring(getChart(PLAYER_2)),
				tostring(#GAMESTATE:GetHumanPlayers())
			}, "|")
			if key ~= frame._volt26_refresh_key then
				frame._volt26_refresh_key = key
				frame:playcommand("Refresh")
			end
		end)
		self:playcommand("Refresh")
	end,
}

-- The stock density graph normally owns chart-hash generation.  VOLT26 does
-- not load that actor, so retain the same debounced service hook here.
if not GAMESTATE:IsCourseMode() then
	for player in ivalues(PlayerNumber) do
		local pn = ToEnumShortString(player)
		local parser = Def.ActorFrame{
			OnCommand=function(self) self:queuecommand("Parse") end,
			ParseCommand=function(self)
				local steps = GAMESTATE:GetCurrentSteps(player)
				if steps then ParseChartInfo(steps, pn) end
				self:stoptweening():sleep(0.4):queuecommand("Hash")
			end,
			HashCommand=function(self)
				local steps = GAMESTATE:GetCurrentSteps(player)
				if steps then
					ComputeChartHash(steps, pn)
					MESSAGEMAN:Broadcast("ChartParsed")
				end
			end,
		}
		parser["CurrentSteps"..pn.."ChangedMessageCommand"] = function(self)
			self:playcommand("Parse")
		end
		af[#af+1] = parser
	end
end

-- Screen title plaque.
af[#af+1] = Def.ActorFrame{
	InitCommand=function(self) self:xy(56,16):rotationz(-5) end,
	Def.Sprite{
		Texture=THEME:GetPathG("", "VOLT26/SongSelection/SS_bg.png"),
		InitCommand=function(self) self:align(0,0):setsize(170,43) end,
	},
	Def.BitmapText{
		Font=font, Text=GAMESTATE:IsCourseMode() and "COURSE SELECTION" or "SONG SELECTION",
		InitCommand=function(self) self:xy(85,22):zoom(0.52*fontScale):diffuse(Color.Black):maxwidth(290/fontScale) end,
	},
}

-- Banner_BG-SS is a complete 16:9 positioning canvas.  Map it to the whole
-- safe frame, then place only the changing banner within its marked opening.
local banner = Def.ActorFrame{ Name="Banner" }
banner[#banner+1] = Def.Sprite{
	Texture=THEME:GetPathG("", "VOLT26/SongSelection/Banner_BG-SS.png"),
	InitCommand=function(self) self:align(0,0):setsize(854,480) end,
}
banner[#banner+1] = Def.ActorProxy{
	Name="LiveBanner",
	InitCommand=function(self)
		self:xy(589,134):rotationz(-8.5)
			:zoomx(490/418):zoomy(195/164):visible(false)
	end,
	BeginCommand=function(self)
		local screen = SCREENMAN:GetTopScreen()
		local native_banner = screen and screen:GetChild("Banner")
		if native_banner then self:SetTarget(native_banner) end
	end,
	RefreshCommand=function(self)
		local kind = selectedType()
		local show = getItem() ~= nil or kind == "WheelItemDataType_Section"
		self:visible(show)
	end,
}
addRefreshCommands(banner)
af[#af+1] = banner

af[#af+1] = Def.Sprite{
	Texture=THEME:GetPathG("", "VOLT26/SongSelection/takeyourtime.png"),
	InitCommand=function(self) self:xy(744,345):setsize(102,140):rotationz(-4) end,
}

-- Backdrop_SongInfoSS is now a complete 16:9 positioning canvas.  Keep the
-- artwork full-frame and place only its dynamic content at the card origin.
local card = Def.ActorFrame{ Name="SongInfoCard" }
card[#card+1] = Def.Sprite{
	Texture=THEME:GetPathG("", "VOLT26/SongSelection/Backdrop_SongInfoSS.png"),
	InitCommand=function(self) self:align(0,0):setsize(854,480) end,
}
-- Match the dominant angle of Backdrop_SongInfoSS so all live typography and
-- graph geometry sit on the same plane as the printed card artwork.
local content = Def.ActorFrame{ InitCommand=function(self) self:xy(475,320):rotationz(-8.5) end }

local cardTitleX = -102
content[#content+1] = Def.ActorFrame{
	Name="Title",
	InitCommand=function(self)
		self:xy(cardTitleX,-86)
		self._volt26Window = 18
		self._volt26Elapsed = 0
		self:SetUpdateFunction(function(frame, delta)
			if (frame._volt26Length or 0) <= 24 then return end
			frame._volt26Elapsed = frame._volt26Elapsed + delta
			if frame._volt26Elapsed < 0.12 then return end
			frame._volt26Elapsed = frame._volt26Elapsed - 0.12
			frame._volt26Position = (frame._volt26Position or 1) + 1
			if frame._volt26Position > frame._volt26Length + 3 then frame._volt26Position = 1 end
			renderMarquee(frame)
		end)
	end,
	RefreshCommand=function(self) setMarquee(self, getTitle(getItem())) end,
	Def.BitmapText{
		Font=font, Name="Text",
		InitCommand=function(self) self:horizalign(left):zoom(0.76*fontScale):diffuse(Color.Black) end,
	},
}

-- Headline meters (one centered meter, or compact P1/P2 meters).
for player in ivalues(PlayerNumber) do
	local pn = ToEnumShortString(player)
	content[#content+1] = Def.ActorFrame{
		Name=pn.."Headline",
		RefreshCommand=function(self)
			local humans = GAMESTATE:GetHumanPlayers()
			local joined = GAMESTATE:IsHumanPlayer(player)
			self:visible(joined)
			if #humans <= 1 then self:x(108) else self:x(player == PLAYER_1 and 88 or 122) end
			local chart = getChart(player)
			self:GetChild("Meter"):settext(chart and chart:GetMeter() or dash)
				:zoom((#humans <= 1 and 2.70 or 1.45)*fontScale)
			self:GetChild("Label"):settext(#humans <= 1 and "" or pn)
		end,
		Def.BitmapText{
			Name="Meter", Font=font,
			InitCommand=function(self) self:y(-86):diffuse(Color.Black) end,
		},
		Def.BitmapText{
			Name="Label", Font=font,
			InitCommand=function(self) self:y(-105):zoom(0.26*fontScale):diffuse(color("#df0d12")) end,
		},
	}
end

-- Available meter row and independent P1/P2 selections.
local difficulties = Def.ActorFrame{ Name="Difficulties", InitCommand=function(self) self:xy(-80,-52) end }
for i=1,maxDifficultySlots do
	difficulties[#difficulties+1] = Def.ActorFrame{
		Name="Slot"..i, InitCommand=function(self) self:x((i-1)*23) end,
		SetSlotCommand=function(self, params)
			local chart = params.Charts[i]
			self:visible(chart ~= nil)
			if not chart then return end
			self:GetChild("Meter"):settext(chart:GetMeter()):diffuse(DifficultyColor(chart:GetDifficulty()))
			self:GetChild("P1"):visible(GAMESTATE:IsHumanPlayer(PLAYER_1) and chart == getChart(PLAYER_1))
			self:GetChild("P2"):visible(GAMESTATE:IsHumanPlayer(PLAYER_2) and chart == getChart(PLAYER_2))
		end,
		Def.BitmapText{ Name="Meter", Font=font, InitCommand=function(self) self:zoom(0.66*fontScale):diffuse(Color.Black) end },
		Def.BitmapText{ Name="P1", Font=font, Text="P1", InitCommand=function(self) self:y(-13):zoom(0.24*fontScale):diffuse(color("#e10d12")) end },
		Def.BitmapText{ Name="P2", Font=font, Text="P2", InitCommand=function(self) self:y(13):zoom(0.24*fontScale):diffuse(color("#33aaff")) end },
	}
end
difficulties.RefreshCommand=function(self)
	local params = {Charts=windowCharts(getCharts())}
	for i=1,maxDifficultySlots do self:GetChild("Slot"..i):playcommand("SetSlot", params) end
end
content[#content+1] = difficulties

-- Shared metadata row.
local metadata = {
	{"ARTIST", -104, -34, function()
		local item = getItem()
		if not item then return dash end
		if GAMESTATE:IsCourseMode() then return item.GetDescription and item:GetDescription() ~= "" and item:GetDescription() or "COURSE" end
		return item:GetDisplayArtist()
	end},
	{"BPM", -104, -17, function()
		if not getItem() or not GAMESTATE:GetMasterPlayerNumber() then return dash end
		return StringifyDisplayBPMs(GAMESTATE:GetMasterPlayerNumber()) or dash
	end},
	{"LENGTH", -104, 0, function()
		local item = getItem()
		if not item then return dash end
		local seconds = GAMESTATE:IsCourseMode() and TotalCourseLength(GAMESTATE:GetMasterPlayerNumber()) or item:MusicLengthSeconds()/SL.Global.ActiveModifiers.MusicRate
		return seconds and SecondsToMSS(seconds) or dash
	end},
}
for _, entry in ipairs(metadata) do
	content[#content+1] = Def.BitmapText{
		Font=font, Text=entry[1], InitCommand=function(self) self:xy(entry[2],entry[3]):horizalign(left):zoom(0.36*fontScale):diffuse(color("#999999")) end,
	}
	content[#content+1] = Def.BitmapText{
		Font=font, InitCommand=function(self) self:xy(entry[2]+47,entry[3]):horizalign(left):zoom(0.38*fontScale):maxwidth(92/(0.38*fontScale)) end,
		RefreshCommand=function(self) self:settext(entry[4]()) end,
	}
end

local function graphVertices(data, width, height)
	local verts = {}
	if #data.nps < 2 or data.peak <= 0 then return verts end
	for i, value in ipairs(data.nps) do
		local x = (i-1)/(#data.nps-1)*width
		local y = -height*(value/data.peak)
		verts[#verts+1] = {{x,0,0}, Color.Black}
		verts[#verts+1] = {{x,y,0}, Color.Black}
	end
	return verts
end

local function playerSummary(player)
	local pn = ToEnumShortString(player)
	local pane = Def.ActorFrame{ Name=pn.."Summary" }
	pane.RefreshCommand=function(self)
		local humans = GAMESTATE:GetHumanPlayers()
		local joined = GAMESTATE:IsHumanPlayer(player)
		self:visible(joined)
		if not joined then return end
		local two = #humans > 1
		local width = two and 104 or 230
		self:x(two and (player == PLAYER_1 and -104 or 17) or 0)
		local data = playerData(player)
		local pct = data.measures > 0 and data.stream/data.measures*100 or 0
		local radar = string.format("T%s J%s H%s M%s R%s A%s",
			safeRadar(data.chart,player,radarKeys[1][2]), safeRadar(data.chart,player,radarKeys[2][2]),
			safeRadar(data.chart,player,radarKeys[3][2]), safeRadar(data.chart,player,radarKeys[4][2]),
			safeRadar(data.chart,player,radarKeys[5][2]), safeRadar(data.chart,player,radarKeys[6][2]))
		local stream = string.format("%d/%d (%.1f%%) TS", data.stream, data.measures, pct)
		local player_label = self:GetChild("Player")
		local radar_actor = self:GetChild("Radar")
		local tech_actor = self:GetChild("Tech")
		local peak_actor = self:GetChild("Peak")
		local credit_actor = self:GetChild("Credit")
		if two then
			player_label:visible(true):xy(0,8):settext(pn)
			radar_actor:xy(0,20):horizalign(left):settext(radar):maxwidth(width/(0.28*fontScale))
			tech_actor:xy(0,32):settext(string.format("%d XO  %d FS  %d SS  %d JA  %d BR", data.xo,data.fs,data.ss,data.jk,data.br))
				:maxwidth(width/(0.28*fontScale))
			peak_actor:xy(0,113):horizalign(left)
				:settext(string.format("%s PEAK %.1f", pn, data.peak*SL.Global.ActiveModifiers.MusicRate))
				:maxwidth(width/(0.28*fontScale))
			credit_actor:xy(0,124):horizalign(left):settext("STEPS "..chartCredit(data.chart))
				:maxwidth(width/(0.27*fontScale))
		else
			player_label:visible(false)
			radar_actor:xy(24,100):horizalign(center):settext(radar):maxwidth(78/(0.28*fontScale))
			tech_actor:xy(20,-36):settext(string.format("%d XO      %d FS\n\n%d SS      %d JA\n\n%d BR      %s",
				data.xo,data.fs,data.ss,data.jk,data.br,stream)):maxwidth(118/(0.31*fontScale))
			peak_actor:xy(-103,100):horizalign(left)
				:settext(string.format("PEAK NPS %.1f", data.peak*SL.Global.ActiveModifiers.MusicRate))
				:maxwidth(78/(0.30*fontScale))
			credit_actor:xy(137,100):horizalign(right):settext("STEPS "..shortText(chartCredit(data.chart), 14))
				:maxwidth(68/(0.30*fontScale))
		end
		local graph = self:GetChild("Graph")
		local verts = graphVertices(data, width, 38)
		graph:SetNumVertices(#verts):SetVertices(verts)
		graph:xy(two and 0 or -96,90)
	end
	pane[#pane+1] = Def.BitmapText{ Name="Player", Font=font, InitCommand=function(self) self:horizalign(left):zoom(0.31*fontScale):diffuse(color("#df0d12")) end }
	pane[#pane+1] = Def.BitmapText{ Name="Radar", Font=font, InitCommand=function(self) self:zoom(0.28*fontScale):diffuse(Color.Black):rotationz(-3) end }
	pane[#pane+1] = Def.BitmapText{ Name="Tech", Font=font, InitCommand=function(self) self:horizalign(left):vertalign(top):zoom(0.31*fontScale):rotationz(2.5) end }
	pane[#pane+1] = Def.ActorMultiVertex{
		Name="Graph", InitCommand=function(self) self:SetDrawState({Mode="DrawMode_QuadStrip"}):rotationz(-3) end,
	}
	pane[#pane+1] = Def.BitmapText{ Name="Peak", Font=font, InitCommand=function(self) self:horizalign(left):zoom(0.30*fontScale):diffuse(Color.Black):rotationz(-3) end }
	pane[#pane+1] = Def.BitmapText{ Name="Credit", Font=font, InitCommand=function(self) self:horizalign(left):zoom(0.30*fontScale):diffuse(Color.Black):rotationz(-3) end }
	return pane
end

content[#content+1] = playerSummary(PLAYER_1)
content[#content+1] = playerSummary(PLAYER_2)
card[#card+1] = content

card.RefreshCommand=function(self)
	self:visible(getItem() ~= nil)
end
addRefreshCommands(card)
af[#af+1] = card

return af
]=]

return LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/VOLT26/Layout.lua"))
