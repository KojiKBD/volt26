-- ScreenVOLT26SelectPack: the first step of music selection.
--
-- Packs are shown as square jackets on a horizontal carousel.  Left/Right
-- moves one pack, Up/Down jumps five; holding a direction keeps moving at the
-- operator's MusicWheel scroll speed (the MusicWheelSwitchSpeed preference,
-- set in the VOLT26 options), the same speed the song wheel scrolls at.
-- Start turns the focused jacket over to show the pack's songs on its back
-- (SongList.lua); there Up/Down scroll the list, Start opens the pack on the
-- song wheel (ScreenSelectMusic) and Back turns the jacket face up again.
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

local packs = PackSelection.List()
local count = #packs
local focus = PackSelection.InitialIndex(packs)

local POOL = 9                 -- tiles in the pool: offsets -4 .. 4
local HALF = (POOL - 1) / 2
local FOCUS_SIZE = K.TileSize
-- Sized so three and a half jackets fill the width: the focused one, one
-- either side, and a quarter of the next on each edge.
local SIDE_SIZE = 500
local GAP = 30
local SIDE_ZOOM = SIDE_SIZE / FOCUS_SIZE
local CENTER_X = K.W / 2
local CENTER_Y = 450
local MOVE_SECONDS = 0.14
local JUMP = 5
local HOLD_DELAY = 0.3         -- a held direction starts repeating after this
local FLIP_SECONDS = 0.12      -- each half of the jacket's turn
local NAME_Y = CENTER_Y + FOCUS_SIZE/2 + 78
local ART_IDLE = 0.08          -- rest before artwork starts loading
local DETAIL_IDLE = 0.12       -- rest before the pack summary is computed
local LOAD_REACH = 2           -- tiles further out are off screen
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
local flipped = false

-- Packs per second while a direction is held: the operator's MusicWheel
-- scroll speed (ScreenOptionsService, VOLT26.OperatorOptions.MusicWheelSpeed).
local function holdRate()
	local speed = tonumber(PREFSMAN:GetPreference("MusicWheelSwitchSpeed")) or 15
	return math.max(1, speed)
end

local function wrap(index)
	return ((index - 1) % count) + 1
end

local function slotX(offset)
	if offset == 0 then return 0 end
	local reach = FOCUS_SIZE/2 + GAP + SIDE_SIZE/2 + (math.abs(offset) - 1) * (SIDE_SIZE + GAP)
	return offset > 0 and reach or -reach
end

local function slotAlpha(offset)
	return math.max(0, 1 - 0.18 * math.abs(offset))
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

local function setFocusLook(tile, focused)
	tile:GetChild("Body"):GetChild("Frame"):visible(focused)
end

local function placeTile(tile, animate)
	local offset = tile.offset
	tile:stoptweening()
	-- A jacket left turned over (or mid-turn) is put face up at once.
	tile:GetChild("Body"):finishtweening():rotationy(0)
	if animate then tile:decelerate(moveSeconds) end
	tile:x(CENTER_X + slotX(offset)):y(0)
		:zoom(offset == 0 and 1 or SIDE_ZOOM)
		:diffusealpha(inWindow(offset) and slotAlpha(offset) or 0)
	setFocusLook(tile, offset == 0)
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

