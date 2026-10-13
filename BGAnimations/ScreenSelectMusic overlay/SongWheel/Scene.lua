-- The mockup's scenery.  Loaded with a part:
--   "Back"   from ScreenSelectMusic background.lua, under the engine's wheel:
--            the red ground with the chosen song's jacket faint under it,
--            its light, the black panel the rows hang down, the white
--            slashes and shards, and the SELECT logo;
--   "Bridge" the same scenery (without the jacket), from the pack step's
--            background: it builds itself while a pack opens, under the
--            jacket flying to its frame, so the song select arrives with its
--            scenery already standing; on the way back from the song select
--            it takes itself apart again over the returning pack step;
--   "Front"  from the overlay, over the wheel: the jacket's white frame (the
--            mockup's stars beside the focused row give way to the song's
--            grade, Grade.lua).
-- Every piece sits where the mockup has it (Art.lua).
--
-- Motion, in the Persona manner.  The scenery's entrance (ENTER below) plays
-- on the song select's On, unless the pack step's bridge has just built it
-- (VOLT26.PackSelection.TakenHandoff() == "ToSongWheel"), and on the bridge,
-- quicker, while a pack opens; EXIT plays on the bridge on the way back.  A
-- new song gives the jacket frame a kick, and the light breathes.  The SELECT logo does not move (the owner's call); it only
-- fades with the bridge.
local part = ... or "Back"
local K = LoadActor(THEME:GetPathB("", "_volt26 music kit.lua"))
local P = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/P5.lua"))
local idle = true

-- A piece with an entrance (and optional idle and song-change motion).
local function piece(name, enter, extra)
	local def = { OnCommand = function(self) if enter then enter(self) end end }
	if extra then for k, v in pairs(extra) do def[k] = v end end
	return P.Piece(name, 0, 0, def)
end

if part == "Front" then
	-- The four decorative stars of the mockup are not drawn: their place
	-- beside the focused row shows the song's grade (Grade.lua), whose star
	-- grades stand where the stars were and turn the way they did.
	local af = Def.ActorFrame{ Name = "SceneFront" }
	-- The jacket frame drops in from above and kicks on every new song.
	af[#af+1] = piece("JacketFrame", function(self)
		self:addy(-460):rotationz(9):sleep(0.04):decelerate(0.2):addy(460):rotationz(-1.5)
			:decelerate(0.07):rotationz(0)
	end, {
		CurrentSongChangedMessageCommand = function(self)
			self:finishtweening():rotationz(3.5):zoom(1.04):decelerate(0.2):rotationz(0):zoom(1)
		end,
	})
	return af
end

-- How much of the jacket shows through the red, and how long the wheel must
-- rest on a song before its jacket is loaded.
local JACKET_ALPHA = 0.28
local JACKET_DELAY = 0.2
-- The song select's own entrance, quicker than the figures below as written.
local TEMPO = 0.7

-- The scenery's choreography.  Each entry takes the piece and a time scale
-- (1 on the song select; less on the bridge, which must finish within the
-- pack step's K.HandoffHold).  Moves are relative, so a piece always ends
-- where the mockup has it.
local PIECES = { "Glow", "Wedge", "DebrisA", "DebrisB", "Slash", "SlashThin",
	"ChipA", "ChipB", "Band", "Line", "Bar", "Select" }

local ENTER = {
	-- The light fades up.
	Glow = function(a, k) a:diffusealpha(0):linear(0.4 * k):diffusealpha(1) end,
	-- The black panel sweeps in from the left; the shards rise from below.
	Wedge = function(a, k) a:addx(-760):decelerate(0.26 * k):addx(790):decelerate(0.08 * k):addx(-30) end,
	DebrisA = function(a, k) a:addy(260):sleep(0.12 * k):decelerate(0.24 * k):addy(-280):decelerate(0.08 * k):addy(20) end,
	DebrisB = function(a, k) a:addy(300):sleep(0.18 * k):decelerate(0.24 * k):addy(-320):decelerate(0.08 * k):addy(20) end,
	-- The slashes cut down along their own line.
	Slash = function(a, k) a:addx(520):addy(-990):sleep(0.06 * k):decelerate(0.22 * k):addx(-520):addy(990) end,
	SlashThin = function(a, k) a:addx(230):addy(-470):sleep(0.14 * k):decelerate(0.2 * k):addx(-230):addy(470) end,
	ChipA = function(a, k) a:zoom(0):sleep(0.3 * k):decelerate(0.12 * k):zoom(1.4):accelerate(0.08 * k):zoom(1) end,
	ChipB = function(a, k) a:zoom(0):sleep(0.34 * k):decelerate(0.12 * k):zoom(1.4):accelerate(0.08 * k):zoom(1) end,
	-- The white band, the line and the black bar wipe across.
	Band = function(a, k) a:cropright(1):sleep(0.1 * k):decelerate(0.28 * k):cropright(0) end,
	Line = function(a, k) a:cropright(1):sleep(0.2 * k):decelerate(0.24 * k):cropright(0) end,
	Bar = function(a, k) a:cropleft(1):sleep(0.24 * k):decelerate(0.16 * k):cropleft(0) end,
	-- SELECT does not move; it is simply there.
	Select = function(a, k) end,
}

local EXIT = {
	Glow = function(a, k) a:linear(0.24 * k):diffusealpha(0) end,
	Wedge = function(a, k) a:accelerate(0.22 * k):addx(-800) end,
	DebrisA = function(a, k) a:accelerate(0.2 * k):addy(300) end,
	DebrisB = function(a, k) a:sleep(0.03 * k):accelerate(0.2 * k):addy(320) end,
	Slash = function(a, k) a:accelerate(0.2 * k):addx(520):addy(-990) end,
	SlashThin = function(a, k) a:accelerate(0.18 * k):addx(230):addy(-470) end,
	ChipA = function(a, k) a:accelerate(0.1 * k):zoom(0) end,
	ChipB = function(a, k) a:accelerate(0.1 * k):zoom(0) end,
	Band = function(a, k) a:accelerate(0.2 * k):cropleft(1) end,
	Line = function(a, k) a:accelerate(0.18 * k):cropleft(1) end,
	Bar = function(a, k) a:accelerate(0.14 * k):cropright(1) end,
	Select = function(a, k) a:linear(0.12 * k):diffusealpha(0) end,
}

-- The black panel.  Its picture starts a pixel below the top edge, and its
-- edges are soft where they meet the screen's, so the red would show through
-- in a thin line along the top and the left; black fill behind it, moving
-- with it, reaches past both edges.
local function wedge(extra)
	local piece = P.Art.Pieces.Wedge
	local def = Def.ActorFrame{
		Name = "Wedge",
		InitCommand = function(self) self:xy(piece.X, piece.Y) end,
		-- Everything left of x = 330 (the panel is solid black there).
		Def.Quad{ InitCommand = function(self)
			self:align(1, 0.5):x(330 - piece.X):zoomto(K.W * 2, K.H * 1.4):diffuse(P.Black)
		end },
		-- A band along the top, under the panel's top edge.
		Def.Quad{ InitCommand = function(self)
			self:align(1, 1):xy(975 - piece.X, 6 - piece.Y):zoomto(K.W * 2, 200):diffuse(P.Black)
		end },
		Def.Sprite{ Texture = P.PiecePath("Wedge") },
	}
	if extra then for k, v in pairs(extra) do def[k] = v end end
	return def
end

-- Puts a piece back where the mockup has it, ready for a motion.
local function reset(a, name)
	local piece = P.Art.Pieces[name]
	a:stoptweening():xy(piece.X, piece.Y):zoom(piece.Zoom or 1):rotationz(0)
		:cropleft(0):cropright(0):diffusealpha(1)
end

local af = Def.ActorFrame{
	Name = "SceneBack",
	InitCommand = function(self) self:xy(K.Left, K.Top):zoom(K.Scale) end,
}

if part == "Bridge" then
	-- The bridge's red comes in as a slanted sheet from the right (and leaves
	-- to the left), instead of a fade.  It is sized to cover the screen
	-- whatever its tilt.
	local SWEEP_W, SWEEP_H, SWEEP_TILT = K.W * 2.2, K.H * 2.4, -14
	local BRIDGE_K = 0.6
	af.InitCommand = function(self) self:xy(K.Left, K.Top):zoom(K.Scale):visible(false) end
	af.VOLT26PackSceneMessageCommand = function(self, p)
		if p.Phase == "Leave" then
			self:stoptweening():visible(true)
			self:GetChild("Ground"):stoptweening():x(K.W / 2 + SWEEP_W):decelerate(0.16):x(K.W / 2)
			for _, name in ipairs(PIECES) do
				local a = self:GetChild(name)
				reset(a, name)
				ENTER[name](a, BRIDGE_K)
			end
			-- SELECT has no motion; on the bridge it fades up with the band.
			self:GetChild("Select"):diffusealpha(0):sleep(0.08):linear(0.08):diffusealpha(1)
		elseif p.Phase == "Enter" and p.FromSongWheel then
			self:stoptweening():visible(true)
			self:GetChild("Ground"):stoptweening():x(K.W / 2):sleep(0.05):accelerate(0.16):x(K.W / 2 - SWEEP_W)
			for _, name in ipairs(PIECES) do
				local a = self:GetChild(name)
				reset(a, name)
				EXIT[name](a, 0.7)
			end
			self:sleep(0.3):queuecommand("Hide")
		end
	end
	af.HideCommand = function(self) self:visible(false) end
	af[#af+1] = Def.Quad{
		Name = "Ground",
		InitCommand = function(self)
			self:xy(K.W / 2, K.H / 2):zoomto(SWEEP_W, SWEEP_H):rotationz(SWEEP_TILT):diffuse(P.Red)
		end,
	}
	for _, name in ipairs(PIECES) do af[#af+1] = name == "Wedge" and wedge() or P.Piece(name) end
	return af
end

-- The song select's own scenery -----------------------------------------------

-- Sized past the design rectangle so a screen that is not 16:9 keeps the red
-- out to its own edges.
af[#af+1] = Def.Quad{
	Name = "Ground",
	InitCommand = function(self)
		self:align(0, 0):xy(-K.W, -K.H):zoomto(K.W * 3, K.H * 3):diffuse(P.Red)
	end,
}

-- The chosen song's jacket, covering the screen, faint under the red.  The
-- small cached copy is enough for a picture this faint.  A new jacket swells
-- in slightly as it fades up.
af[#af+1] = Def.Sprite{
	Name = "Jacket",
	InitCommand = function(self) self:xy(K.W / 2, K.H / 2):diffusealpha(0) end,
	OnCommand = function(self) self:queuecommand("Want") end,
	CurrentSongChangedMessageCommand = function(self) self:queuecommand("Want") end,
	CurrentCourseChangedMessageCommand = function(self) self:queuecommand("Want") end,
	WantCommand = function(self)
		local item = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or GAMESTATE:GetCurrentSong()
		local path, cacheDir
		if item then
			if GAMESTATE:IsCourseMode() then path, cacheDir = K.CourseArt(item) else path, cacheDir = K.SongArt(item) end
		end
		if path == self.wanted then return end
		self.wanted, self.wantedCache = path, cacheDir
		self:stoptweening():linear(0.12):diffusealpha(0):sleep(JACKET_DELAY):queuecommand("Show")
	end,
	ShowCommand = function(self)
		local path = self.wanted
		if path and K.LoadStill(self, path, self.wantedCache) then
			K.Cover(self, K.W, K.H)
			local zoom = self:GetZoomX()
			self:zoom(zoom * 1.06):decelerate(0.4):zoom(zoom):diffusealpha(JACKET_ALPHA)
		end
	end,
}

-- Was the scenery just built by the pack step's bridge?
local function bridged()
	if GAMESTATE:IsCourseMode() then return false end
	local selection = VOLT26.PackSelection
	return selection and selection.TakenHandoff and selection.TakenHandoff() == "ToSongWheel" or false
end

for _, name in ipairs(PIECES) do
	af[#af+1] = (name == "Wedge" and wedge or function(extra) return P.Piece(name, 0, 0, extra) end)({
		OnCommand = function(self)
			if not bridged() then ENTER[name](self, TEMPO) end
			if name == "Glow" then self:queuecommand("Idle") end
		end,
		IdleCommand = function(self)
			if idle and name == "Glow" then
				self:diffuseshift():effectperiod(4)
					:effectcolor1(color("1,1,1,1")):effectcolor2(color("1,1,1,0.55"))
			end
		end,
	})
end

-- The cutout lettering of the song select, drawn here and shown in the
-- overlay through proxies (see P.CutoutHost).
af[#af+1] = P.CutoutHost(K.Scale)

return af
