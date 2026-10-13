-- ScreenVOLT26SelectPack: the first step of music selection.
--
-- Packs are shown as square jackets on a horizontal carousel.  Left/Right
-- moves one pack, Up/Down jumps five; holding a direction keeps moving at the
-- operator's MusicWheel scroll speed (the MusicWheelSwitchSpeed preference,
-- set in the VOLT26 options), the same speed the song wheel scrolls at.
-- Start opens the focused pack on the song wheel (ScreenSelectMusic).
-- Back on the carousel leaves music selection; in event mode it has to be
-- pressed twice, standing in for the exit prompt the song wheel used to show.
-- The focused pack's name is drawn in the profile screen's cutout lettering
-- (VOLT26.Cutout).
--
-- The pack step and the song wheel are two screens drawn to read as one: the
-- same backdrop, and the chosen jacket travels between them.  The pack step
-- has no header or footer band; the song wheel's fade in and out around it.  Opening a pack shrinks the focused jacket into the
-- song wheel's header badge (K.Badge) while the other jackets slide away;
-- coming back grows it out of the badge into the carousel again.  The screen's
-- out transition only holds (K.HandoffHold) so the motion is not covered.
--
-- Pack data comes from VOLT26.PackSelection; this file owns the actors, the
-- carousel motion and the input.  The carousel recycles a fixed pool of tiles:
-- each tile keeps an offset from the focused slot, and only a tile that wraps
-- from one end of the pool to the other is given a new pack.  Pack artwork is
-- loaded only once the carousel has come to rest, nearest tiles first, so
-- holding a direction never stalls on image decoding.

local K = LoadActor(THEME:GetPathB("", "_volt26 music kit.lua"))
local PackSelection = VOLT26.PackSelection
local scene = LoadActor("./Scene.lua", { K=K })

local packs = PackSelection.List()
local count = #packs
local focus = PackSelection.InitialIndex(packs)

local POOL = 9                 -- tiles in the pool: offsets -4 .. 4
local HALF = (POOL - 1) / 2
-- Tiles are built at K.TileSize (the song wheel badge is the same tile) and
-- zoomed to their slot.
local FOCUS_SIZE = K.TileSize
-- The focused jacket sits in the splash's window (Scene.lua).
local CENTER_X = scene.Focus.X
local CENTER_Y = scene.Focus.Y
local FOCUS_ZOOM = scene.Focus.Size / FOCUS_SIZE
local FOCUS_TILT = scene.Focus.Tilt
-- Neighbours, by distance from the focus: smaller, upright (a turned jacket
-- aliases at its corners), darkened, and partly behind the splash (draw
-- order, see sortTiles).  x/y are relative to the focused slot; tilt is for
-- the right-hand side, mirrored on the left.
-- Only the nearest neighbour on each side is shown (three packs on screen);
-- the further slots are where tiles wait, hidden, to slide in from.
local SHOWN_REACH = 1
local SLOTS = {
	[1] = { x = 560, y = 30, size = 300, tilt = 0, bright = 0.5 },
	[2] = { x = 805, y = 74, size = 210, tilt = 0, bright = 0.3 },
	[3] = { x = 1000, y = 110, size = 160, tilt = 0, bright = 0.2 },
}
local MOVE_SECONDS = 0.14
local JUMP = 5
local HOLD_DELAY = 0.3         -- a held direction starts repeating after this
-- The words under the splash.  The bottom of the screen is left to the credit
-- line (player names and EVENT MODE, drawn by ScreenSystemLayer as on the main
-- menu; ShowCreditDisplay in metrics.ini).
local NAME_Y = 875
local ART_IDLE = 0.08          -- rest before artwork starts loading
local DETAIL_IDLE = 0.12       -- rest before the pack summary is computed
local LOAD_REACH = 1           -- tiles further out are hidden
local EXIT_WINDOW = 2.0        -- event mode: seconds for the second Back

-- The header badge, in the carousel's own coordinates.
local BADGE_X = K.Badge.X
local BADGE_Y = K.Badge.Y - CENTER_Y
local BADGE_ZOOM = K.Badge.Size / FOCUS_SIZE

local root
local tiles = {}
local idle = 0
local detailsDirty = true
local finished = false
local exitArmedAt = nil
local timerSeen = false
local checkTimer = VOLT26.MenuTimer.IsEnabledForSongSelect()
local handoff = PackSelection.TakeHandoff()
local held = nil               -- the direction being held, see Hold()
local moveSeconds = MOVE_SECONDS

