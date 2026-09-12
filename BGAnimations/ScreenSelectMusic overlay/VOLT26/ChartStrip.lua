local args = ...
local H = args.H
local player = args.Player
local stripX = args.X
local stripW = args.Width
local pn = ToEnumShortString(player)

-- The chart preview: a scale model of this player's notefield, scrolling with
-- the song sample.  It uses the noteskin the player has chosen and spaces the
-- notes by the speed mod they have chosen, so what the strip shows is what they
-- are about to play rather than a generic picture of the chart.

local headerH = 24
local receptorGap = 42
local bottomGap = 8
local designLaneWidth = 38
local arrowSize = 64
local tapPool = 20
local minePool = 4
local liftPool = 4
local holdPool = 6
local measurePool = 6
local fadeDepth = 26
-- A preview whose notes are a pixel apart says nothing, and one that fits a
-- single note says little more, so the modelled spacing is held inside these
-- bands.  They are wide enough that an ordinary speed mod passes through
-- untouched and only absurd ones are caught.  Beat spacing and time spacing are
-- in different units, so each gets its own.
local beatSpacingRange = {8, 170}
local timeSpacingRange = {50, 700}
local transparent = color("0,0,0,0")
-- The fades that swallow the notes at each end have to be stronger than the
-- ground they sit on: at the scrim's own strength a note would still be a third
-- visible where it is meant to be gone.
local fadeAlpha = 0.92

local style = GAMESTATE:GetCurrentStyle()
local columnCount = 4
do
	local ok, count = pcall(function() return style:ColumnsPerPlayer() end)
	if ok and tonumber(count) and count > 0 then columnCount = count end
end

local columns = {}
for i = 1, columnCount do
	local ok, info = pcall(function() return style:GetColumnInfo(player, i) end)
	columns[i] = (ok and info and info.Name) or "Up"
end

local laneWidth = math.min(designLaneWidth, (stripW - 16)/columnCount)
-- One scale factor drives both axes.  Gameplay draws one arrow per column width
-- and advances one column width per beat at 1x, so keeping the same ratio here
-- makes the strip a scale model rather than an approximation of one.
local noteZoom = laneWidth/arrowSize
local laneOrigin = stripX + stripW/2 - (columnCount-1)*laneWidth/2

