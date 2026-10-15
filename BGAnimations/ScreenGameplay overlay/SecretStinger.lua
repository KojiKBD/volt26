-- "Are you LOST?" over the hidden song's opening (VOLT26.Secret): the song
-- starts at once (ScreenGameplay in skips its lead-in for it) and its first
-- arrow comes about four seconds in, so the screen stays black with the title
-- while the music plays, and clears before the first arrow reaches the
-- receptors.  Any other song gets an empty actor.
--
-- The title is one picture baked by tools/secret/build_lost_title.py from the
-- cutout fonts' own letters at a high em, with the block's tilt baked in, so
-- the sprite is never rotated.
if not VOLT26.Secret.IsHiddenSong(GAMESTATE:GetCurrentSong()) or GAMESTATE:IsCourseMode() then
	return Def.Actor{}
end

local SHOW_AT = 0.15        -- seconds before the title lands
local CLEAR_AT = 2.7        -- when the screen starts to clear
local CLEAR = 0.3           -- how long it takes
local WIDTH = 1500          -- the title's width, in 1920x1080 design pixels

local scale = SCREEN_HEIGHT / 1080

return Def.ActorFrame{
	Name="SecretStinger",
	OnCommand=function(self)
		self:sleep(CLEAR_AT + CLEAR):queuecommand("Done")
	end,
	DoneCommand=function(self) self:visible(false) end,

	Def.Quad{
		InitCommand=function(self) self:FullScreen():diffuse(Color.Black) end,
		OnCommand=function(self) self:sleep(CLEAR_AT):linear(CLEAR):diffusealpha(0) end,
	},
	Def.Sprite{
		Texture=THEME:GetPathG("", "VOLT26/Secret/lost_title.png"),
		InitCommand=function(self)
			local zoom = WIDTH * scale / self:GetWidth()
			self.zoomTo = zoom
			self:Center():zoom(zoom * 1.25):diffusealpha(0)
		end,
		OnCommand=function(self)
			local zoom = self.zoomTo
			self:sleep(SHOW_AT):decelerate(0.12):zoom(zoom * 0.97):diffusealpha(1)
				:decelerate(0.06):zoom(zoom)
				:sleep(CLEAR_AT - SHOW_AT - 0.18):linear(CLEAR * 0.7):diffusealpha(0)
		end,
	},
}
