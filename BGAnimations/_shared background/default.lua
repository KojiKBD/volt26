-- the best way to spread holiday cheer is singing loud for all to hear
-- if HolidayCheer() then
-- 	return LoadActor( THEME:GetPathB("", "_shared background/Snow.lua") )
-- end

local file = THEME:GetPathG("", "VOLT26/SharedBackground.png")

local af = Def.ActorFrame{}

-- a simple Quad to serve as the backdrop
af[#af+1] = Def.Quad{
	InitCommand=function(self) self:FullScreen():Center():diffuse( ThemePrefs.Get("RainbowMode") and Color.White or Color.Black ) end,
}

af[#af+1] = LoadActor("./Normal.lua", file)
af[#af+1] = LoadActor("./RainbowMode.lua", file)
af[#af+1] = LoadActor("./Static.lua", file)
af[#af+1] = LoadActor("./Technique.lua", file)

return af
