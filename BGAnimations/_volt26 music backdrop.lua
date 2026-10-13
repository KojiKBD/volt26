-- Backdrop shared by ScreenVOLT26SelectPack and ScreenSelectMusic.
--
-- Loaded from each screen's background layer: on ScreenSelectMusic the engine
-- MusicWheel draws between the background and the overlay, so the backdrop
-- must live underneath it.  The Song Select artwork is kept behind a veil of
-- the ground colour so text stays readable over it.

local K = LoadActor(THEME:GetPathB("", "_volt26 music kit.lua"))

local artVeil = 0.72

return Def.ActorFrame{
	Name="VOLT26MusicBackdrop",
	InitCommand=function(self) self:xy(K.Left, K.Top):zoom(K.Scale) end,

	-- Sized past the design rectangle so a non-16:9 screen keeps the ground
	-- colour out to its own edges.
	Def.Quad{
		Name="Ground",
		InitCommand=function(self)
			self:align(0,0):xy(-K.W, -K.H):zoomto(K.W*3, K.H*3):diffuse(K.Bg)
		end,
	},
	Def.Sprite{
		Name="Art",
		Texture=THEME:GetPathG("", "VOLT26/SongSelection/backdrop.png"),
		InitCommand=function(self) self:align(0,0):xy(0,0):zoomto(K.W, K.H) end,
	},
	Def.Sprite{
		Name="Halftone",
		Texture=THEME:GetPathG("", "VOLT26/halftone_ss.png"),
		InitCommand=function(self) self:align(0,0):xy(0,0):zoomto(K.W, K.H) end,
	},
	Def.Quad{
		Name="Veil",
		InitCommand=function(self)
			self:align(0,0):xy(-K.W, -K.H):zoomto(K.W*3, K.H*3)
				:diffuse(K.Bg):diffusealpha(artVeil)
		end,
	},
}
