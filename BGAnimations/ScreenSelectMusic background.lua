return Def.ActorFrame{
	Def.Sprite{
		Name="SongSelectBackground",
		Texture=THEME:GetPathG("", "VOLT26/bg_ss@2x.png"),
		InitCommand=function(self)
			self:Center():scaletoclipped(_screen.w, _screen.h)
		end,
	},
	Def.Quad{
		Name="WheelRail",
		InitCommand=function(self)
			local scale = math.min(_screen.w/854, _screen.h/480)
			local left = _screen.cx - 427*scale
			self:align(0.5,0):xy(left+32*scale, 0)
				:zoomto(math.max(1,scale), _screen.h):diffuse(color("#840000"))
		end,
	}
}
