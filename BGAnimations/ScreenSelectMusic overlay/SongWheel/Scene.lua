-- The mockup's scenery.  Loaded with a part:
--   "Back"   from ScreenSelectMusic background.lua, under the engine's wheel:
--            the red ground with the chosen song's jacket faint under it,
--            its light, the black panel the rows hang down, the white
--            slashes and shards, and the SELECT logo;
--   "Bridge" the same without the jacket, from the pack step's background:
--            it fades in while a pack opens (and out on the way back), so
--            the pack step hands over to this red scene rather than
--            uncovering the backdrop under its own;
--   "Front"  from the overlay, over the wheel: the stars beside the focused
--            row and the jacket's white frame.
-- Every piece sits where the mockup has it (Art.lua).  Pieces are named after
-- the mockup's parts so the animation pass can address them.
local part = ... or "Back"
local K = LoadActor(THEME:GetPathB("", "_volt26 music kit.lua"))
local P = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/P5.lua"))

if part == "Front" then
	return Def.ActorFrame{
		Name = "SceneFront",
		P.Piece("Star1"), P.Piece("Star2"), P.Piece("Star3"), P.Piece("Star4"),
		P.Piece("JacketFrame"),
	}
end

-- How much of the jacket shows through the red, and how long the wheel must
-- rest on a song before its jacket is loaded.
local JACKET_ALPHA = 0.16
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
	-- small cached copy is enough for a picture this faint.
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
				self:linear(0.3):diffusealpha(JACKET_ALPHA)
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
end

for _, name in ipairs({ "Glow", "Wedge", "DebrisA", "DebrisB", "Slash", "SlashThin",
	"ChipA", "ChipB", "Band", "Line", "Bar", "Select" }) do
	af[#af+1] = P.Piece(name)
end
return af