-- The noteskin is read once, when this actor tree is built.  Changing it means
-- visiting Player Options, and returning from there rebuilds the screen.
--
-- A player who has never picked one has no noteskin in the theme's modifiers,
-- so the engine is asked next: PlayerOptions:NoteSkin() answers with the
-- machine default rather than nothing.  The list is built by appending, never
-- as a literal with holes in it -- ipairs stops at the first nil, which would
-- silently drop every fallback behind an unset choice.
local noteskin
do
	local candidates = {}
	local function offer(name)
		if type(name) == "string" and name ~= "" then candidates[#candidates+1] = name end
	end

	local okMods, modifiers = pcall(function() return VOLT26.Options.GetPlayerModifiers(player) end)
	if okMods and modifiers then offer(modifiers.NoteSkin) end

	local okEngine, engineSkin = pcall(function()
		return GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred"):NoteSkin()
	end)
	if okEngine then offer(engineSkin) end

	offer("cel")
	local okNames, names = pcall(function() return NOTESKIN:GetNoteSkinNames(false) end)
	if okNames and names then
		for name in ivalues(names) do offer(name) end
	end

	for _, candidate in ipairs(candidates) do
		if NOTESKIN:DoesNoteSkinExist(candidate) then
			noteskin = candidate
			break
		end
	end
end

-- Only reached when the game has no usable noteskin at all.  A note stands in
-- as a diamond rather than a square so the strip still reads as a stepchart.
local function fallbackActor(element, name)
	local receptor = element == "Receptor"
	local tint = element == "Tap Mine" and color("#8a8a94") or H.Accent(player)
	return Def.Quad{
		Name = name,
		InitCommand = function(self)
			self:zoomto(receptor and 42 or 22, receptor and 5 or 22)
				:diffuse(tint):diffusealpha(receptor and 0.45 or 0.9)
				:rotationz(receptor and 0 or 45)
		end,
	}
end

local function loadNote(columnName, element, name)
	if not noteskin then return fallbackActor(element, name) end
	local ok, actor = pcall(NOTESKIN.LoadActorForNoteSkin, NOTESKIN, columnName, element, noteskin)
	if not ok or not actor then return fallbackActor(element, name) end
	actor.Name = name
	return actor
end

local function noteTexture(columnName, element)
	if not noteskin then return THEME:GetPathG("", "_blank") end
	local ok, path = pcall(NOTESKIN.GetPathForNoteSkin, NOTESKIN, columnName, element, noteskin)
	return ok and path or THEME:GetPathG("", "_blank")
end

local function holdBodyVertices(width, top, bottom, textureHeight)
	local span = (bottom-top) / math.max(1, textureHeight*noteZoom)
	local textureBottom = math.ceil(span-0.0001)
	local textureTop = textureBottom-span
	local half = width/2
	local tint = {1,1,1,1}
	return {
		{{-half, top, 0},    tint, {0, textureTop}},
		{{ half, top, 0},    tint, {1, textureTop}},
		{{ half, bottom, 0}, tint, {1, textureBottom}},
		{{-half, bottom, 0}, tint, {0, textureBottom}},
	}, textureBottom
end

local function holdTailVertices(width, top, length, textureRow)
	local half = width/2
	local tint = {1,1,1,1}
	return {
		{{-half, top, 0},        tint, {0, textureRow}},
		{{ half, top, 0},        tint, {1, textureRow}},
		{{0, top+length, 0},     tint, {0.5, textureRow}},
	}
end

-- Rhythm colours live as vertically stacked frames in the tap texture, so a
-- skin that follows that convention is coloured by shifting its texture.  A
-- skin that does not simply keeps its own default frame.
local function rhythmOffset(quant)
	local order = {[4]=0, [8]=1, [12]=3, [16]=2, [24]=5, [32]=4, [48]=6, [64]=7}
	return (order[quant] or 7) * 0.03125
end

local function setRhythm(actor, quant)
	local visual = actor and actor:GetChild("Visual")
	if visual and visual.texturetranslate then visual:texturetranslate(rhythmOffset(quant), 0) end
end

-- The chart's own ceiling, as the reference an M-mod is measured against.  The
-- declared display ceiling wins so a hidden gimmick BPM cannot collapse the
-- whole preview into a note wall.
local function chartCeilingBpm(chart)
	local ok, bpms = pcall(function() return chart:GetDisplayBpms() end)
	local ceiling = ok and type(bpms) == "table" and tonumber(bpms[2]) or nil
	if not ceiling or ceiling <= 0 then
		-- GetActualBPM answers with the slowest and the fastest as two values,
		-- not as a table.
		local okActual, _, fastest = pcall(function() return chart:GetTimingData():GetActualBPM() end)
		ceiling = okActual and tonumber(fastest) or nil
	end
	if not ceiling or ceiling <= 0 then return nil end
	return ceiling
end

-- Returns the spacing the player's own speed mod produces, and whether that
-- spacing is per second rather than per beat.  C-mod is the one that has to be
-- laid out in time; X and M both resolve to a multiple of the 1x beat pitch.
-- Each of these getters answers with the value *and* its rate of approach, so
-- every call is parenthesised down to one: passing both to tonumber() hands the
-- second one over as a numeric base.
local function optionValue(options, name)
	return tonumber((options[name](options))) or 0
end

local function speedSpacing(chart)
	local options = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")

	local maxScrollBpm = optionValue(options, "MaxScrollBPM")
	if maxScrollBpm > 0 then
		return laneWidth * maxScrollBpm / (chartCeilingBpm(chart) or maxScrollBpm), false
	end

	local scrollBpm = optionValue(options, "ScrollBPM")
	if optionValue(options, "TimeSpacing") > 0 and scrollBpm > 0 then
		return laneWidth * scrollBpm/60, true
	end

	local scrollSpeed = optionValue(options, "ScrollSpeed")
	return laneWidth * (scrollSpeed > 0 and scrollSpeed or 1), false
end

local function lowerBound(list, key, target)
	local low, high = 1, #list+1
	while low < high do
		local middle = math.floor((low+high)/2)
		if list[middle][key] < target then low = middle+1 else high = middle end
	end
	return low
end

-- Every pooled actor is looked up once and kept.  This frame holds well over a
-- hundred children and the pools are walked on every drawn frame, so resolving
-- them by name each time would be the most expensive thing on the screen.
local poolSizes = {tap = tapPool, mine = minePool, lift = liftPool, hold = holdPool}
local poolPrefix = {tap = "Tap_", mine = "Mine_", lift = "Lift_", hold = "Hold_"}

local function bindPools(self)
	local pools = {}
	for kind, size in pairs(poolSizes) do
		pools[kind] = {}
		for column = 1, columnCount do
			pools[kind][column] = {}
			for i = 1, size do
				pools[kind][column][i] = self:GetChild(poolPrefix[kind]..column.."_"..i)
			end
		end
	end
	pools.measure = {}
	for i = 1, measurePool do pools.measure[i] = self:GetChild("Measure"..i) end
	self.pools = pools
end

local function hideAll(self)
	for kind in pairs(poolSizes) do
		for column = 1, columnCount do
			for _, actor in ipairs(self.pools[kind][column]) do actor:visible(false) end
		end
	end
	for _, actor in ipairs(self.pools.measure) do actor:visible(false) end
end

local holdParts = {"HoldBody","HoldHead","HoldTail","RollBody","RollHead","RollTail"}

local function draw(self)
	if not self.receptorY or not self.pools then return end
	hideAll(self)
	if not self.notes or not self.timing or not self.scrollPitch then return end

	local top, bottom = self.receptorY, self.bottomY
	local perSecond = self.spacingIsTime
	-- Not `self.pitch`: Actor already answers to that name, and the method
	-- wins over anything stored beside it.
	local pitch = self.scrollPitch

	-- The strip is anchored on the song's preview marker: it opens on the part
	-- of the chart the marker points at, which is also the part the wheel plays.
	--
	-- The music clock refines that when it can be trusted, but it cannot always
	-- be: the wheel plays a fallback loop between selections and while the list
	-- is scrolling fast, and that loop reports a position too.  Only a reading
	-- inside the sample's own window belongs to this song.
	local current
	if self.trustMusicClock then
		local ok, seconds = pcall(function() return GAMESTATE:GetCurMusicSeconds() end)
		seconds = ok and tonumber(seconds) or nil
		if seconds and seconds >= self.sampleStart - 1
			and seconds <= self.sampleStart + self.sampleLength + 2 then
			current = seconds
		end
	end
	if not current then
		current = self.sampleStart + (self.freeClock or 0) % self.sampleLength
	end
	local okBeat, currentBeat = pcall(function() return self.timing:GetBeatFromElapsedTime(current) end)
	currentBeat = okBeat and tonumber(currentBeat) or nil
	if not currentBeat then return end

	local span = bottom - top
	local key = perSecond and "Time" or "Beat"
	local now = perSecond and current or currentBeat
	local last = now + span/pitch
	local function yAt(value) return top + (value - now)*pitch end

	local used = {}
	for column = 1, columnCount do used[column] = {tap=0, mine=0, lift=0, hold=0} end

	for index = lowerBound(self.notes, key, now), #self.notes do
		local note = self.notes[index]
		if note[key] > last then break end
		local column = note.Column
		if column <= columnCount then
			local kind = note.Kind == "mine" and "mine" or (note.Kind == "lift" and "lift" or "tap")
			local pool = kind == "mine" and minePool or (kind == "lift" and liftPool or tapPool)
			used[column][kind] = used[column][kind] + 1
			if used[column][kind] <= pool then
				local actor = self.pools[kind][column][used[column][kind]]
				actor:visible(true)
					:xy(laneOrigin + (column-1)*laneWidth, yAt(note[key]))
					:zoom(noteZoom)
					:diffusealpha(note.Kind == "fake" and 0.38 or 1)
				setRhythm(actor, note.Quantization)
			end
		end
	end

	for _, hold in ipairs(self.holds) do
		local endKey = perSecond and hold.EndTime or hold.EndBeat
		local startKey = hold[key]
		if endKey and endKey >= now and startKey <= last and hold.Column <= columnCount then
			local column = hold.Column
			used[column].hold = used[column].hold + 1
			if used[column].hold <= holdPool then
				local actor = self.pools.hold[column][used[column].hold]
				local rawStartY, rawEndY = yAt(startKey), yAt(endKey)
				local startY = math.max(top, rawStartY)
				local endY = math.min(bottom, rawEndY)
				if endY > startY then
					local isRoll = hold.Kind == "roll"
					local head = actor:GetChild(isRoll and "RollHead" or "HoldHead")
					local body = actor:GetChild(isRoll and "RollBody" or "HoldBody")
					local tail = actor:GetChild(isRoll and "RollTail" or "HoldTail")
					actor:visible(true):x(laneOrigin + (column-1)*laneWidth)
					for _, name in ipairs(holdParts) do actor:GetChild(name):visible(false) end

					local active = startKey <= now + 0.001
					local headY = active and top or startY
					local texture = body:GetTexture()
					local textureHeight = texture and texture:GetSourceHeight() or (isRoll and 256 or 128)
					local bodyWidth = arrowSize*noteZoom
					local bodyVertices, textureBottom = holdBodyVertices(bodyWidth, headY, endY, textureHeight)
					body:visible(true):SetNumVertices(4):SetVertices(bodyVertices)
					head:visible(true):y(headY):zoom(noteZoom):diffusealpha(active and 0.82 or 1)
					local capHeight = math.min(18*noteZoom, bottom - rawEndY)
					local showTail = rawEndY <= bottom and rawEndY >= top and capHeight > 0
					tail:visible(showTail)
					if showTail then
						tail:SetNumVertices(3):SetVertices(holdTailVertices(bodyWidth, rawEndY, capHeight, textureBottom))
					end
					setRhythm(actor, hold.Quantization)
				end
			end
		end
	end

	-- Measure lines are laid out in beats even under a C-mod: they mark the
	-- chart's own structure, not the scroll's.
	local lines = 0
	local firstMeasure = math.ceil(currentBeat/4)
	for measure = firstMeasure, firstMeasure + measurePool do
		local beat = measure*4
		local value = beat
		if perSecond then
			local okTime, seconds = pcall(function() return self.timing:GetElapsedTimeFromBeat(beat) end)
			value = okTime and tonumber(seconds) or nil
		end
		if not value then break end
		local y = yAt(value)
		if y > bottom then break end
		lines = lines + 1
		if lines > measurePool then break end
		self.pools.measure[lines]:visible(true):y(y)
	end
end

local af = Def.ActorFrame{
	Name = pn.."ChartStrip",
	RefreshCommand = function(self)
		local joined = GAMESTATE:IsHumanPlayer(player)
		self:visible(joined)
		if not joined then return end

		local rowTop, rowHeight = H.RowGeometry(player)
		self.receptorY = rowTop + headerH + receptorGap
		-- Notes are drawn from their centre, so a spawn line sitting on the
		-- strip's inner edge puts half an arrow outside it.  Half a lane is
		-- exactly half an arrow at this zoom, so pulling the line up by that
		-- much keeps the whole note inside the frame as it appears.
		self.bottomY = rowTop + rowHeight - bottomGap - laneWidth/2

		self:GetChild("Background"):xy(stripX, rowTop):zoomto(stripW, rowHeight)
		self:GetChild("EdgeL"):xy(stripX-1, rowTop-1):zoomto(1, rowHeight+2)
		self:GetChild("EdgeR"):xy(stripX+stripW, rowTop-1):zoomto(1, rowHeight+2)
		self:GetChild("EdgeT"):xy(stripX-1, rowTop-1):zoomto(stripW+2, 1)
		self:GetChild("EdgeB"):xy(stripX-1, rowTop+rowHeight):zoomto(stripW+2, 1)
		self:GetChild("HeaderRule"):xy(stripX, rowTop + headerH):zoomto(stripW, 1)
		H.SetLabel(self:GetChild("Caption"), H.String("Preview"), 9, stripW-16)
		self:GetChild("Caption"):xy(stripX + stripW/2, rowTop + headerH/2)
		self:GetChild("TopFade"):xy(stripX, rowTop + headerH + 1):zoomto(stripW, fadeDepth)
		-- The fade stays on the frame's own edge rather than on the spawn line,
		-- which now sits a little above it.
		self:GetChild("BottomFade"):xy(stripX, rowTop + rowHeight):zoomto(stripW, fadeDepth)
		for column = 1, columnCount do
			self:GetChild("Receptor_"..column)
				:xy(laneOrigin + (column-1)*laneWidth, self.receptorY):zoom(noteZoom)
		end

		local chart = H.Chart(player)
		if chart ~= self.chart then
			self.chart = chart
			self.notes, self.holds, self.timing = nil, nil, nil
			self.freeClock = 0
			local song = GAMESTATE:GetCurrentSong()
			self.sampleStart = math.max(0, tonumber(song and song:GetSampleStart()) or 0)
			local length = tonumber(song and song:GetSampleLength()) or 0
			-- A song can leave the length unset, which the engine reports as a
			-- negative; the wheel then plays its own default window.
			self.sampleLength = length > 0 and length or 15
			-- With a separate preview file the engine plays that file from zero,
			-- so its position says nothing about where we are in the chart and
			-- the strip has to run on its own clock from the marker.
			local okPreview, previewPath = pcall(function() return song:GetPreviewMusicPath() end)
			local okMusic, musicPath = pcall(function() return song:GetMusicPath() end)
			self.trustMusicClock = okPreview and okMusic and previewPath == musicPath

			if chart and not GAMESTATE:IsCourseMode() then
				local untilSeconds = self.sampleStart + math.max(15, self.sampleLength) + 8
				local ok, notes, holds = pcall(function()
					return VOLT26.Simfile.Notes(chart, player, untilSeconds)
				end)
				if ok then
					self.notes, self.holds = notes, holds
					self.timing = chart:GetTimingData()
				end
			end
			if self.timing then
				local pitch, isTime = speedSpacing(chart)
				local range = isTime and timeSpacingRange or beatSpacingRange
				self.scrollPitch = math.min(range[2], math.max(range[1], pitch))
				self.spacingIsTime = isTime
			end
		end
		draw(self)
	end,
	OnCommand = function(self)
		bindPools(self)
		self.advanceElapsed = 0
		self:SetUpdateFunction(function(frame, delta)
			if not frame:GetVisible() then return end
			frame.advanceElapsed = frame.advanceElapsed + (delta or 0)
			local interval = VOLT26.Performance.IsEnabled() and (1/30) or 0
			if frame.advanceElapsed < interval then return end
			frame.freeClock = (frame.freeClock or 0) + frame.advanceElapsed
			frame.advanceElapsed = 0
			draw(frame)
		end)
	end,
}

-- No box, and a ground held back to the shared scrim so the backdrop still
-- reads under the notes.  The fades that mask the notes running past its ends
-- are that same scrim rather than the wheel's solid one, so the strip does not
-- turn opaque again at its two ends.
af[#af+1] = H.Rule{Name="Background", Tint=H.Panel, Alpha=H.ScrimAlpha}
-- Drawn as an outline rather than a filled quad behind the ground: a filled one
-- would show through the scrim and close the strip off again.
af[#af+1] = H.Rule{Name="EdgeL"}
af[#af+1] = H.Rule{Name="EdgeR"}
af[#af+1] = H.Rule{Name="EdgeT"}
af[#af+1] = H.Rule{Name="EdgeB"}
af[#af+1] = H.Rule{Name="HeaderRule"}
af[#af+1] = H.LabelText{Name="Caption", Px=9, Tint=H.Dim, Align=center}

for i = 1, measurePool do
	af[#af+1] = Def.Quad{
		Name = "Measure"..i,
		InitCommand = function(self)
			self:align(0,0.5):x(stripX):zoomto(stripW, 1):diffuse(H.Line):visible(false)
		end,
	}
end

for column = 1, columnCount do
	local columnName = columns[column]
	af[#af+1] = Def.ActorFrame{
		Name = "Receptor_"..column,
		InitCommand = function(self) self:diffusealpha(0.5) end,
		loadNote(columnName, "Receptor"),
	}
	for i = 1, tapPool do
		af[#af+1] = Def.ActorFrame{
			Name = "Tap_"..column.."_"..i,
			InitCommand = function(self) self:visible(false) end,
			loadNote(columnName, "Tap Note", "Visual"),
		}
	end
	for i = 1, minePool do
		af[#af+1] = Def.ActorFrame{
			Name = "Mine_"..column.."_"..i,
			InitCommand = function(self) self:visible(false) end,
			loadNote(columnName, "Tap Mine", "Visual"),
		}
	end
	for i = 1, liftPool do
		af[#af+1] = Def.ActorFrame{
			Name = "Lift_"..column.."_"..i,
			InitCommand = function(self) self:visible(false) end,
			loadNote(columnName, "Tap Lift", "Visual"),
		}
	end
	for i = 1, holdPool do
		af[#af+1] = Def.ActorFrame{
			Name = "Hold_"..column.."_"..i,
			InitCommand = function(self) self:visible(false) end,
			Def.ActorMultiVertex{
				Name = "HoldBody", Texture = noteTexture(columnName, "Hold Body Inactive"),
				InitCommand = function(self)
					self:SetDrawState({Mode="DrawMode_Quads"}):texturewrapping(true):visible(false)
				end,
			},
			loadNote(columnName, "Hold Head Inactive", "HoldHead"),
			Def.ActorMultiVertex{
				Name = "HoldTail", Texture = noteTexture(columnName, "Hold Body Inactive"),
				InitCommand = function(self)
					self:SetDrawState({Mode="DrawMode_Triangles"}):texturewrapping(true):visible(false)
				end,
			},
			Def.ActorMultiVertex{
				Name = "RollBody", Texture = noteTexture(columnName, "Roll Body Inactive"),
				InitCommand = function(self)
					self:SetDrawState({Mode="DrawMode_Quads"}):texturewrapping(true):visible(false)
				end,
			},
			loadNote(columnName, "Roll Head Inactive", "RollHead"),
			Def.ActorMultiVertex{
				Name = "RollTail", Texture = noteTexture(columnName, "Roll Body Inactive"),
				InitCommand = function(self)
					self:SetDrawState({Mode="DrawMode_Triangles"}):texturewrapping(true):visible(false)
				end,
			},
		}
	end
end

-- The strip has no clip of its own, so notes are only ever placed inside it and
-- these two fades carry the edges into the card colour.
af[#af+1] = Def.Quad{
	Name = "TopFade",
	InitCommand = function(self)
		self:align(0,0):diffuse(H.Panel):diffusealpha(fadeAlpha):diffusebottomedge(transparent)
	end,
}
af[#af+1] = Def.Quad{
	Name = "BottomFade",
	InitCommand = function(self)
		self:align(0,1):diffuse(H.Panel):diffusealpha(fadeAlpha):diffusetopedge(transparent)
	end,
}

return af