-- Packs per second while a direction is held: the operator's MusicWheel
-- scroll speed (ScreenOptionsService, VOLT26.OperatorOptions.MusicWheelSpeed).
local function holdRate()
	local speed = tonumber(PREFSMAN:GetPreference("MusicWheelSwitchSpeed")) or 15
	return math.max(1, speed)
end

local function wrap(index)
	return ((index - 1) % count) + 1
end

-- Where a tile at this offset stands: x, y (carousel coordinates), zoom,
-- rotation, brightness, and whether it is drawn at all (offsets past the
-- second neighbour wait off to the side, hidden).
local function slot(offset)
	if offset == 0 then
		return CENTER_X, 0, FOCUS_ZOOM, FOCUS_TILT, 1, true
	end
	local reach = math.abs(offset)
	local s = SLOTS[math.min(reach, #SLOTS)]
	local side = offset > 0 and 1 or -1
	return CENTER_X + side * s.x, s.y, s.size / FOCUS_SIZE, side * s.tilt, s.bright, reach <= SHOWN_REACH
end

-- With fewer packs than tiles every pack is shown once, around the focus.
local function inWindow(offset)
	if count == 0 then return false end
	if count >= POOL then return true end
	return offset >= -math.floor((count - 1) / 2) and offset <= math.ceil((count - 1) / 2)
end

-- Tiles ---------------------------------------------------------------------

local function setContent(tile)
	local entry = count > 0 and packs[wrap(focus + tile.offset)] or nil
	tile:playcommand("SetPack", { Group = entry and entry.Name or nil })
end

-- The splash frames the focused jacket, so the tile's own focus outline is
-- not used here.
local function setFocusLook(tile)
	tile:GetChild("Body"):GetChild("Frame"):visible(false)
end

-- The focused jacket is drawn in front of the splash (draw order 0), the
-- neighbours behind it, nearer ones over further ones.  A jacket leaving
-- the focus drops behind the splash at once and slides out from under it.
local function sortTiles()
	for _, tile in ipairs(tiles) do
		tile:draworder(tile.offset == 0 and 10 or -math.abs(tile.offset))
	end
	root:GetChild("Carousel"):SortByDrawOrder()
end

local function placeTile(tile, animate)
	local offset = tile.offset
	local x, y, zoom, tilt, bright, shown = slot(offset)
	tile:stoptweening()
	if animate then tile:decelerate(moveSeconds) end
	tile:xy(x, y):zoom(zoom):rotationz(tilt)
		:diffuse(bright, bright, bright, (shown and inWindow(offset)) and 1 or 0)
	setFocusLook(tile)
end

local function focusedTile()
	for _, tile in ipairs(tiles) do
		if tile.offset == 0 then return tile end
	end
	return nil
end

-- Details -------------------------------------------------------------------

-- The name: two cutout slots used alternately, as on the profile screen, so
-- the name on screen stays until its successor has finished rendering.
local names = { slots = {}, active = 1, shown = nil, wanted = nil, pending = nil }

-- The name's size lives in VOLT26.Cutout.StyleDesign.PackName
-- (Scripts/VOLT26_CutoutStyles.lua), shared with the startup warm-up that
-- pre-renders the names of the packs around the one the carousel opens on.
-- Pack names run long ("Anime Stamina Sessions for the Energetically Slow" is
-- 49 characters).  Every character of headroom costs stamp actors in both
-- slots, so the limit (64) is generous but finite; longer names fall back to
-- plain text.
local nameStyle = VOLT26.Cutout.Style("PackName")

local function nameSlot(index)
	return VOLT26.Cutout.CreateSlot{
		-- The slots stand in theme units (NameLayer undoes the design scale),
		-- so their texture matches the screen's pixels.
		maxW = nameStyle.maxW, maxH = nameStyle.maxH, halign = 0.5, valign = 0.5,
		maxChars = nameStyle.maxChars, held = true,
		opts = nameStyle.opts,
		fallbackZoom = VOLT26.Type.DisplayZoom(56 * K.Scale),
		onInit = function(slot) names.slots[index] = slot end,
		onReady = function(slot)
			-- Only the slot being prepared, and only for the name still wanted.
			if slot ~= names.slots[3 - names.active] or names.pending ~= names.wanted then return end
			local outgoing = names.slots[names.active]
			names.active = 3 - names.active
			names.shown = names.wanted
			outgoing:playcommand("CutoutHold", { held = true })
			slot:playcommand("CutoutHold", { held = false })
		end,
	}
end

local function setName(text)
	text = text or ""
	if text == names.wanted then return end
	names.wanted = text
	if text == names.shown then
		names.pending = nil
		return
	end
	names.pending = text
	local slot = names.slots[3 - names.active]
	if slot then slot:playcommand("CutoutSet", { text = text }) end
end

local function refreshName()
	setName(count > 0 and packs[focus].Name or "")
end

-- The summary line is drawn white over eight black copies of itself, nudged
-- around it, which gives it a black stroke (the label font has no stroke
-- layer of its own).
local INFO_PX = 18
local INFO_STROKE = 3
local INFO_OFFSETS = {
	{ -1, -1 }, { 0, -1 }, { 1, -1 }, { -1, 0 }, { 1, 0 }, { -1, 1 }, { 0, 1 }, { 1, 1 },
}

local function setInfo(text)
	local info = root:GetChild("Details"):GetChild("Info")
	for i = 1, #INFO_OFFSETS do
		K.SetLabel(info:GetChild("Stroke" .. i), text, INFO_PX, 1500)
	end
	K.SetLabel(info:GetChild("Text"), text, INFO_PX, 1500)
end

local function refreshDetails()
	if count == 0 then
		setInfo(K.String("NoPacks"))
		return
	end
	local summary = PackSelection.Summary(packs[focus].Name)
	local parts = {}
	local songs = summary.Playable > 0 and summary.Playable or summary.Songs
	parts[#parts+1] = string.format(K.String(songs == 1 and "PackSong" or "PackSongs"), songs)
	if summary.MinMeter and summary.MaxMeter then
		if summary.MinMeter == summary.MaxMeter then
			parts[#parts+1] = string.format(K.String("PackLevel"), summary.MinMeter)
		else
			parts[#parts+1] = string.format(K.String("PackLevels"), summary.MinMeter, summary.MaxMeter)
		end
	end
	setInfo(table.concat(parts, "   /   "))
end

-- Entrances and exits --------------------------------------------------------

-- Coming back from the song wheel: the focused jacket grows out of the header
-- badge into the middle and the rest of the carousel slides in around it.
local function enterFromSongWheel()
	for _, tile in ipairs(tiles) do
		local offset = tile.offset
		local x, y, zoom, tilt, bright, shown = slot(offset)
		if offset == 0 then
			-- It overshoots a little and settles, like a card slapped down.
			tile:stoptweening():xy(BADGE_X, BADGE_Y):zoom(BADGE_ZOOM):rotationz(0):diffuse(1, 1, 1, 1)
				:decelerate(K.HandoffSeconds * 0.8):xy(x, y):zoom(zoom * 1.05):rotationz(tilt)
				:decelerate(K.HandoffSeconds * 0.2):zoom(zoom)
		else
			local side = offset > 0 and 1 or -1
			tile:stoptweening():xy(x + side * 360, y):zoom(zoom):rotationz(tilt)
				:diffuse(bright, bright, bright, 0)
				:sleep(0.08):decelerate(K.HandoffSeconds)
				:x(x):diffusealpha((shown and inWindow(offset)) and 1 or 0)
		end
	end
	local details = root:GetChild("Details")
	details:stoptweening():diffusealpha(0):addy(16):sleep(0.16):decelerate(0.2):diffusealpha(1):addy(-16)
end

local function enterFresh()
	local carousel = root:GetChild("Carousel")
	carousel:diffusealpha(0):addy(24):decelerate(0.25):diffusealpha(1):addy(-24)
end

-- Opening a pack: the focused jacket shrinks into the song wheel's jacket
-- frame, the others slide out to their own side, and the words fade; under
-- it all the song select's scenery builds itself (the background's bridge,
-- ScreenSelectMusic overlay/SongWheel/Scene.lua).
local function leaveToSongWheel()
	for _, tile in ipairs(tiles) do
		local offset = tile.offset
		if offset == 0 then
			tile:GetChild("Body"):GetChild("Frame"):visible(false)
			-- It overshoots into the frame and settles there (never turned:
			-- jackets stay upright).
			tile:stoptweening():decelerate(K.HandoffSeconds * 0.8):xy(BADGE_X, BADGE_Y)
				:zoom(BADGE_ZOOM * 0.92):rotationz(0)
				:decelerate(K.HandoffSeconds * 0.2):zoom(BADGE_ZOOM)
		else
			local side = offset > 0 and 1 or -1
			tile:stoptweening():accelerate(0.22):addx(side * 420):diffusealpha(0)
		end
	end
	root:GetChild("Details"):stoptweening():linear(0.12):diffusealpha(0)
	root:playcommand("SceneLeave")
	MESSAGEMAN:Broadcast("VOLT26PackScene", { Phase = "Leave" })
end

-- Actions -------------------------------------------------------------------

local function play(name)
	local sound = root and root:GetChild(name)
	if sound then sound:play() end
end

local function move(direction, steps)
	if finished or count <= 1 then return end
	steps = steps or 1
	for _ = 1, steps do
		focus = wrap(focus + direction)
		for _, tile in ipairs(tiles) do
			tile.offset = tile.offset - direction
			if tile.offset < -HALF then
				tile.offset = tile.offset + POOL
				setContent(tile)
				placeTile(tile, false)
			elseif tile.offset > HALF then
				tile.offset = tile.offset - POOL
				setContent(tile)
				placeTile(tile, false)
			else
				placeTile(tile, true)
			end
		end
	end
	sortTiles()
	root:playcommand("Bump")
	idle = 0
	detailsDirty = true
	exitArmedAt = nil
	root:GetChild("Notice"):stoptweening():diffusealpha(0)
	refreshName()
	play("Change")
end

local function choose()
	if finished then return end
	if count == 0 or not PackSelection.Choose(packs[focus].Name) then
		play("Invalid")
		return
	end
	finished = true
	held = nil
	play("Start")
	-- The badge in the song wheel header shows the same artwork; make sure the
	-- jacket that flies there already has it.
	local tile = focusedTile()
	if tile and tile.artPending then tile:playcommand("LoadPackArt") end
	PackSelection.SetHandoff("ToSongWheel")
	leaveToSongWheel()
	local screen = SCREENMAN:GetTopScreen()
	screen:SetNextScreenName("ScreenSelectMusic")
	screen:StartTransitioningScreen("SM_GoToNextScreen")
end

local input

local function leave()
	finished = true
	local screen = SCREENMAN:GetTopScreen()
	screen:RemoveInputCallback(input)
	screen:Cancel()
end

local function back()
	if finished then return end
	if not PREFSMAN:GetPreference("EventMode") then
		leave()
		return
	end
	local now = GetTimeSinceStart()
	if exitArmedAt and now - exitArmedAt <= EXIT_WINDOW then
		leave()
		return
	end
	exitArmedAt = now
	play("Invalid")
	root:GetChild("Notice"):stoptweening():diffusealpha(1)
		:sleep(EXIT_WINDOW):linear(0.2):diffusealpha(0)
end

-- A held direction: one move on the press, then after HOLD_DELAY a steady
-- stream at holdRate() packs per second (Up/Down repeat whole jumps at the
-- same pace in packs).  Engine repeat events are not used for this, so the
-- operator's speed setting is what decides the pace.
local function hold(event, direction, steps)
	held = { player = event.PlayerNumber, button = event.GameButton,
		direction = direction, steps = steps, elapsed = 0, owed = 0 }
	moveSeconds = MOVE_SECONDS
	move(direction, steps)
end

local function updateHold(delta)
	if not held or finished then return end
	held.elapsed = held.elapsed + delta
	if held.elapsed < HOLD_DELAY then return end
	local rate = holdRate() / held.steps
	held.owed = held.owed + delta * rate
	local moves = math.floor(held.owed)
	if moves < 1 then return end
	held.owed = held.owed - moves
	-- Each glide has to finish before the next one starts.
	moveSeconds = math.min(MOVE_SECONDS, 0.9 / holdRate())
	move(held.direction, moves * held.steps)
end

input = function(event)
	if finished or not event or not event.PlayerNumber then return false end
	if not GAMESTATE:IsHumanPlayer(event.PlayerNumber) then return false end
	local kind = event.type
	local button = event.GameButton

	if kind == "InputEventType_Release" then
		if held and held.player == event.PlayerNumber and held.button == button then
			held = nil
			moveSeconds = MOVE_SECONDS
		end
		return false
	end
	if kind ~= "InputEventType_FirstPress" and kind ~= "InputEventType_Repeat" then return false end

	-- Carousel movement repeats on its own clock (updateHold), not on the
	-- engine's repeat events.
	if kind ~= "InputEventType_FirstPress" then return false end
	if button == "MenuLeft" then
		hold(event, -1, 1)
	elseif button == "MenuRight" then
		hold(event, 1, 1)
	elseif button == "MenuUp" then
		hold(event, -1, JUMP)
	elseif button == "MenuDown" then
		hold(event, 1, JUMP)
	elseif button == "Start" then
		choose()
	elseif button == "Back" then
		back()
	end
	return false
end

-- Menu timer: when it runs out the focused pack is opened.  The reading must
-- have been above zero first, so a timer that never started cannot fire.
local function checkMenuTimer()
	if not checkTimer or finished then return end
	local screen = SCREENMAN:GetTopScreen()
	local timer = screen and screen:GetChild("Timer")
	if not timer then return end
	local seconds = timer:GetSeconds()
	if seconds > 0 then
		timerSeen = true
	elseif timerSeen then
		choose()
	end
end

-- Actors --------------------------------------------------------------------

local af = Def.ActorFrame{
	Name="VOLT26SelectPack",
	InitCommand=function(self)
		root = self
		self:xy(K.Left, K.Top):zoom(K.Scale)
	end,
	OnCommand=function(self)
		local carousel = self:GetChild("Carousel")
		for i = 1, POOL do
			local tile = carousel:GetChild("Tile" .. i)
			tile.offset = i - 1 - HALF
			tiles[#tiles+1] = tile
			setContent(tile)
			placeTile(tile, false)
		end
		sortTiles()
		-- The focused jacket is on screen from the first frame (and is the
		-- one that may have just grown out of the header), so its artwork is
		-- not deferred.
		local focused = focusedTile()
		if focused and focused.artPending then focused:playcommand("LoadPackArt") end
		refreshName()
		refreshDetails()
		detailsDirty = false
		local entering = { Phase = "Enter", FromSongWheel = handoff == "FromSongWheel" }
		self:playcommand("SceneEnter", entering)
		MESSAGEMAN:Broadcast("VOLT26PackScene", entering)
		if handoff == "FromSongWheel" then enterFromSongWheel() else enterFresh() end

		local elapsed = 0
		self:SetUpdateFunction(function(frame, delta)
			delta = delta or 0
			updateHold(delta)
			idle = idle + delta
			if idle >= ART_IDLE and not finished then
				local best
				for _, tile in ipairs(tiles) do
					local reach = math.abs(tile.offset)
					if tile.artPending and reach <= LOAD_REACH and inWindow(tile.offset)
						and (not best or reach < math.abs(best.offset)) then
						best = tile
					end
				end
				if best then best:playcommand("LoadPackArt") end
			end
			if detailsDirty and idle >= DETAIL_IDLE then
				detailsDirty = false
				refreshDetails()
			end
			elapsed = elapsed + delta
			if elapsed >= 0.1 then
				elapsed = 0
				checkMenuTimer()
			end
		end)
		SCREENMAN:GetTopScreen():AddInputCallback(input)
	end,
	OffCommand=function(self)
		self:SetUpdateFunction(nil)
		SCREENMAN:GetTopScreen():RemoveInputCallback(input)
	end,
}

-- Back to front (the set's ground and stripes are in the background layer):
-- the carousel (neighbours, the splash, the focused jacket), the back of the
-- focused jacket, the set's lettering and stars, then the words.

local carousel = Def.ActorFrame{
	Name="Carousel",
	InitCommand=function(self) self:y(CENTER_Y) end,
	scene.Splash,
}
for i = 1, POOL do
	carousel[#carousel+1] = LoadActor("./Tile.lua", { K=K, Size=FOCUS_SIZE, Name="Tile" .. i })
end
af[#af+1] = carousel

af[#af+1] = scene.Front

-- Focused pack details
local details = Def.ActorFrame{ Name="Details" }
details[#details+1] = Def.ActorFrame{
	Name="NameLayer",
	InitCommand=function(self) self:xy(K.W/2, NAME_Y):zoom(1 / K.Scale) end,
	nameSlot(1),
	nameSlot(2),
}
local info = Def.ActorFrame{
	Name="Info",
	InitCommand=function(self) self:xy(K.W/2, 952) end,
}
for i, o in ipairs(INFO_OFFSETS) do
	info[#info+1] = K.Text{ Name="Stroke" .. i, Px=INFO_PX, Tint=Color.Black, Align=center,
		X=o[1] * INFO_STROKE, Y=o[2] * INFO_STROKE }
end
info[#info+1] = K.Text{ Name="Text", Px=INFO_PX, Tint=Color.White, Align=center }
details[#details+1] = info
af[#af+1] = details

af[#af+1] = Def.BitmapText{
	Name="Notice", Font=K.Label,
	InitCommand=function(self)
		self:xy(K.W/2, 1003):horizalign(center):shadowlength(0)
			:zoom(VOLT26.Type.LabelZoom(13)):diffuse(K.Ink):diffusealpha(0)
			:settext(K.String("PressBackAgain"))
	end,
}

af[#af+1] = LoadActor(THEME:GetPathS("MusicWheel", "change"))..{ Name="Change", IsAction=true, SupportPan=false }
af[#af+1] = LoadActor(THEME:GetPathS("common", "start"))..{ Name="Start", IsAction=true, SupportPan=false }
af[#af+1] = LoadActor(THEME:GetPathS("common", "invalid"))..{ Name="Invalid", IsAction=true, SupportPan=false }

return af
