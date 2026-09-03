return Def.ActorFrame{
	Name="SplashScreen",
	InitCommand=function(self) self:draworder(200) end,

	Def.Quad{
		Name="Background",
		InitCommand=function(self) self:diffuse(0,0,0,0):FullScreen():cropbottom(1):fadebottom(0.5) end,
		OffCommand=function(self) self:linear(0.3):cropbottom(-0.5):diffusealpha(1) end
	}
}
