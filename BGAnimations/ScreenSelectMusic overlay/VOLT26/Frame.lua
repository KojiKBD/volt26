local H = ...

return Def.ActorFrame{
	Name="Frame",
	Def.Sprite{
		Name="SelectTitle",
		Texture=THEME:GetPathG("", "VOLT26/Select_B.png"),
		InitCommand=function(self)
			self:align(0.5,0):xy(427,12):scaletoclipped(190,57)
		end,
	},
}
