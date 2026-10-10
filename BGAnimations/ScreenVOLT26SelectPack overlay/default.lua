-- ScreenVOLT26SelectPack: the first step of music selection.
--
-- Packs are shown as square jackets on a horizontal carousel.  Left/Right
-- moves one pack, Up/Down jumps five, Start opens the focused pack on the song
-- wheel (ScreenSelectMusic) and Back leaves music selection.  In event mode
-- Back has to be pressed twice, standing in for the exit prompt the song wheel
-- used to show.
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
local FOCUS_SIZE = 440
local SIDE_SIZE = 280
local GAP = 28
local SIDE_ZOOM = SIDE_SIZE / FOCUS_SIZE
local CENTER_X = K.W / 2
local CENTER_Y = 480
local MOVE_SECONDS = 0.14
local JUMP = 5
local ART_IDLE = 0.08          -- rest before artwork starts loading
local DETAIL_IDLE = 0.12       -- rest before the pack summary is computed
local LOAD_REACH = 3           -- tiles further out are off screen
local EXIT_WINDOW = 2.0        -- event mode: seconds for the second Back

local root
local tiles = {}
local idle = 0
local detailsDirty = true
local finished = false
local exitArmedAt = nil
local timerSeen = false
local checkTimer = VOLT26.MenuTimer.IsEnabledForSongSelect()

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
	tile.group = entry and entry.Name or nil
	local body = tile:GetChild("Body")
	K.SetLabel(body:GetChild("Plate"):GetChild("Name"), (tile.group or ""):upper(), 20, FOCUS_SIZE - 48)
	body:GetChild("Initials"):settext(K.Initials(tile.group))
	if tile.loadedGroup ~= tile.group then
		body:GetChild("Art"):visible(false)
		body:GetChild("Fill"):visible(false)
		tile.loadedGroup = nil
		tile.artPending = tile.group ~= nil
	end
end

local function loadArt(tile)
	tile.artPending = false
	tile.loadedGroup = tile.group
	local body = tile:GetChild("Body")
	local art, fill = body:GetChild("Art"), body:GetChild("Fill")
	art:visible(false)
	fill:visible(false)
	if not tile.group then return end

	local info = PackSelection.Artwork(tile.group)
	if not info then return end
	if info.Kind == "Jacket" then
		if K.LoadStill(art, info.Path) then
			K.Cover(art, FOCUS_SIZE, FOCUS_SIZE)
			art:visible(true)
		end
	else
		if K.LoadStill(fill, info.Path, "Banner") then
			K.Cover(fill, FOCUS_SIZE, FOCUS_SIZE)
			fill:diffusealpha(0.28):visible(true)
		end
		if K.LoadStill(art, info.Path, "Banner") then
			K.Contain(art, FOCUS_SIZE - 40, FOCUS_SIZE - 40)
			art:visible(true)
		end
	end
end

local function placeTile(tile, animate)
	local offset = tile.offset
	local focused = offset == 0
	tile:stoptweening()
	if animate then tile:decelerate(MOVE_SECONDS) end
	tile:x(CENTER_X + slotX(offset))
		:zoom(focused and 1 or SIDE_ZOOM)
		:diffusealpha(inWindow(offset) and slotAlpha(offset) or 0)

	local body = tile:GetChild("Body")
	local plate = body:GetChild("Plate")
	plate:stoptweening()
	if animate then plate:linear(MOVE_SECONDS) end
	plate:diffusealpha(focused and 0 or 1)
	body:GetChild("Frame"):visible(focused)
end

-- Details -------------------------------------------------------------------

