-- The mockup's scenery.  Loaded with a part:
--   "Back"   from ScreenSelectMusic background.lua, under the engine's wheel:
--            the red ground with the chosen song's jacket faint under it,
--            its light, the black panel the rows hang down, the white
--            slashes and shards, and the SELECT logo;
--   "Bridge" just the red ground and its light, from the pack step's
--            background: it fades in while a pack opens (and out on the way
--            back), so the pack step hands over to red rather than
--            uncovering the backdrop under its own set; the song select's
--            pieces then slam in over it;
--   "Front"  from the overlay, over the wheel: the stars beside the focused
--            row and the jacket's white frame.
-- Every piece sits where the mockup has it (Art.lua).
--
-- Motion, in the Persona manner: every piece arrives on the screen's On with
-- a hard ease and a small overshoot, a new song gives the logo, the stars and
-- the jacket frame a kick, and (outside Performance mode) the light breathes,
-- the stars turn and the logo rocks.
local part = ... or "Back"
local K = LoadActor(THEME:GetPathB("", "_volt26 music kit.lua"))
local P = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/P5.lua"))
local idle = P.IdleMotion()

-- A piece with an entrance (and optional idle and song-change motion).
local function piece(name, enter, extra)
	local def = { OnCommand = function(self) if enter then enter(self) end end }
	if extra then for k, v in pairs(extra) do def[k] = v end end
	return P.Piece(name, 0, 0, def)
end

if part == "Front" then
	-- Stars: pop in turning, then turn on their own (each its own speed and
	-- way round); a new song makes them jump.
	local starSpin = { 34, -22, 48, -30 }
	local af = Def.ActorFrame{ Name = "SceneFront" }
	for i = 1, 4 do
		af[#af+1] = piece("Star" .. i, function(self)
			self:zoom(0):rotationz(-160):sleep(0.28 + i * 0.06)
				:decelerate(0.2):zoom(1.25):rotationz(10):decelerate(0.1):zoom(1):rotationz(0)
				:queuecommand("Idle")
		end, {
			IdleCommand = function(self)
				if idle then self:spin():effectmagnitude(0, 0, starSpin[i]) end
			end,
			CurrentSongChangedMessageCommand = function(self)
				self:finishtweening():sleep((i - 1) * 0.04):decelerate(0.08):zoom(1.3):accelerate(0.12):zoom(1)
			end,
		})
	end
	-- The jacket frame drops in from above and kicks on every new song.
	af[#af+1] = piece("JacketFrame", function(self)
		self:addy(-460):rotationz(9):sleep(0.12):decelerate(0.3):addy(460):rotationz(-1.5)
			:decelerate(0.1):rotationz(0)
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

local af = Def.ActorFrame{
	Name = "SceneBack",
	InitCommand = function(self) self:xy(K.Left, K.Top):zoom(K.Scale) end,
	-- Sized past the design rectangle so a screen that is not 16:9 keeps the
	-- red out to its own edges.
	Def.Quad{
		Name = "Ground",
		InitCommand = function(self)
			self:align(0, 0):xy(-K.W, -K.H):zoomto(K.W * 3, K.H * 3):diffuse(P.Red)
		end,
	},
}

if part == "Back" then
	-- The chosen song's jacket, covering the screen, faint under the red.  The
	-- small cached copy is enough for a picture this faint.  A new jacket
	-- swells in slightly as it fades up.
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
elseif part == "Bridge" then
	af.InitCommand = function(self) self:xy(K.Left, K.Top):zoom(K.Scale):diffusealpha(0) end
	af.VOLT26PackSceneMessageCommand = function(self, p)
		if p.Phase == "Leave" then
			self:stoptweening():linear(K.HandoffSeconds):diffusealpha(1)
		elseif p.Phase == "Enter" and p.FromSongWheel then
			self:stoptweening():diffusealpha(1):linear(K.HandoffSeconds):diffusealpha(0)
		end
	end
	af[#af+1] = P.Piece("Glow")
	return af
end

-- The light: fades up, then breathes.
af[#af+1] = piece("Glow", function(self)
	self:diffusealpha(0):linear(0.4):diffusealpha(1):queuecommand("Idle")
end, {
	IdleCommand = function(self)
		if idle then
			self:diffuseshift():effectperiod(4)
				:effectcolor1(color("1,1,1,1")):effectcolor2(color("1,1,1,0.55"))
		end
	end,
})

-- The black panel sweeps in from the left; the shards rise from the bottom.
af[#af+1] = piece("Wedge", function(self)
	self:addx(-760):decelerate(0.26):addx(790):decelerate(0.08):addx(-30)
end)
af[#af+1] = piece("DebrisA", function(self)
	self:addy(260):sleep(0.12):decelerate(0.24):addy(-280):decelerate(0.08):addy(20)
end)
af[#af+1] = piece("DebrisB", function(self)
	self:addy(300):sleep(0.18):decelerate(0.24):addy(-320):decelerate(0.08):addy(20)
end)

-- The slashes cut down along their own line.
af[#af+1] = piece("Slash", function(self)
	self:addx(520):addy(-990):sleep(0.06):decelerate(0.22):addx(-520):addy(990)
end)
af[#af+1] = piece("SlashThin", function(self)
	self:addx(230):addy(-470):sleep(0.14):decelerate(0.2):addx(-230):addy(470)
end)
af[#af+1] = piece("ChipA", function(self)
	self:zoom(0):sleep(0.42):decelerate(0.12):zoom(1.4):accelerate(0.08):zoom(1)
end)
af[#af+1] = piece("ChipB", function(self)
	self:zoom(0):sleep(0.46):decelerate(0.12):zoom(1.4):accelerate(0.08):zoom(1)
end)

-- The white band, the line and the black bar wipe across.
af[#af+1] = piece("Band", function(self)
	self:cropright(1):sleep(0.1):decelerate(0.28):cropright(0)
end)
af[#af+1] = piece("Line", function(self)
	self:cropright(1):sleep(0.2):decelerate(0.24):cropright(0)
end)
af[#af+1] = piece("Bar", function(self)
	self:cropleft(1):sleep(0.24):decelerate(0.16):cropleft(0)
end)

-- SELECT slams down from large, overshoots, then rocks; it jolts on a new
-- song and swells when the song is chosen.
af[#af+1] = piece("Select", function(self)
	self:zoom(2.3):rotationz(-24):diffusealpha(0):sleep(0.3)
		:accelerate(0.16):zoom(0.9):rotationz(4):diffusealpha(1)
		:decelerate(0.12):zoom(1.04):rotationz(-1)
		:accelerate(0.08):zoom(1):rotationz(0)
		:queuecommand("Idle")
end, {
	IdleCommand = function(self)
		if idle then self:wag():effectmagnitude(0, 0, 1.6):effectperiod(3.2) end
	end,
	CurrentSongChangedMessageCommand = function(self)
		self:finishtweening():zoom(1.06):decelerate(0.14):zoom(1)
	end,
	SongChosenMessageCommand = function(self)
		self:finishtweening():decelerate(0.12):zoom(1.25):rotationz(-6):accelerate(0.2):zoom(1.1):rotationz(-3)
	end,
})

return af
