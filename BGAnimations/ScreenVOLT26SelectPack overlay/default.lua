-- ScreenVOLT26SelectPack: the first step of music selection.
--
-- Packs are shown as square jackets on a horizontal carousel.  Left/Right
-- moves one pack, Up/Down jumps five, Start opens the focused pack on the song
-- wheel (ScreenSelectMusic) and Back leaves music selection.  In event mode
-- Back has to be pressed twice, standing in for the exit prompt the song wheel
-- used to show.
--
-- The pack step and the song wheel are two screens drawn to read as one: the
-- same backdrop and header/footer bands (K.Chrome), and the chosen jacket
-- travels between them.  Opening a pack shrinks the focused jacket into the
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
local SIDE_SIZE = 280
local GAP = 28
local SIDE_ZOOM = SIDE_SIZE / FOCUS_SIZE
local CENTER_X = K.W / 2
local CENTER_Y = 500
local MOVE_SECONDS = 0.14
local JUMP = 5
local ART_IDLE = 0.08          -- rest before artwork starts loading
local DETAIL_IDLE = 0.12       -- rest before the pack summary is computed
local LOAD_REACH = 3           -- tiles further out are off screen
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

local function setFocusLook(tile, focused, animate)
	local body = tile:GetChild("Body")
	local plate = body:GetChild("Plate")
	plate:stoptweening()
	if animate then plate:linear(MOVE_SECONDS) end
	plate:diffusealpha(focused and 0 or 1)
	body:GetChild("Frame"):visible(focused)
end

local function placeTile(tile, animate)
	local offset = tile.offset
	tile:stoptweening()
	if animate then tile:decelerate(MOVE_SECONDS) end
	tile:x(CENTER_X + slotX(offset)):y(0)
		:zoom(offset == 0 and 1 or SIDE_ZOOM)
		:diffusealpha(inWindow(offset) and slotAlpha(offset) or 0)
	setFocusLook(tile, offset == 0, animate)
end

local function focusedTile()
	for _, tile in ipairs(tiles) do
		if tile.offset == 0 then return tile end
	end
	return nil
end

-- Details -------------------------------------------------------------------

local function refreshName()
	local name = root:GetChild("Details"):GetChild("Name")
	local position = root:GetChild("Position")
	if count == 0 then
		K.SetDisplay(name, "", 56)
		K.SetLabel(position, "", 13)
		return
	end
	K.SetDisplay(name, packs[focus].Name, 56, 1500)
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
	root:GetChild("Position"):stoptweening():diffusealpha(0):sleep(0.16):linear(0.2):diffusealpha(1)
	root:GetChild("Chrome"):playcommand("ChromeIn")
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
	root:GetChild("Position"):stoptweening():linear(0.12):diffusealpha(0)
	root:GetChild("Chrome"):playcommand("ChromeOut")
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

input = function(event)
	if finished or not event or not event.PlayerNumber then return false end
	if not GAMESTATE:IsHumanPlayer(event.PlayerNumber) then return false end
	local kind = event.type
	if kind ~= "InputEventType_FirstPress" and kind ~= "InputEventType_Repeat" then return false end
	local button = event.GameButton

	if button == "MenuLeft" then
		move(-1)
	elseif button == "MenuRight" then
		move(1)
	elseif button == "MenuUp" then
		move(-1, JUMP)
	elseif button == "MenuDown" then
		move(1, JUMP)
	elseif kind == "InputEventType_FirstPress" then
		if button == "Start" then
			choose()
		elseif button == "Back" then
			back()
		end
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

-- The header and footer bands come first: the jacket flying to the header
-- badge has to pass over them.
af[#af+1] = K.Chrome{
	Title = K.String("PackTitle"),
	Hints = table.concat({ K.String("HintPack"), K.String("HintJump"), K.String("HintOpen"), K.String("HintExit") }, "        "),
}
-- Where the song wheel shows the song's place in its pack, the pack step shows
-- the pack's place in the list.
af[#af+1] = K.Text{ Name="Position", Px=13, Tint=K.Mute, X=K.Badge.X + K.Badge.Size/2 + 18, Y=72 }
af[#af+1] = Def.BitmapText{
	Name="Notice", Font=K.Label,
	InitCommand=function(self)
		self:xy(K.W-40, K.FooterTop+38):horizalign(right):shadowlength(0)
			:zoom(VOLT26.Type.LabelZoom(13)):diffuse(K.Accent):diffusealpha(0)
			:settext(K.String("PressBackAgain"))
	end,
}

-- Focused pack details
local details = Def.ActorFrame{ Name="Details" }
details[#details+1] = K.Text{ Name="Name", Role="Display", Px=56, Tint=K.Ink, Align=center, X=K.W/2, Y=CENTER_Y + FOCUS_SIZE/2 + 80 }
details[#details+1] = K.Text{ Name="Info", Px=18, Tint=K.Mute, Align=center, X=K.W/2, Y=CENTER_Y + FOCUS_SIZE/2 + 138 }
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

af[#af+1] = LoadActor(THEME:GetPathS("MusicWheel", "change"))..{ Name="Change", IsAction=true, SupportPan=false }
af[#af+1] = LoadActor(THEME:GetPathS("common", "start"))..{ Name="Start", IsAction=true, SupportPan=false }
af[#af+1] = LoadActor(THEME:GetPathS("common", "invalid"))..{ Name="Invalid", IsAction=true, SupportPan=false }

return af
