local surface = color("#151515")
local accent = color("#ff0000")

return Def.ActorFrame{
	Name="Footer",
	InitCommand=function(self) self:draworder(90) end,
	Def.Quad{
		InitCommand=function(self)
			self:align(0.5,1):xy(0,0):zoomto(_screen.w,32):diffuse(surface)
		end,
	},
	Def.Quad{
		InitCommand=function(self)
			self:xy(_screen.cx-16,-16):zoomto(8,8):rotationz(45):diffuse(accent)
		end,
	},
}
