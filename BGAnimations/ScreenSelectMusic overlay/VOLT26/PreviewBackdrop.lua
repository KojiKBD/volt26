local H = ...

local vertices = {
	{{242,76,0},  {0.035,0.025,0.028,0.00}}, {{612,76,0},  {0.035,0.025,0.028,0.00}},
	{{242,112,0}, {0.035,0.025,0.028,0.48}}, {{612,112,0}, {0.035,0.025,0.028,0.48}},
	{{242,410,0}, {0.035,0.025,0.028,0.48}}, {{612,410,0}, {0.035,0.025,0.028,0.48}},
	{{242,450,0}, {0.035,0.025,0.028,0.00}}, {{612,450,0}, {0.035,0.025,0.028,0.00}},
}

local af = Def.ActorFrame{
	Name="PreviewBackdrop",
	RefreshCommand=function(self)
		self:visible(H.Item() ~= nil and not GAMESTATE:IsCourseMode())
	end,
	Def.ActorMultiVertex{
		InitCommand=function(self)
			self:SetDrawState({Mode="DrawMode_QuadStrip"}):SetVertices(vertices)
		end,
	},
}

H.AddRefresh(af)
return af
