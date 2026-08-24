return Def.Quad{
	InitCommand=function(self) self:FullScreen():diffuse(1,0,0,0) end,
	OnCommand=function(self) self:decelerate(1):diffusealpha(1) end
}
