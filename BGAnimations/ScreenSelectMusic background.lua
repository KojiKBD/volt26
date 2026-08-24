return Def.ActorFrame{
	Def.Sprite{
		Texture=THEME:GetPathG("", "VOLT26/bg_songselect.png"),
		InitCommand=function(self) self:Center():setsize(_screen.w, _screen.h) end,
	},
	Def.Quad{
		InitCommand=function(self) self:FullScreen():Center():diffuse(Color.Black) end,
		OnCommand=function(self) self:linear(0.25):diffusealpha(0):queuecommand("Hide") end,
		HideCommand=function(self) self:visible(false) end
	}
}
