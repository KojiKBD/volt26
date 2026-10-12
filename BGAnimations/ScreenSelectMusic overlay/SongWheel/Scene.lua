-- The mockup's scenery.  Loaded twice with a different part:
--   "Back"  from ScreenSelectMusic background.lua, under the engine's wheel:
--           the red ground and its light, the black panel the rows hang
--           down, the white slashes and shards, and the SELECT logo;
--   "Front" from the overlay, over the wheel: the stars beside the focused
--           row and the jacket's white frame.
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
for _, name in ipairs({ "Glow", "Wedge", "DebrisA", "DebrisB", "Slash", "SlashThin",
	"ChipA", "ChipB", "Band", "Line", "Bar", "Select" }) do
	af[#af+1] = P.Piece(name)
end
return af
