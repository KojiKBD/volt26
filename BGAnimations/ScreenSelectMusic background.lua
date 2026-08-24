if ThemePrefs.Get("VisualStyle") == "VOLT26" then
	return Def.ActorFrame{
		Def.Sprite{
			Texture=THEME:GetPathG("", "VOLT26/bg_songselect.png"),
			InitCommand=function(self) self:Center():setsize(_screen.w, _screen.h) end,
		},
		Def.Quad{
			InitCommand=function(self) self:FullScreen():Center():diffuse(Color.Black) end,
			OnCommand=function(self) self:linear(0.25):diffusealpha(0):queuecommand("Hide") end,
			HideCommand=function(self) self:visible(false) end,
		}
	}
end

return Def.ActorFrame{
	Def.Quad{
		InitCommand=function(self) self:FullScreen():Center():diffuse( Color.White ) end
	},

	LoadActor( THEME:GetPathB("", "_shared background") ),

	Def.Quad{
		InitCommand=function(self)
			self:diffuse((ThemePrefs.Get("VisualStyle") == "SRPG6") and Color.Black or Color.White)
				:Center()
				:FullScreen()
				:sleep(0.6):linear(0.5):diffusealpha(0)
				:queuecommand("Hide")
		end,
		HideCommand=function(self) self:visible(false) end
	}
}
