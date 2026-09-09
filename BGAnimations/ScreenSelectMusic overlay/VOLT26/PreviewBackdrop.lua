local H = ...

-- The band is centred on x=427, like the preview notefield in ChartPreview.lua.
-- That notefield adopted the gameplay column pitch and now spans 359..495 for a
-- four-column style, so the band clears it by one arrow width on each side.
local vertices = {
	{{324,76,0},  {0.035,0.025,0.028,0.00}}, {{530,76,0},  {0.035,0.025,0.028,0.00}},
	{{324,112,0}, {0.035,0.025,0.028,0.48}}, {{530,112,0}, {0.035,0.025,0.028,0.48}},
	{{324,410,0}, {0.035,0.025,0.028,0.48}}, {{530,410,0}, {0.035,0.025,0.028,0.48}},
	{{324,450,0}, {0.035,0.025,0.028,0.00}}, {{530,450,0}, {0.035,0.025,0.028,0.00}},
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
