local surface = color("#151515")
local accent = color("#ff0000")
local white = color("#f1eded")

return Def.ActorFrame{
	Name="Header",
	Def.Quad{
		InitCommand=function(self)
			self:align(0,0):xy(0,0):zoomto(_screen.w,32):diffuse(surface)
		end,
	},
	Def.Quad{
		InitCommand=function(self)
			self:xy(_screen.w-16,16):zoomto(8,8):rotationz(45):diffuse(accent)
		end,
	},
	LoadFont("Common Header")..{
		Name="HeaderText",
		Text=ScreenString("HeaderText"),
		InitCommand=function(self)
			self:horizalign(left):xy(13,15):zoom(SL_WideScale(0.5,0.6)):diffuse(white):diffusealpha(0)
				:maxwidth((_screen.w-52)/SL_WideScale(0.5,0.6))
		end,
		OnCommand=function(self) self:sleep(0.06):decelerate(0.24):diffusealpha(1) end,
		OffCommand=function(self) self:accelerate(0.16):diffusealpha(0) end,
		SetHeaderTextMessageCommand=function(self,params) self:settext(params.Text) end,
		ResetHeaderTextMessageCommand=function(self)
			self:settext(THEME:GetString(SCREENMAN:GetTopScreen():GetName(),"HeaderText"))
		end,
	},
}
