-- The hidden song's stinger (VOLT26.Secret): "Are you LOST?" in the cutout
-- lettering, white with LOST? in red, on black; then its chart starts.
--
-- The title is one picture baked by tools/secret/build_lost_title.py from the
-- cutout fonts' own letters at a high em (the runtime cutout fonts only carry
-- the grade letters large enough for a title this size), with the block's
-- tilt baked in, so the sprite is never rotated.
local SHOW_AT = 0.35        -- seconds of black before the title
local HOLD = 2.4            -- how long the title stays
local WIDTH = 1500          -- the title's width, in 1920x1080 design pixels

local scale = SCREEN_HEIGHT / 1080
local done = false

local function proceed()
	if done then return end
	done = true
	local screen = SCREENMAN:GetTopScreen()
	if screen then screen:StartTransitioningScreen("SM_GoToNextScreen") end
end

return Def.ActorFrame{
	OnCommand=function(self)
		SOUND:StopMusic()
		self:sleep(SHOW_AT + HOLD + 0.25):queuecommand("Proceed")
	end,
	ProceedCommand=function(self) proceed() end,

	Def.Quad{
		InitCommand=function(self) self:FullScreen():diffuse(Color.Black) end,
	},
	Def.Sprite{
		Name="Title",
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
				:sleep(HOLD):linear(0.2):diffusealpha(0)
		end,
	},
}
