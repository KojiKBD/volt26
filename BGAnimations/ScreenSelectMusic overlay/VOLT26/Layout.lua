-- VOLT26 Song Select composition.
--
-- The screen is laid out in a virtual 1920x1080 space and scaled to whatever
-- resolution the theme runs at, so every measurement below is the design figure
-- rather than a converted one.

local H = {
	W = 1920,
	H = 1080,
	Dash = "--",
	ChartCache = {},
	LastStepsPlayer = PLAYER_1,
}

-- Palette.
H.Bg     = color("#0a0a0c")
H.Panel  = color("#141417")
H.Panel2 = color("#17171b")
H.Line   = color("#26262c")
H.Ink    = color("#f2f0ec")
H.Mute   = color("#8a8a94")
H.Dim    = color("#5a5a64")
H.P1     = color("#e03a2f")
H.P2     = color("#2f7de0")
-- The songwheel rail: a red desaturated far enough to read as structure rather
-- than as a second accent.
H.Rail   = color("#3a2020")
-- Everything standing off the card's solid body -- the two leaderboards, the
-- preview strip, the card's own header band -- shares one ground: the panel
-- colour held back from full strength, so the screen's backdrop still reads
-- through it the way it does behind the songwheel.  Enough to carry text,
-- not enough to close the screen off again.
H.ScrimAlpha = 0.65

-- Typography.  The design calls for Oswald and Space Mono; the theme ships
-- neither, so VOLT26.Type fills the two roles with the closest faces it does
-- have and owns the metrics that turn a design pixel size into a zoom.
H.Display = VOLT26.Type.Display
H.Label = VOLT26.Type.Label
H.DisplayZoom = VOLT26.Type.DisplayZoom
H.LabelZoom = VOLT26.Type.LabelZoom
H.SetLabel = VOLT26.Type.SetLabel
H.SetDisplay = VOLT26.Type.SetDisplay

-- Text and rule factories.  Every one takes the design's own figures --
-- {Name, Px, Tint, Align, X, Y} -- so a component reads as the design does and
-- the shared defaults (no shadow, vertically centred on the given Y) stay in
-- one place.
local function textActor(font, zoomFor, defaultTint)
	return function(t)
		return Def.BitmapText{
			Name=t.Name, Font=font,
			InitCommand=function(self)
				self:xy(t.X or 0, t.Y or 0)
					:horizalign(t.Align or left):vertalign(t.VAlign or middle)
					:shadowlength(0):zoom(zoomFor(t.Px)):diffuse(t.Tint or defaultTint)
				if t.Width then self:maxwidth(t.Width/zoomFor(t.Px)) end
			end,
		}
	end
end

H.LabelText = textActor(H.Label, H.LabelZoom, H.Mute)
H.DisplayText = textActor(H.Display, H.DisplayZoom, H.Ink)

function H.String(key)
	return THEME:GetString("ScreenSelectMusic", key)
end

-- Video artwork.  Songs and packs may ship their banner as a movie, and such a
-- file cannot go through the image cache -- the cache holds stills only, so
-- LoadFromCached quietly fails and the art never appears.  A movie has to be
-- loaded from its own path and have its decoder switched on, and it reports no
-- size at all until its first frame lands, which is why nothing may be fitted
-- into a box before H.ArtReady says so.
H.MovieExtensions = {
	avi=true, f4v=true, flv=true, mkv=true, mp4=true, mpeg=true,
	mpg=true, mov=true, ogv=true, ogg=true, webm=true, wmv=true,
}

function H.IsMovie(path)
	return type(path) == "string"
		and H.MovieExtensions[(path:match("%.([^.]+)$") or ""):lower()] == true
end

-- Answers whether the artwork loaded, so the caller can fall back.
function H.LoadArt(sprite, path, cacheDir)
	if type(path) ~= "string" or path == "" then return false end
	if H.IsMovie(path) then
		return pcall(function()
			sprite:Load(path)
			if sprite.SetDecodeMovie then sprite:SetDecodeMovie(true) end
			sprite:animate(true)
		end)
	end
	return pcall(function()
		sprite:LoadFromCached(cacheDir, path)
		sprite:animate(false)
	end)
end

function H.ArtReady(sprite)
	local ok, ready = pcall(function()
		return sprite:GetWidth() > 1 and sprite:GetHeight() > 1
	end)
	return ok and ready or false
end

-- Releases a movie's decoder.  A still needs none of this, and calling it on
-- one is harmless.
function H.StopArt(sprite)
	pcall(function()
		if sprite.SetDecodeMovie then sprite:SetDecodeMovie(false) end
		sprite:animate(false)
	end)
end

function H.Rule(t)
	return Def.Quad{
		Name=t.Name,
		InitCommand=function(self)
			self:align(t.AlignX or 0, t.AlignY or 0):xy(t.X or 0, t.Y or 0)
				:zoomto(t.Width or 1, t.Height or 1)
				:diffuse(t.Tint or H.Line):diffusealpha(t.Alpha or 1)
		end,
	}
end

-- Vertical bands.
H.Pad         = 32
H.TopBarH     = 62
H.HeaderH     = 132
H.FooterH     = 62
H.ContentTop  = H.TopBarH + H.HeaderH
H.InnerTop    = H.ContentTop + 20
H.InnerBottom = H.H - H.FooterH - 20

