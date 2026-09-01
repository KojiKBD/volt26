local H = ...
local previewW, previewH = 354, 350
local receptorY, bottomY = 30, 342
local mMod = 600
local tapPoolSize, minePoolSize, liftPoolSize, holdPoolSize = 36, 10, 8, 12
local noteskin = "cel"
local fileCache = {}
local parseCache = setmetatable({}, {__mode="k"})

local style = GAMESTATE:GetCurrentStyle()
local numColumns = style and style:ColumnsPerPlayer() or 4
local columns = {}
for i=1,numColumns do
	local ok, info = pcall(function() return style:GetColumnInfo(PLAYER_1, i) end)
	columns[i] = ok and info or {Name="Up"}
end

local spacing = math.min(46, (previewW-28)/math.max(1,numColumns))
local firstX = previewW/2 - (numColumns-1)*spacing/2
local noteZoom = math.min(0.53, spacing/64)

local function fallbackActor(element, name)
	local tint = element == "Tap Mine" and color("#222222") or color("#ed1c24")
	return Def.Quad{
		Name=name,
		InitCommand=function(self)
			self:zoomto(element == "Receptor" and 42 or 30, element == "Receptor" and 5 or 30)
				:diffuse(tint):diffusealpha(element == "Receptor" and 0.45 or 0.9)
		end,
	}
end

local function loadCel(columnName, element, name)
	if not NOTESKIN:DoesNoteSkinExist(noteskin) then return fallbackActor(element, name) end
	local ok, actor = pcall(NOTESKIN.LoadActorForNoteSkin, NOTESKIN, columnName, element, noteskin)
	if not ok then return fallbackActor(element, name) end
	actor.Name = name
	return actor
end

local function celTexturePath(columnName, element)
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
		{{-half,top,0}, tint, {0,textureTop}},
		{{ half,top,0}, tint, {1,textureTop}},
		{{ half,bottom,0}, tint, {1,textureBottom}},
		{{-half,bottom,0}, tint, {0,textureBottom}},
	}, textureBottom
end

local function holdTailVertices(width, top, length, textureRow)
	local half = width/2
	local tint = {1,1,1,1}
	return {
		{{-half,top,0}, tint, {0,textureRow}},
		{{ half,top,0}, tint, {1,textureRow}},
		{{0,top+length,0}, tint, {0.5,textureRow}},
	}
end

local function readFile(path)
	if not path or path == "" then return nil end
	if fileCache[path] ~= nil then return fileCache[path] or nil end
	local file = RageFileUtil.CreateRageFile()
	local contents
	if file:Open(path, 1) then contents = file:Read() end
	file:destroy()
	fileCache[path] = contents or false
	return contents
end

