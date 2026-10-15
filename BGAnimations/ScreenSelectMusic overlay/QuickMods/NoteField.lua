local args = ...
local L = args.L
local player = args.Player
local shared = args.Sources
local Sources = args.SourcesModule
local receptorY = args.ReceptorY
local reverseY = args.ReverseY
local bottomY = args.BottomY
local topY = args.TopY
local pn = ToEnumShortString(player)

-- The live preview: this player's note field, at the size gameplay draws it,
-- scrolling the demonstration chart at whatever the list currently says.
--
-- Everything here is laid out around x = 0, because the frame this returns is
-- the one the panel tilts: the engine rotates the whole note field about the
-- player's own centre, so that centre has to be this frame's origin rather than
-- a number baked into every note.
--
-- Nothing reads the selected song's steps.  The point of the picture is to
-- answer "can I read this", and that question is answered by a chart the player
-- has seen before -- same shape every time, denser as the difficulty they have
-- chosen rises -- rather than by whichever sixteen bars the song's preview
-- marker happens to point at.

-- Gameplay draws one arrow per 64 engine units.  The overlay is laid out in
-- design units and scaled by L.Scale to reach those engine units, so undoing
-- that scale is what puts a preview arrow at its gameplay size whatever the
-- engine's own resolution is.
local designLane = 64 / L.Scale

local demoBpm = VOLT26.DemoChart.Bpm
local columns = Sources.Columns()
local columnCount = #columns
local maxNotes = VOLT26.DemoChart.MaxNotes()
local holdPool = 2
local minePool = 4

local function miniScale()
	local value = tonumber((tostring(VOLT26.Options.GetPlayerModifiers(player).Mini or "0%"):gsub("%%", "")))
	return math.max(0.2, 1 - (value or 0)/100)
end

local function noteSkin()
	local mods = VOLT26.Options.GetPlayerModifiers(player)
	local chosen = mods.NoteSkinVariant or mods.NoteSkin
	if type(chosen) == "string" and chosen ~= "" then return chosen end
	local ok, engine = pcall(function()
		return GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred"):NoteSkin()
	end)
	return ok and engine or nil
end

-- The ceiling the selected chart declares, which is what an M-mod is measured
-- against.  Without one, an M-mod is read as the demo's own tempo so the
-- preview still moves.
local function songCeilingBpm()
	local chart = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player)
		or GAMESTATE:GetCurrentSteps(player)
	if not chart then return demoBpm end
	local ok, bpms = pcall(function()
		return GetDisplayBPMs(player, chart, VOLT26.MusicSelection.GetMusicRate())
	end)
	local ceiling = ok and type(bpms) == "table" and tonumber(bpms[2]) or nil
	if ceiling and ceiling > 0 then return ceiling end
	return demoBpm
end

-- Reverse turns the field upside down without turning the arrows: the
-- receptors stand where ScreenGameplay puts reversed ones and every note is
-- measured from them upwards instead of downwards.
local function reversed()
	return VOLT26.Options.IsReverse(player)
end

-- Pixels per demo beat.  An x-mod is a multiple of the 1x beat pitch; an m-mod
-- is the same thing once the selected chart's ceiling has resolved it; a c-mod
-- is a constant number of pixels per second, which on a chart of a known tempo
-- is also a constant per beat.  The bounds only catch a setting that would
-- otherwise draw a solid wall or a single arrow.
local function pitchFor(lane)
	local mods = VOLT26.Options.GetPlayerModifiers(player)
	local kind = mods.SpeedModType or "X"
	local speed = tonumber(mods.SpeedMod) or 1
	local multiplier
	if kind == "C" then
		multiplier = speed / demoBpm
	elseif kind == "M" then
		multiplier = speed / songCeilingBpm()
	else
		multiplier = speed
	end
	return math.max(lane * 0.35, math.min(lane * 9, lane * multiplier))
end

local function sourceActor(key)
	local frame = shared.Frame
	return frame and frame:GetChild(key) or nil
end

local function targetProxy(proxy, key)
	local source = sourceActor(key)
	if not source then
		proxy:visible(false)
		return false
	end
	if proxy.quickModsTarget ~= key then
		proxy:SetTarget(source)
		proxy.quickModsTarget = key
	end
	return true
end

-- --------------------------------------------------------------------- holds
--
-- A hold is the skin's own body texture tiled between its head and its end,
-- the way NoteDisplay lays one out, rather than a coloured bar: the body is
-- most of what a player looks at when they are judging whether they can read a
-- chart, and a bar says nothing about the skin they just chose.

