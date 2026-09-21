-- the best way to spread holiday cheer is singing loud for all to hear
-- if HolidayCheer() then
-- 	return LoadActor( THEME:GetPathB("", "_shared background/Snow.lua") )
-- end

local af = Def.ActorFrame{}

-- a simple Quad to serve as the backdrop
af[#af+1] = Def.Quad{
	InitCommand=function(self) self:FullScreen():Center():diffuse( Color.Black ) end,
}

af[#af+1] = Def.Sprite{
	Texture=THEME:GetPathG("", "VOLT26/SharedBackground.png"),
	InitCommand=function(self)
		self:Center():scaletoclipped(_screen.w, _screen.h)
	end,
}

return af
