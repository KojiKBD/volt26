-- Compatibility gate and short black handoff. ScreenTitleMenu owns the complete
-- descending-city vow and no longer replays the old red/logo handoff frame.
local af = Def.ActorFrame{
	InitCommand=function(self) self:Center() end,
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