local function holdTexture(skin, column, element)
	local ok, path = pcall(NOTESKIN.GetPathForNoteSkin, NOTESKIN, columns[column], element, skin)
	if ok and type(path) == "string" and path ~= "" then return path end
	return nil
end

local function loadTexture(actor, path)
	if not path then return false end
	if actor.quickModsPath ~= path then
		local ok = pcall(function() actor:LoadTexture(path) end)
		actor.quickModsPath = ok and path or nil
	end
	return actor.quickModsPath ~= nil
end

local function textureHeight(actor, fallback)
	local ok, height = pcall(function() return actor:GetTexture():GetSourceHeight() end)
	return (ok and tonumber(height) and height > 0) and height or fallback
end

-- The body is anchored on its end rather than on its head, so the tile boundary
-- lands where the hold finishes instead of drifting as the hold scrolls.
local function bodyVertices(width, top, bottom, repeats)
	local last = math.ceil(repeats - 0.0001)
	local first = last - repeats
	local half = width/2
	local tint = {1, 1, 1, 1}
	return {
		{{-half, top,    0}, tint, {0, first}},
		{{ half, top,    0}, tint, {1, first}},
		{{ half, bottom, 0}, tint, {1, last}},
		{{-half, bottom, 0}, tint, {0, last}},
	}, last
end

local function capVertices(width, top, height, row)
	local half = width/2
	local tint = {1, 1, 1, 1}
	return {
		{{-half, top,          0}, tint, {0,   row}},
		{{ half, top,          0}, tint, {1,   row}},
		{{ 0,    top + height, 0}, tint, {0.5, row}},
	}
end

-- --------------------------------------------------------------------- draw

