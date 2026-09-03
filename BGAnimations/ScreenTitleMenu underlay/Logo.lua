return Def.ActorFrame{
	Def.Sprite{
		Name="VOLT26 Logo",
		Texture=THEME:GetPathG("", "VOLT26/logo_main (doubleres).png"),
		InitCommand=function(self)
			self:zoom(0.30):vertalign(middle):y(0):shadowlength(0)
		end,
		OffCommand=function(self)
			self:linear(0.5):shadowlength(0)
		end,
	},
}