local function nameSlot(index)
	return VOLT26.Cutout.CreateSlot{
		-- The slots stand in theme units (NameLayer undoes the design scale),
		-- so their texture matches the screen's pixels.
		maxW = 1600 * K.Scale, maxH = 130 * K.Scale, halign = 0.5, valign = 0.5,
		maxChars = 48, held = true,
		opts = { base = 70 * K.Scale, tiltDeg = -2 },
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
	local position = root:GetChild("Details"):GetChild("Position")
	if count == 0 then
		setName("")
		K.SetLabel(position, "", 13)
		return
	end
	setName(packs[focus].Name)
	K.SetLabel(position, string.format("%03d / %03d", focus, count), 13)
end

local function refreshDetails()
	local info = root:GetChild("Details"):GetChild("Info")
	if count == 0 then
		K.SetLabel(info, K.String("NoPacks"), 18)
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
	K.SetLabel(info, table.concat(parts, "   /   "), 18, 1500)
end

-- Entrances and exits --------------------------------------------------------

-- Coming back from the song wheel: the focused jacket grows out of the header
-- badge into the middle and the rest of the carousel slides in around it.
local function enterFromSongWheel()
	for _, tile in ipairs(tiles) do
		local offset = tile.offset
		if offset == 0 then
			tile:stoptweening():xy(BADGE_X, BADGE_Y):zoom(BADGE_ZOOM):diffusealpha(1)
				:decelerate(K.HandoffSeconds):xy(CENTER_X, 0):zoom(1)
		else
			local side = offset > 0 and 1 or -1
			tile:stoptweening():xy(CENTER_X + slotX(offset) + side * 360, 0)
				:zoom(SIDE_ZOOM):diffusealpha(0)
				:sleep(0.08):decelerate(K.HandoffSeconds)
				:x(CENTER_X + slotX(offset))
				:diffusealpha(inWindow(offset) and slotAlpha(offset) or 0)
		end
	end
	local details = root:GetChild("Details")
	details:stoptweening():diffusealpha(0):addy(16):sleep(0.16):decelerate(0.2):diffusealpha(1):addy(-16)
end

local function enterFresh()
	local carousel = root:GetChild("Carousel")
	carousel:diffusealpha(0):addy(24):decelerate(0.25):diffusealpha(1):addy(-24)
end

-- Opening a pack: the focused jacket shrinks into the song wheel's header
-- badge, the others slide out to their own side, and the words fade.
local function leaveToSongWheel()
	for _, tile in ipairs(tiles) do
		local offset = tile.offset
		if offset == 0 then
			tile:GetChild("Body"):GetChild("Frame"):visible(false)
			tile:stoptweening():decelerate(K.HandoffSeconds):xy(BADGE_X, BADGE_Y):zoom(BADGE_ZOOM)
		else
			local side = offset > 0 and 1 or -1
			tile:stoptweening():accelerate(0.22):addx(side * 420):diffusealpha(0)
		end
	end
	root:GetChild("Details"):stoptweening():linear(0.12):diffusealpha(0)
end

-- Turning the jacket over ---------------------------------------------------
--
-- The jacket's front turns edge-on, then the song list (a separate face drawn
-- over the focused slot) turns in from the other edge; turning back is the
-- reverse.  Each face only ever rotates between face-on and edge-on.

local function songList()
	return root:GetChild("SongList")
end

local function flipToSongs()
	local tile = focusedTile()
	if not tile or count == 0 then return end
	-- A direction still held would turn the jacket straight back.
	held = nil
	moveSeconds = MOVE_SECONDS
	flipped = true
	songList():playcommand("SetSongs", { Group = packs[focus].Name })
	tile:GetChild("Body"):stoptweening():linear(FLIP_SECONDS):rotationy(90)
	songList():stoptweening():visible(true):rotationy(-90)
		:sleep(FLIP_SECONDS):decelerate(FLIP_SECONDS):rotationy(0)
end

local function flipToJacket(instant)
	if not flipped then return end
	flipped = false
	local tile = focusedTile()
	local list = songList()
	if instant then
		list:stoptweening():rotationy(0):visible(false)
		if tile then tile:GetChild("Body"):stoptweening():rotationy(0) end
		return
	end
	list:stoptweening():linear(FLIP_SECONDS):rotationy(90):queuecommand("Hide")
	if tile then
		tile:GetChild("Body"):stoptweening():rotationy(-90)
			:sleep(FLIP_SECONDS):decelerate(FLIP_SECONDS):rotationy(0)
	end
end

-- Actions -------------------------------------------------------------------