-- Content columns.  The songwheel's figures are shared with the wheel row
-- graphic through VOLT26.MusicSelection, so the rail cannot drift from the rows.
local wheel = VOLT26.MusicSelection.Wheel
H.WheelX     = wheel.X
H.WheelW     = wheel.Width
H.WheelGuide = wheel.X + wheel.GuideOffset
H.WheelItemX = wheel.X + wheel.ItemOffset
H.WheelPitch = wheel.Pitch
H.RowsX      = H.WheelX + H.WheelW + 26
H.RowsW      = H.W - H.Pad - H.RowsX
H.RowGap     = 26

H.Scale = math.min(_screen.w/H.W, _screen.h/H.H)
H.Left = _screen.cx - H.W*H.Scale/2
H.Top = _screen.cy - H.H*H.Scale/2

-- The list geometry, shared by the wheel rows, the sticky heading and the fades.
H.WheelListTop = H.InnerTop + 42
H.WheelListBottom = H.InnerBottom
H.WheelCenterY = (H.WheelListTop + H.WheelListBottom)/2

function H.Wheel()
	local screen = SCREENMAN:GetTopScreen()
	return screen and screen.GetMusicWheel and screen:GetMusicWheel() or nil
end

function H.SelectedType()
	local wheel = H.Wheel()
	return wheel and wheel:GetSelectedType() or nil
end

function H.SelectedSection()
	local wheel = H.Wheel()
	return wheel and wheel:GetSelectedSection() or nil
end

function H.SelectedPack()
	if GAMESTATE:IsCourseMode() then return nil end
	local selected = H.SelectedType()
	local sort = GAMESTATE:GetSortOrder()
	if (sort == "SortOrder_Group" or sort == "SortOrder_Series") and
		(selected == "WheelItemDataType_Section" or selected == "WheelItemDataType_ParentSection") then
		local group = H.SelectedSection()
		return group and group ~= "" and group or nil
	end
	return nil
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

-- The pack the selection belongs to, and where the selection sits inside it.
-- The top bar, the song header and the songwheel's sticky heading all read the
-- same answer, so they cannot disagree.
function H.Pack()
	local selectedPack = H.SelectedPack()
	if selectedPack then return selectedPack end
	local song = not GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentSong() or nil
	local group = song and song.GetGroupName and song:GetGroupName() or nil
	if group and group ~= "" then return group end
	return H.SelectedSection() or ""
end

function H.PackPosition()
	local group = H.Pack()
	if group == "" then return 0, 0 end
	local song = not GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentSong() or nil
	local ok, songs = pcall(function() return SONGMAN:GetSongsInGroup(group) end)
	if not ok or not songs then return 0, 0 end
	for index, candidate in ipairs(songs) do
		if candidate == song then return index, #songs end
	end
	return 0, #songs
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

-- One joined player gets the whole band to itself, and that changes the row's
-- shape rather than just its height: see PlayerRow's solo layout.
function H.IsSolo()
	return #GAMESTATE:GetHumanPlayers() <= 1
end

-- Each player owns one row.  A lone player's row takes the whole band, which is
-- what gives its density graph and preview their extra height.
function H.RowGeometry(player)
	local band = H.InnerBottom - H.InnerTop
	if H.IsSolo() then return H.InnerTop, band end
	local height = (band - H.RowGap)/2
	if player == PLAYER_1 then return H.InnerTop, height end
	return H.InnerTop + height + H.RowGap, height
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
		local wheel = H.Wheel()
		if wheel then
			if not GAMESTATE:IsCourseMode() and GAMESTATE:GetSortOrder() ~= "SortOrder_Group" then
				wheel:ChangeSort("SortOrder_Group")
			end
			-- The wheel is the screen's own actor rather than a child of this
			-- frame, so it needs the same scale before its rows can be laid out
			-- in design units.  Its origin is the rail the dots sit on.
			wheel:xy(H.Left + H.WheelGuide*H.Scale, H.Top + H.WheelCenterY*H.Scale):zoom(H.Scale)
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

af[#af+1] = LoadActor(componentPath("TopBar.lua"), H)
af[#af+1] = LoadActor(componentPath("SongHeader.lua"), H)
af[#af+1] = LoadActor(componentPath("Songwheel.lua"), H)

local rowLayer = Def.ActorFrame{
	Name="PlayerRows",
	-- Modal overlays (sort menu, song search, leaderboard, input test) own the
	-- screen while they are open.  The preview strips draw after them, so stop
	-- drawing the rows entirely instead of relying on draw order.
	VOLT26ModalOverlayOpenedMessageCommand=function(self) self:visible(false) end,
	VOLT26ModalOverlayClosedMessageCommand=function(self) self:visible(true) end,
}
rowLayer[#rowLayer+1] = LoadActor(componentPath("PlayerRow.lua"), {H=H, Player=PLAYER_1})
rowLayer[#rowLayer+1] = LoadActor(componentPath("PlayerRow.lua"), {H=H, Player=PLAYER_2})
rowLayer[#rowLayer+1] = LoadActor(componentPath("GroupPreview.lua"), H)
af[#af+1] = rowLayer

af[#af+1] = LoadActor(componentPath("Footer.lua"), H)

-- Use Song Select idle time to prepare the small shared gameplay/evaluation
-- textures before the player confirms a chart.
af[#af+1] = VOLT26.Warmup.CreateActor("Play", {Interval=0.12})

return af