local function draw(self)
	if not self.notes then return end
	local skin = noteSkin()
	if not skin then return end

	local scale = miniScale()
	local lane = designLane * scale
	-- A sample is built at the skin's own 64 unit size, so the zoom that puts it
	-- on a lane of this width is the ratio between the two.
	local zoom = lane/64
	local pitch = pitchFor(lane)

	-- Every position below is a distance from the receptors along the scroll;
	-- `at` turns one into a y on the screen and `reach` is the farthest a note
	-- can be and still be on it.
	local rev = reversed()
	local origin = rev and reverseY or receptorY
	local direction = rev and -1 or 1
	local reach = rev and (origin - topY) or (bottomY - origin)
	local function at(distance) return origin + direction*distance end
	local laneOrigin = -(columnCount - 1)*lane/2
	local function laneX(column) return laneOrigin + (column - 1)*lane end

	for column = 1, columnCount do
		local receptor = self:GetChild("Receptor_"..column)
		if targetProxy(receptor, Sources.Key(skin, column, "receptor")) then
			receptor:visible(true):xy(laneX(column), origin):zoom(zoom):diffusealpha(0.55)
		end
	end

	local loopBeats = self.loopBeats
	local now = ((self.clock or 0) * demoBpm/60) % loopBeats

	local function relative(beat)
		local value = beat - now
		if value < 0 then value = value + loopBeats end
		return value
	end

	local used, usedMines = 0, 0
	for _, note in ipairs(self.notes) do
		local distance = relative(note.Beat) * pitch
		local mine = note.Kind == "mine"
		local index = mine and (usedMines + 1) or (used + 1)
		local proxy = self:GetChild((mine and "Mine_" or "Tap_")..index)
		if proxy and distance <= reach then
			local key = mine and Sources.Key(skin, note.Column, "mine")
				or Sources.Key(skin, note.Column, "tap", note.Quantization)
			if targetProxy(proxy, key) then
				proxy:visible(true):xy(laneX(note.Column), at(distance)):zoom(zoom)
			end
			if mine then usedMines = index else used = index end
		elseif proxy then
			proxy:visible(false)
			if mine then usedMines = index else used = index end
		end
	end
	for i = used + 1, maxNotes do self:GetChild("Tap_"..i):visible(false) end
	for i = usedMines + 1, minePool do self:GetChild("Mine_"..i):visible(false) end

	for i = 1, holdPool do
		local hold = self.holds[i]
		local body = self:GetChild("HoldBody_"..i)
		local cap = self:GetChild("HoldCap_"..i)
		local head = self:GetChild("HoldHead_"..i)
		body:visible(false)
		cap:visible(false)
		head:visible(false)
		if hold then
			local lengthBeats = hold.EndBeat - hold.Beat
			local startBeat = relative(hold.Beat)
			local startD, endD
			if startBeat > loopBeats - lengthBeats then
				-- The head has gone past the receptors: the hold is being held,
				-- so it stands on them the way gameplay draws an active one.
				startD = 0
				endD = (startBeat - loopBeats + lengthBeats) * pitch
			else
				startD = startBeat * pitch
				endD = startD + lengthBeats * pitch
			end
			local drawnEnd = math.min(endD, reach)
			if drawnEnd > startD and startD <= reach then
				local x = laneX(hold.Column)
				local bodyLoaded = loadTexture(body,
					holdTexture(skin, hold.Column, "Hold Body Inactive"))
				if bodyLoaded then
					local height = textureHeight(body, 128)
					local repeats = (drawnEnd - startD) / math.max(1, height * zoom)
					-- Reversed, the head is the lower end: the body's texture
					-- runs the other way up, as the engine flips it.
					local vertices, lastRow = bodyVertices(lane, at(startD), at(drawnEnd), repeats)
					body:visible(true):x(x):SetNumVertices(#vertices):SetVertices(vertices)

					-- The cap closes the hold off, and only when its end is on
					-- screen: past the bottom there is nothing to close.
					local capLoaded = loadTexture(cap,
						holdTexture(skin, hold.Column, "Hold BottomCap Inactive"))
					local capHeight = math.min(18 * zoom, reach - endD)
					if capLoaded and endD <= reach and capHeight > 0 then
						local capShape = capVertices(lane, at(endD), direction*capHeight, lastRow)
						cap:visible(true):x(x):SetNumVertices(#capShape):SetVertices(capShape)
					end
				else
					-- A skin that builds its body out of something other than a
					-- texture -- a Lua actor, say -- leaves the head standing on
					-- its own rather than a bar that belongs to no skin.
					body:visible(false)
				end

				if targetProxy(head, Sources.Key(skin, hold.Column, "holdhead")) then
					head:visible(true):xy(x, at(startD)):zoom(zoom)
				end
			end
		end
	end
end

-- -------------------------------------------------------------------- frame

local af = Def.ActorFrame{
	Name = pn.."QuickModsNoteField",
	RefreshCommand = function(self)
		local chart = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player)
			or GAMESTATE:GetCurrentSteps(player)
		local difficulty = chart and chart:GetDifficulty() or "Difficulty_Medium"
		self.notes, self.holds, self.loopBeats = VOLT26.DemoChart.Build(difficulty)
		draw(self)
	end,
	VOLT26QuickModsChangedMessageCommand = function(self)
		if self.notes then draw(self) end
	end,
	-- The preview is built and animated only while the menu is open: the
	-- update function that lays out its notes every frame is installed on
	-- Show and removed on Hide (it used to run, hidden, for the whole of
	-- Song Select, and the preview was built on the screen's first frame).
	ShowQuickModsCommand = function(self)
		self.clock = 0
		self:playcommand("Refresh")
		self:SetUpdateFunction(function(frame, delta)
			if not frame:GetVisible() then return end
			frame.clock = (frame.clock or 0) + (delta or 0)
			draw(frame)
		end)
	end,
	HideQuickModsCommand = function(self) self:SetUpdateFunction(nil) end,
}

for column = 1, columnCount do
	af[#af+1] = Def.ActorProxy{
		Name = "Receptor_"..column,
		InitCommand = function(self) self:visible(false) end,
	}
end

-- The bodies are drawn before the taps so a note landing on one sits on top of
-- it, as it does in gameplay.
for i = 1, holdPool do
	af[#af+1] = Def.ActorMultiVertex{
		Name = "HoldBody_"..i,
		InitCommand = function(self)
			self:SetDrawState({Mode="DrawMode_Quads"}):texturewrapping(true):visible(false)
		end,
	}
	af[#af+1] = Def.ActorMultiVertex{
		Name = "HoldCap_"..i,
		InitCommand = function(self)
			self:SetDrawState({Mode="DrawMode_Triangles"}):texturewrapping(true):visible(false)
		end,
	}
	af[#af+1] = Def.ActorProxy{
		Name = "HoldHead_"..i,
		InitCommand = function(self) self:visible(false) end,
	}
end

for i = 1, maxNotes do
	af[#af+1] = Def.ActorProxy{
		Name = "Tap_"..i,
		InitCommand = function(self) self:visible(false) end,
	}
end
for i = 1, minePool do
	af[#af+1] = Def.ActorProxy{
		Name = "Mine_"..i,
		InitCommand = function(self) self:visible(false) end,
	}
end

return af