local function play(name)
	local sound = root and root:GetChild(name)
	if sound then sound:play() end
end

local function move(direction, steps)
	if finished or count <= 1 then return end
	flipToJacket(true)
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
	-- jacket that flies there already has it, and turn it face up on the way.
	local tile = focusedTile()
	if tile and tile.artPending then tile:playcommand("LoadPackArt") end
	flipToJacket(false)
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

local function onFlippedSide(event, button, kind)
	if button == "MenuUp" or button == "MenuDown" then
		local list = songList()
		list:playcommand("Scroll", { Delta = button == "MenuUp" and -1 or 1 })
		if list.moved then play("Change") end
	elseif kind == "InputEventType_FirstPress" then
		if button == "MenuLeft" then
			hold(event, -1, 1)
		elseif button == "MenuRight" then
			hold(event, 1, 1)
		elseif button == "Start" then
			choose()
		elseif button == "Back" then
			flipToJacket(false)
			play("Change")
		end
	end
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

	if flipped then
		onFlippedSide(event, button, kind)
		return false
	end
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
		if count == 0 then play("Invalid") else flipToSongs(); play("Change") end
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
		-- The focused jacket is on screen from the first frame (and is the
		-- one that may have just grown out of the header), so its artwork is
		-- not deferred.
		local focused = focusedTile()
		if focused and focused.artPending then focused:playcommand("LoadPackArt") end
		refreshName()
		refreshDetails()
		detailsDirty = false
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

af[#af+1] = Def.BitmapText{
	Name="Notice", Font=K.Label,
	InitCommand=function(self)
		self:xy(K.W/2, CENTER_Y + FOCUS_SIZE/2 + 228):horizalign(center):shadowlength(0)
			:zoom(VOLT26.Type.LabelZoom(13)):diffuse(K.Accent):diffusealpha(0)
			:settext(K.String("PressBackAgain"))
	end,
}

-- Focused pack details
local details = Def.ActorFrame{ Name="Details" }
details[#details+1] = Def.ActorFrame{
	Name="NameLayer",
	InitCommand=function(self) self:xy(K.W/2, NAME_Y):zoom(1 / K.Scale) end,
	nameSlot(1),
	nameSlot(2),
}
details[#details+1] = K.Text{ Name="Info", Px=18, Tint=K.Mute, Align=center, X=K.W/2, Y=CENTER_Y + FOCUS_SIZE/2 + 150 }
-- The pack's place in the list.
details[#details+1] = K.Text{ Name="Position", Px=13, Tint=K.Dim, Align=center, X=K.W/2, Y=CENTER_Y + FOCUS_SIZE/2 + 190 }
af[#af+1] = details

-- Carousel
local carousel = Def.ActorFrame{
	Name="Carousel",
	InitCommand=function(self) self:y(CENTER_Y) end,
}
for i = 1, POOL do
	carousel[#carousel+1] = LoadActor("./Tile.lua", { K=K, Size=FOCUS_SIZE, Name="Tile" .. i })
end
af[#af+1] = carousel

-- The back of the focused jacket, over the focused slot.
af[#af+1] = LoadActor("./SongList.lua", { K=K, Size=FOCUS_SIZE })..{
	InitCommand=function(self)
		self.songs, self.offset, self.moved = {}, 0, false
		self:xy(CENTER_X, CENTER_Y):visible(false)
	end,
	HideCommand=function(self) self:visible(false):rotationy(0) end,
}

af[#af+1] = LoadActor(THEME:GetPathS("MusicWheel", "change"))..{ Name="Change", IsAction=true, SupportPan=false }
af[#af+1] = LoadActor(THEME:GetPathS("common", "start"))..{ Name="Start", IsAction=true, SupportPan=false }
af[#af+1] = LoadActor(THEME:GetPathS("common", "invalid"))..{ Name="Invalid", IsAction=true, SupportPan=false }

return af
