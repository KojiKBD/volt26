-- Compatibility gate and short black handoff. The opening credits and logo now
-- play over the descending 3D city camera on ScreenTitleMenu.
local af = Def.ActorFrame{
	InitCommand=function(self) self:Center() end,
	OffCommand=function(self)
		_G.Volt26InitHandoff = true
	end
}

-- Keep startup compatibility checks active before the title sequence.
af[#af+1] = LoadActor("./CompatibilityChecks.lua")

af[#af+1] = Def.Quad{
	Name="HandoffBackground",
	InitCommand=function(self)
		self:zoomto(_screen.w, _screen.h):diffuse(Color.Black)
	end
}

return af
