-- Carries ScreenInit's final composition onto the already-loaded title menu,
-- then dissolves it to reveal the live VOLT26 menu animation underneath.
local enabled = _G.Volt26InitHandoff == true

local af = Def.ActorFrame{
	InitCommand=function(self)
		self:Center():draworder(1000):visible(enabled)
	end,
	StartTransitioningCommand=function(self)
		if not enabled then return end
		self:smooth(0.90):diffusealpha(0):queuecommand("FinishHandoff")
	end,
	FinishHandoffCommand=function(self)
		_G.Volt26InitHandoff = nil
		self:visible(false)
	end
}

af[#af+1] = Def.Quad{
	InitCommand=function(self)
		self:zoomto(_screen.w, _screen.h):diffuse(color("#FF0000"))
	end
}

af[#af+1] = Def.Sprite{
	Texture=THEME:GetPathG("", "_VisualStyles/VOLT26/Stars/star_00029.png"),
	InitCommand=function(self) self:zoomto(_screen.w, _screen.h) end
}

af[#af+1] = Def.Sprite{
	Texture=THEME:GetPathG("", "_VisualStyles/VOLT26/logo_main (doubleres).png"),
	InitCommand=function(self) self:zoom(0.30) end
}

return af