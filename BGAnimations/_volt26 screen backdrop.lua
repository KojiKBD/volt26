return Def.ActorFrame{
	Name="VOLT26ScreenBackdrop",
	Def.Sprite{
		Texture=THEME:GetPathG("", "VOLT26/bg_ss@2x.png"),
		InitCommand=function(self) self:Center():scaletoclipped(_screen.w, _screen.h) end,
	},
	Def.Quad{
		InitCommand=function(self)
			self:align(0,0):xy(0,0):zoomto(_screen.w,_screen.h*0.22)
				:diffuse(color("#090909")):diffusealpha(0.44)
		end,
	},
	Def.Quad{
		InitCommand=function(self)
			self:align(0,1):xy(0,_screen.h):zoomto(_screen.w,_screen.h*0.18)
				:diffuse(color("#090909")):diffusealpha(0.38)
		end,
	},
}
