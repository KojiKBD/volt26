local H = ...

local af = Def.ActorFrame{
	Name="Controls",
	InitCommand=function(self) self:xy(282,391) end,
}

af[#af+1] = H.Polygon({{-6,9},{112,2},{123,62},{0,69}}, H.Black)
af[#af+1] = Def.Quad{InitCommand=function(self) self:xy(58,37):zoomto(116,57):skewx(-0.1):diffuse(H.White):diffusealpha(0.08) end}
af[#af+1] = Def.BitmapText{Font=H.Font, Text="<   >", InitCommand=function(self) self:xy(24,35):zoom(0.074):diffuse(H.White) end}
af[#af+1] = Def.BitmapText{Font=H.Font, Text="CHANGE\nSONG", InitCommand=function(self) self:xy(79,35):zoom(0.061):diffuse(H.White):rotationz(-2) end}

af[#af+1] = H.Polygon({{116,3},{284,-5},{275,70},{125,65}}, H.White)
af[#af+1] = H.Polygon({{123,10},{278,2},{269,61},{130,59}}, color("#ededed"))
af[#af+1] = Def.Quad{InitCommand=function(self) self:align(0,0):xy(128,58):zoomto(134,4):rotationz(-2):diffuse(H.P1) end}
af[#af+1] = Def.BitmapText{Font=H.Font, Text="SELECT", InitCommand=function(self) self:xy(198,30):zoom(0.17):diffuse(H.Black):rotationz(-2) end}
af[#af+1] = Def.BitmapText{Font=H.Font, Text="CENTER  //  SELECT / START SONG", InitCommand=function(self) self:xy(199,52):zoom(0.038):diffuse(H.Black):maxwidth(135/0.038) end}

af[#af+1] = H.Polygon({{280,1},{559,7},{550,67},{276,62}}, H.Black)
af[#af+1] = Def.Quad{InitCommand=function(self) self:align(0,0):xy(291,9):zoomto(257,2):rotationz(1):diffuse(H.White):diffusealpha(0.7) end}
af[#af+1] = Def.BitmapText{Font=H.Font, Text="OO", InitCommand=function(self) self:xy(310,34):zoom(0.095):diffuse(H.White) end}
af[#af+1] = Def.BitmapText{Font=H.Font, Text="DOUBLE TAP CENTER", InitCommand=function(self) self:xy(355,26):horizalign(left):zoom(0.056):diffuse(H.White) end}
af[#af+1] = Def.BitmapText{Font=H.Font, Text="ENTER MODIFIERS", InitCommand=function(self) self:xy(355,45):horizalign(left):zoom(0.048):diffuse(H.Muted) end}

return af