local function mixedCase(value)
	local pattern = {}
	for character in value:gmatch(".") do
		pattern[#pattern+1] = "["..character:upper()..character:lower().."]"
	end
	return table.concat(pattern)
end

local function trim(value)
	return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizeDifficulty(value)
	value = trim(value):gsub("[^%a]", ""):lower()
	if value == "expert" or value == "oni" or value == "maniac" then return "challenge" end
	if value == "basic" then return "easy" end
	if value == "another" or value == "trick" then return "medium" end
	return value
end

local function extractNoteData(steps, player)
	if not steps or not steps.GetFilename then return nil end
	local filename = steps:GetFilename()
	local contents = readFile(filename)
	if not contents then return nil end
	local extension = filename:match("%.([^%.]+)$")
	extension = extension and extension:lower() or ""
	local targetType = ToEnumShortString(steps:GetStepsType()):gsub("_", "-"):lower()
	local targetDifficulty = normalizeDifficulty(ToEnumShortString(steps:GetDifficulty()))
	local targetDescription = trim(steps:GetDescription())
	local noteData

	local NOTES = mixedCase("NOTES")
	if extension == "ssc" then
		local NOTEDATA = mixedCase("NOTEDATA")
		local STEPSTYPE = mixedCase("STEPSTYPE")
		local DIFFICULTY = mixedCase("DIFFICULTY")
		local DESCRIPTION = mixedCase("DESCRIPTION")
		for block in contents:gmatch("#"..NOTEDATA..".-#"..NOTES.."2?:[^;]*") do
			local stepsType = trim(block:match("#"..STEPSTYPE..":(.-);") or ""):lower()
			local difficulty = normalizeDifficulty(block:match("#"..DIFFICULTY..":(.-);") or "")
			local description = trim(block:match("#"..DESCRIPTION..":(.-);") or "")
			if stepsType == targetType and difficulty == targetDifficulty
				and (difficulty ~= "edit" or description == targetDescription) then
				noteData = block:match("#"..NOTES.."2?:%s*([^;]*)")
				break
			end
		end
	elseif extension == "sm" then
		for block in contents:gmatch("#"..NOTES.."2?[^;]*") do
			local parts = {}
			for part in (block..":"):gmatch("([^:]*):") do parts[#parts+1] = part end
			if #parts >= 7 then
				local stepsType = parts[2]:gsub("[^%w-]", ""):lower()
				local difficulty = normalizeDifficulty(parts[4])
				local description = trim(parts[3])
				if stepsType == targetType and difficulty == targetDifficulty
					and (difficulty ~= "edit" or description == targetDescription) then
					noteData = parts[7]
					break
				end
			end
		end
	end

	if not noteData then return nil end
	noteData = noteData:gsub("//[^\r\n]*", "")
	local split = noteData:find("&", 1, true)
	if split then
		noteData = player == PLAYER_2 and noteData:sub(split+1) or noteData:sub(1,split-1)
	end
	return noteData
end

local function elapsedAt(timing, beat)
	local ok, seconds = pcall(function() return timing:GetElapsedTimeFromBeat(beat) end)
	return ok and tonumber(seconds) or nil
end

local function parseChart(steps, player, yieldWork, previewEnd)
	local raw = extractNoteData(steps, player)
	if not raw then return nil, nil end
	-- Reading/extracting the simfile is the only indivisible part of the job.  Yield
	-- immediately afterwards so note conversion never lands in that same frame.
	if yieldWork then yieldWork() end
	local timing = steps:GetTimingData()
	if not timing then return nil, nil end
	local notes, holds = {}, {}
	local openHolds = {}
	local measureIndex = 0
	local rowsSinceYield = 0
	for measure in (raw..","):gmatch("(.-),") do
		local rows = {}
		for row in measure:gmatch("[^\r\n]+") do
			row = trim(row)
			if row ~= "" and row ~= ";" then rows[#rows+1] = row:gsub(";", "") end
		end
		local rowCount = #rows
		local pastPreview = false
		if rowCount > 0 then
			for rowIndex, row in ipairs(rows) do
				local beat = measureIndex*4 + (rowIndex-1)*4/rowCount
				local seconds = elapsedAt(timing, beat)
				if seconds and previewEnd and seconds > previewEnd then pastPreview = true; break end
				if seconds then
					for column=1,math.min(numColumns,#row) do
						local value = row:sub(column,column):upper()
						if value == "1" or value == "M" or value == "L" or value == "F" then
							local kind = value == "M" and "mine" or (value == "L" and "lift" or (value == "F" and "fake" or "tap"))
							notes[#notes+1] = {column=column, time=seconds, beat=beat, kind=kind}
						elseif value == "2" or value == "4" then
							openHolds[column] = {column=column, startTime=seconds, beat=beat, kind=value == "4" and "roll" or "hold"}
						elseif value == "3" and openHolds[column] then
							local hold = openHolds[column]
							hold.endTime = seconds
							hold.endBeat = beat
							holds[#holds+1] = hold
							openHolds[column] = nil
						end
					end
				end
				rowsSinceYield = rowsSinceYield + 1
				if yieldWork and rowsSinceYield >= 64 then
					rowsSinceYield = 0
					yieldWork()
				end
			end
		end
		measureIndex = measureIndex + 1
		if pastPreview then break end
		if yieldWork and rowsSinceYield > 0 and measureIndex % 4 == 0 then
			rowsSinceYield = 0
			yieldWork()
		end
	end
	-- Notes are appended in measure/row order already.  Holds can close out of
	-- start order, so only that much smaller collection needs sorting.
	if yieldWork then yieldWork() end
	table.sort(holds, function(a,b) return a.beat < b.beat end)
	if yieldWork then yieldWork() end
	return notes, holds
end

local function cachedParse(chart, player)
	local chartCache = parseCache[chart]
	return chartCache and chartCache[player] or nil
end

local function storeParse(chart, player, notes, holds)
	local chartCache = parseCache[chart] or {}
	chartCache[player] = {notes=notes, holds=holds}
	parseCache[chart] = chartCache
end

local function lowerBound(notes, target)
	local low, high = 1, #notes+1
	while low < high do
		local middle = math.floor((low+high)/2)
		if middle <= #notes and notes[middle].beat < target then low = middle+1 else high = middle end
	end
	return low
end

local function playCrossingEffects(self, previousBeat, currentBeat)
	if not previousBeat or currentBeat < previousBeat or currentBeat-previousBeat > 2 then return end
	local hitColumns = {}
	local firstNote = lowerBound(self.notes or {}, previousBeat+0.001)
	for i=firstNote,#(self.notes or {}) do
		local note = self.notes[i]
		if note.beat > currentBeat then break end
		if note.kind ~= "mine" and note.kind ~= "fake" then hitColumns[note.column] = true end
	end
	local firstHold = lowerBound(self.holds or {}, previousBeat+0.001)
	for i=firstHold,#(self.holds or {}) do
		local hold = self.holds[i]
		if hold.beat > currentBeat then break end
		hitColumns[hold.column] = true
	end
	for column in pairs(hitColumns) do
		self:GetChild("Receptor_"..column):playcommand("Hit")
		self:GetChild("HitFlash_"..column):playcommand("Hit")
	end
end

local function yAt(noteBeat, currentBeat, pixelsPerBeat)
	return receptorY + (noteBeat-currentBeat)*pixelsPerBeat
end

local function rhythmOffset(beat)
	local divisions = {1, 2, 3, 4, 6, 8, 12, 16}
	for index, division in ipairs(divisions) do
		local row = beat * division
		if math.abs(row - math.floor(row + 0.5)) < 0.001 then return (index-1) * 0.03125 end
	end
	return 7 * 0.03125
end

local function setRhythm(actor, beat)
	local visual = actor and actor:GetChild("Visual")
	if visual and visual.texturetranslate then visual:texturetranslate(rhythmOffset(beat or 0), 0) end
end

local function updateSourceLabel(self, player, chart)
	local label = self:GetChild("SourceLabel")
	if not label then return end
	if GAMESTATE:IsCourseMode() then
		label:settext("CHART PREVIEW UNAVAILABLE IN COURSE MODE"):diffuse(H.Muted)
	elseif not chart then
		label:settext("SELECT A SONG TO PREVIEW ITS CHART"):diffuse(H.Muted)
	elseif self.pendingParse or self.parseJob then
		label:settext(H.PlayerName(player).."   -   LOADING CEL PREVIEW"):diffuse(H.Muted)
	elseif not self.notes then
		label:settext("CHART PREVIEW DATA UNAVAILABLE"):diffuse(H.Muted)
	else
		local same = H.Chart(PLAYER_1) == H.Chart(PLAYER_2) and GAMESTATE:IsHumanPlayer(PLAYER_1) and GAMESTATE:IsHumanPlayer(PLAYER_2)
		local source = same and (H.PlayerName(PLAYER_1).." + "..H.PlayerName(PLAYER_2)) or H.PlayerName(player)
		label:settext(source.."   -   M600 CEL CHART PREVIEW"):diffuse(H.White)
	end
end

local function beginParse(self)
	local pending = self.pendingParse
	if not pending then return end
	self.pendingParse = nil
	local song = GAMESTATE:GetCurrentSong()
	local sampleStart = song and song.GetSampleStart and song:GetSampleStart() or 0
	local sampleLength = song and song.GetSampleLength and song:GetSampleLength() or 15
	local previewEnd = sampleStart + math.max(15, tonumber(sampleLength) or 0) + 8
	self.parseJob = coroutine.create(function()
		local notes, holds = parseChart(pending.chart, pending.player, coroutine.yield, previewEnd)
		storeParse(pending.chart, pending.player, notes, holds)
		if self.parseGeneration == pending.generation and self.previewChart == pending.chart then
			self.notes, self.holds = notes, holds
		end
	end)
end

local af = Def.ActorFrame{
	Name="ChartPreview",
	InitCommand=function(self)
		self:xy(250,82)
		self.pools = {tap={}, mine={}, lift={}, hold={}}
		for column=1,numColumns do
			self.pools.tap[column], self.pools.mine[column] = {}, {}
			self.pools.lift[column], self.pools.hold[column] = {}, {}
			for i=1,tapPoolSize do self.pools.tap[column][i] = self:GetChild("Tap_"..column.."_"..i) end
			for i=1,minePoolSize do self.pools.mine[column][i] = self:GetChild("Mine_"..column.."_"..i) end
			for i=1,liftPoolSize do self.pools.lift[column][i] = self:GetChild("Lift_"..column.."_"..i) end
			for i=1,holdPoolSize do self.pools.hold[column][i] = self:GetChild("Hold_"..column.."_"..i) end
		end
		self.previewClock = 0
		self.lastPreviewBeat = nil
		self.previewWarmupFrames = 0
		self.previewRevealPending = false
		self.parseGeneration = 0
		self:queuecommand("Refresh")
		self:SetUpdateFunction(function(frame, delta) frame:playcommand("Advance", {Delta=delta}) end)
	end,
	RefreshCommand=function(self)
		local isSong = H.Item() ~= nil and not GAMESTATE:IsCourseMode()
		self:visible(isSong)
		if not isSong then
			self.parseGeneration = self.parseGeneration + 1
			self.pendingParse, self.parseJob = nil, nil
			self.previewChart, self.notes, self.holds = nil, nil, nil
			return
		end
		local player, chart = H.PreviewSource()
		local sourceChanged = player ~= self.previewPlayer
		local chartChanged = chart ~= self.previewChart or sourceChanged
		self.previewPlayer = player
		if chartChanged then
			-- Keep the whole preview effectively hidden while the new chart is
			-- parsed and its CEL textures receive their first draw call.
			self:GetParent():stoptweening():diffusealpha(0.001)
			self.previewClock = 0
			self.lastPreviewBeat = nil
			self.previewWarmupFrames = 0
			self.previewRevealPending = false
			self.previewTiming = chart and chart:GetTimingData() or nil
			self.pixelsPerBeat = spacing
			if self.previewTiming then
				-- Use the chart's declared display ceiling as the M-mod reference,
				-- matching what the player is told the chart speed is.  The timing
				-- clock below still uses the real BPM segments, stops and warps.
				-- This prevents intentionally absurd gimmick BPMs (for example 9001)
				-- from compressing the entire preview into an unreadable note wall.
				local okDisplay, displayBpms = pcall(function() return chart:GetDisplayBpms() end)
				local maxBpm = okDisplay and type(displayBpms) == "table" and tonumber(displayBpms[2]) or nil
				if not maxBpm or maxBpm <= 0 then
					local okActual, actualBpms = pcall(function() return self.previewTiming:GetActualBPM() end)
					maxBpm = okActual and type(actualBpms) == "table" and tonumber(actualBpms[2]) or nil
				end
				self.pixelsPerBeat = spacing * mMod / math.max(1, maxBpm or mMod)
			end
			self.parseGeneration = self.parseGeneration + 1
			self.previewChart = chart
			self.pendingParse, self.parseJob = nil, nil
			self.notes, self.holds = nil, nil
			local cached = chart and cachedParse(chart, player) or nil
			if cached then
				self.notes, self.holds = cached.notes, cached.holds
				self.previewWarmupFrames = 2
				self.previewRevealPending = true
			elseif chart then
				-- Do not read or cache transient charts while the wheel is moving.
				self.parseDelay = 0.35
				self.pendingParse = {chart=chart, player=player, generation=self.parseGeneration}
			else
				self:GetParent():diffusealpha(1)
			end
		end
		updateSourceLabel(self, player, chart)
	end,
	AdvanceCommand=function(self, params)
		self.previewClock = self.previewClock + (params.Delta or 0)
		if self.pendingParse then
			self.parseDelay = (self.parseDelay or 0) - (params.Delta or 0)
			if self.parseDelay <= 0 then beginParse(self) end
		end
		if self.parseJob then
			local ok, errorMessage = coroutine.resume(self.parseJob)
			if not ok then
				Trace("VOLT26 chart preview parser: "..tostring(errorMessage))
				self.parseJob = nil
				self.previewRevealPending = true
			elseif coroutine.status(self.parseJob) == "dead" then
				self.parseJob = nil
				-- Do not run Refresh here: it used to reset previewClock exactly as
				-- the notes appeared, producing the visible start hitch/jump.
				self.previewWarmupFrames = 2
				self.previewRevealPending = true
				self.lastPreviewBeat = nil
				updateSourceLabel(self, self.previewPlayer, self.previewChart)
			end
		end
		for _, poolType in pairs(self.pools) do
			for column=1,numColumns do
				for _, actor in ipairs(poolType[column]) do actor:visible(false) end
			end
		end
		local warming = self.previewWarmupFrames and self.previewWarmupFrames > 0
		if warming then
			self.previewWarmupFrames = self.previewWarmupFrames - 1
		elseif self.previewRevealPending then
			self.previewRevealPending = false
			self:GetParent():stoptweening():decelerate(0.30):diffusealpha(1)
		end
		if not self.notes or not self.previewTiming then return end

		local ok, current = pcall(function() return GAMESTATE:GetCurMusicSeconds() end)
		current = ok and tonumber(current) or nil
		local song = GAMESTATE:GetCurrentSong()
		local sampleStart = song and song.GetSampleStart and song:GetSampleStart() or 0
		if not current or current < -2 or (sampleStart > 4 and current < sampleStart-2) then
			current = sampleStart + self.previewClock
		end
		local okBeat, currentBeat = pcall(function() return self.previewTiming:GetBeatFromElapsedTime(current) end)
		currentBeat = okBeat and tonumber(currentBeat) or nil
		if not currentBeat then return end
		if not warming then playCrossingEffects(self, self.lastPreviewBeat, currentBeat) end
		self.lastPreviewBeat = currentBeat
		local pixelsPerBeat = self.pixelsPerBeat or spacing
		local lastVisibleBeat = currentBeat + (bottomY-receptorY)/pixelsPerBeat

		local used = {tap={}, mine={}, lift={}, hold={}}
		for kind in pairs(used) do for column=1,numColumns do used[kind][column]=0 end end
		local first = lowerBound(self.notes, currentBeat+0.001)
		for i=first,#self.notes do
			local note = self.notes[i]
			if note.beat > lastVisibleBeat then break end
			local poolKind = note.kind == "mine" and "mine" or (note.kind == "lift" and "lift" or "tap")
			used[poolKind][note.column] = used[poolKind][note.column] + 1
			local actor = self.pools[poolKind][note.column][used[poolKind][note.column]]
			if actor then
				actor:visible(true):xy(firstX+(note.column-1)*spacing,yAt(note.beat,currentBeat,pixelsPerBeat)):zoom(noteZoom)
					:diffusealpha(note.kind == "fake" and 0.38 or 1)
				setRhythm(actor, note.beat)
			end
		end

		for _, hold in ipairs(self.holds or {}) do
			if hold.endBeat and hold.endBeat >= currentBeat and hold.beat <= lastVisibleBeat then
				local column = hold.column
				used.hold[column] = used.hold[column] + 1
				local actor = self.pools.hold[column][used.hold[column]]
				if actor then
					local rawStartY = yAt(hold.beat,currentBeat,pixelsPerBeat)
					local rawEndY = yAt(hold.endBeat,currentBeat,pixelsPerBeat)
					local startY = math.max(receptorY,rawStartY)
					local endY = math.min(bottomY,rawEndY)
					if endY >= receptorY and startY <= bottomY and endY > startY then
						local isRoll = hold.kind == "roll"
						local head = actor:GetChild(isRoll and "RollHead" or "HoldHead")
						local body = actor:GetChild(isRoll and "RollBody" or "HoldBody")
						local tail = actor:GetChild(isRoll and "RollTail" or "HoldTail")
						actor:visible(true):x(firstX+(column-1)*spacing)
						for _, name in ipairs({"HoldBody","HoldHead","HoldTail","RollBody","RollHead","RollTail"}) do
							actor:GetChild(name):visible(false)
						end
						local active = hold.beat <= currentBeat+0.001
						local headY = active and receptorY or startY
						local texture = body:GetTexture()
						local textureHeight = texture and texture:GetSourceHeight() or (isRoll and 256 or 128)
						local bodyWidth = 64*noteZoom
						local bodyVertices, textureBottom = holdBodyVertices(bodyWidth,headY,endY,textureHeight)
						body:visible(true):SetNumVertices(4):SetVertices(bodyVertices)
						head:visible(true):y(headY):zoom(noteZoom):diffusealpha(active and 0.82 or 1)
						local capHeight = math.min(18*noteZoom, bottomY-rawEndY)
						local showTail = rawEndY <= bottomY and rawEndY >= receptorY and capHeight > 0
						tail:visible(showTail)
						if showTail then
							tail:SetNumVertices(3):SetVertices(holdTailVertices(bodyWidth,rawEndY,capHeight,textureBottom))
						end
						if head.texturetranslate then head:texturetranslate(rhythmOffset(hold.beat or 0), 0) end
					end
				end
			end
		end
	end,
	CurrentSongChangedMessageCommand=function(self) self.previewChart=nil; self:queuecommand("Refresh") end,
	CurrentStepsP1ChangedMessageCommand=function(self) H.LastStepsPlayer=PLAYER_1; self:queuecommand("Refresh") end,
	CurrentStepsP2ChangedMessageCommand=function(self) H.LastStepsPlayer=PLAYER_2; self:queuecommand("Refresh") end,
	PlayerJoinedMessageCommand=function(self) self:queuecommand("Refresh") end,
	PlayerUnjoinedMessageCommand=function(self) self:queuecommand("Refresh") end,
	VOLT26SongSelectRefreshMessageCommand=function(self) self:queuecommand("Refresh") end,
}

af[#af+1] = Def.BitmapText{
	Name="SourceLabel", Font=H.FontBold,
	InitCommand=function(self) self:xy(previewW/2,0):horizalign(center):zoom(H.BoldZoom(0.034)):diffuse(H.White):maxwidth((previewW-16)/H.BoldZoom(0.034)) end,
}

for column=1,numColumns do
	local columnName = columns[column].Name or "Up"
	local x = firstX+(column-1)*spacing
	af[#af+1] = Def.ActorFrame{
		Name="Receptor_"..column,
		InitCommand=function(self) self:xy(x,receptorY):zoom(noteZoom):diffusealpha(0.72) end,
		HitCommand=function(self)
			self:stoptweening():zoom(noteZoom*1.18):diffusealpha(1)
				:decelerate(0.10):zoom(noteZoom):diffusealpha(0.72)
		end,
		loadCel(columnName, "Receptor"),
	}
	af[#af+1] = Def.ActorFrame{
		Name="HitFlash_"..column,
		InitCommand=function(self) self:xy(x,receptorY):zoom(noteZoom*0.75):diffusealpha(0) end,
		HitCommand=function(self)
			self:stoptweening():zoom(noteZoom*0.75):diffusealpha(0.85)
				:decelerate(0.14):zoom(noteZoom*1.28):diffusealpha(0)
		end,
		loadCel(columnName, "Tap Explosion Dim W1"),
	}
	for i=1,tapPoolSize do
		af[#af+1] = Def.ActorFrame{
			Name="Tap_"..column.."_"..i,
			InitCommand=function(self) self:visible(false) end,
			loadCel(columnName, "Tap Note", "Visual"),
		}
	end
	for i=1,minePoolSize do
		af[#af+1] = Def.ActorFrame{
			Name="Mine_"..column.."_"..i,
			InitCommand=function(self) self:visible(false) end,
			loadCel(columnName, "Tap Mine", "Visual"),
		}
	end
	for i=1,liftPoolSize do
		af[#af+1] = Def.ActorFrame{
			Name="Lift_"..column.."_"..i,
			InitCommand=function(self) self:visible(false) end,
			loadCel(columnName, "Tap Lift", "Visual"),
		}
	end
	for i=1,holdPoolSize do
		af[#af+1] = Def.ActorFrame{
			Name="Hold_"..column.."_"..i,
			InitCommand=function(self) self:visible(false) end,
			Def.ActorMultiVertex{
				Name="HoldBody", Texture=celTexturePath(columnName, "Hold Body Inactive"),
				InitCommand=function(self) self:SetDrawState({Mode="DrawMode_Quads"}):texturewrapping(true):visible(false) end,
			},
			loadCel(columnName, "Hold Head Inactive", "HoldHead"),
			Def.ActorMultiVertex{
				Name="HoldTail", Texture=celTexturePath(columnName, "Hold Body Inactive"),
				InitCommand=function(self) self:SetDrawState({Mode="DrawMode_Triangles"}):texturewrapping(true):visible(false) end,
			},
			Def.ActorMultiVertex{
				Name="RollBody", Texture=celTexturePath(columnName, "Roll Body Inactive"),
				InitCommand=function(self) self:SetDrawState({Mode="DrawMode_Quads"}):texturewrapping(true):visible(false) end,
			},
			loadCel(columnName, "Roll Head Inactive", "RollHead"),
			Def.ActorMultiVertex{
				Name="RollTail", Texture=celTexturePath(columnName, "Roll Body Inactive"),
				InitCommand=function(self) self:SetDrawState({Mode="DrawMode_Triangles"}):texturewrapping(true):visible(false) end,
			},
		}
	end
end

return af