local function refreshName()
	local name = root:GetChild("Details"):GetChild("Name")
	local position = root:GetChild("Header"):GetChild("Position")
	if count == 0 then
		K.SetDisplay(name, "", 56)
		K.SetLabel(position, "", 16)
		return
	end
	K.SetDisplay(name, packs[focus].Name, 56, 1500)
	K.SetLabel(position, string.format("%03d / %03d", focus, count), 16)
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
	root:GetChild("Footer"):GetChild("Notice"):stoptweening():diffusealpha(0)
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
	for _, tile in ipairs(tiles) do
		if tile.offset == 0 then
			tile:stoptweening():decelerate(0.12):zoom(1.06)
		else
			tile:stoptweening():linear(0.18):diffusealpha(0)
		end
	end
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
	root:GetChild("Footer"):GetChild("Notice"):stoptweening():diffusealpha(1)
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
		refreshName()
		refreshDetails()
		detailsDirty = false
		carousel:diffusealpha(0):addy(24):decelerate(0.25):diffusealpha(1):addy(-24)

		local elapsed = 0
		self:SetUpdateFunction(function(frame, delta)
			delta = delta or 0
			idle = idle + delta
			if idle >= ART_IDLE then
				local best
				for _, tile in ipairs(tiles) do
					local reach = math.abs(tile.offset)
					if tile.artPending and reach <= LOAD_REACH and inWindow(tile.offset)
						and (not best or reach < math.abs(best.offset)) then
						best = tile
					end
				end
				if best then loadArt(best) end
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

-- Header
local header = Def.ActorFrame{ Name="Header" }
header[#header+1] = K.Text{ Name="Kicker", Px=13, Tint=K.Accent, X=80, Y=52, Text=K.String("PackKicker") }
header[#header+1] = K.Text{ Name="Title", Px=40, Tint=K.Ink, X=80, Y=96, Text=K.String("PackTitle") }
header[#header+1] = K.Text{ Name="Position", Px=16, Tint=K.Mute, Align=right, X=K.W-80, Y=96 }
header[#header+1] = K.Rule{ X=80, Y=136, Width=K.W-160, Height=1 }
af[#af+1] = header

-- Carousel
local carousel = Def.ActorFrame{
	Name="Carousel",
	InitCommand=function(self) self:y(CENTER_Y) end,
}
for i = 1, POOL do
	carousel[#carousel+1] = LoadActor("./Tile.lua", { K=K, Size=FOCUS_SIZE, Name="Tile" .. i })
end
af[#af+1] = carousel

-- Focused pack details
local details = Def.ActorFrame{ Name="Details" }
details[#details+1] = K.Text{ Name="Name", Role="Display", Px=56, Tint=K.Ink, Align=center, X=K.W/2, Y=CENTER_Y + FOCUS_SIZE/2 + 80 }
details[#details+1] = K.Text{ Name="Info", Px=18, Tint=K.Mute, Align=center, X=K.W/2, Y=CENTER_Y + FOCUS_SIZE/2 + 140 }
af[#af+1] = details

-- Footer
local footer = Def.ActorFrame{ Name="Footer" }
footer[#footer+1] = K.Rule{ X=80, Y=990, Width=K.W-160, Height=1 }
footer[#footer+1] = K.Text{
	Name="Hints", Px=14, Tint=K.Mute, X=80, Y=1030,
	Text=table.concat({ K.String("HintPack"), K.String("HintJump"), K.String("HintOpen"), K.String("HintExit") }, "        "),
}
footer[#footer+1] = Def.BitmapText{
	Name="Notice", Font=K.Label,
	InitCommand=function(self)
		self:xy(K.W-80, 1030):horizalign(right):shadowlength(0)
			:zoom(VOLT26.Type.LabelZoom(14)):diffuse(K.Accent):diffusealpha(0)
			:settext(K.String("PressBackAgain"))
	end,
}
af[#af+1] = footer

af[#af+1] = LoadActor(THEME:GetPathS("MusicWheel", "change"))..{ Name="Change", IsAction=true, SupportPan=false }
af[#af+1] = LoadActor(THEME:GetPathS("common", "start"))..{ Name="Start", IsAction=true, SupportPan=false }
af[#af+1] = LoadActor(THEME:GetPathS("common", "invalid"))..{ Name="Invalid", IsAction=true, SupportPan=false }

return af
