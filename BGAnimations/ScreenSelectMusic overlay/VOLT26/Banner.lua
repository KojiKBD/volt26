local H = ...

local af = Def.ActorFrame{
	Name="SelectedBanner",
	InitCommand=function(self) self:xy(286,35):rotationz(-1.2) end,
}

af[#af+1] = H.Polygon({{-7,5},{349,-4},{362,99},{7,113}}, H.White)
af[#af+1] = H.Polygon({{0,9},{344,3},{351,94},{5,105}}, H.Black)
af[#af+1] = Def.Quad{
	InitCommand=function(self) self:align(0,0):xy(8,12):zoomto(335,78):diffuse(color("#222222")) end,
}

af[#af+1] = Def.Sprite{
	Name="LiveBanner",
	InitCommand=function(self) self:xy(175,51) end,
	RefreshCommand=function(self)
		local item = H.Item()
		local path = item and item.HasBanner and item:HasBanner() and item:GetBannerPath() or nil
		if path and path ~= "" then
			self:Load(path):scaletoclipped(335,78):visible(true)
		else
			self:visible(false)
		end
	end,
}

-- Metadata strips overlap the banner edge without obscuring its center.
af[#af+1] = H.Polygon({{8,76},{245,72},{252,103},{2,107}}, color("#050505dd"))
af[#af+1] = Def.BitmapText{
	Name="Title", Font=H.Font,
	InitCommand=function(self) self:xy(15,84):horizalign(left):zoom(0.092):maxwidth(220/0.092):diffuse(H.White) end,
	RefreshCommand=function(self) self:settext(H.Title(H.Item())) end,
}
af[#af+1] = Def.BitmapText{
	Name="Artist", Font=H.Font,
	InitCommand=function(self) self:xy(15,99):horizalign(left):zoom(0.052):maxwidth(215/0.052):diffuse(H.Muted) end,
	RefreshCommand=function(self) self:settext(H.Artist(H.Item())) end,
}

af[#af+1] = Def.ActorFrame{
	InitCommand=function(self) self:xy(315,91):rotationz(4) end,
	Def.Quad{InitCommand=function(self) self:zoomto(68,37):skewx(-0.18):diffuse(H.P1) end},
	Def.Quad{InitCommand=function(self) self:zoomto(58,30):skewx(-0.18):diffuse(H.Black) end},
	Def.BitmapText{Font=H.Font, Text="BPM", InitCommand=function(self) self:y(-7):zoom(0.043):diffuse(H.White) end},
	Def.BitmapText{
		Name="BPM", Font=H.Font,
		InitCommand=function(self) self:y(7):zoom(0.082):diffuse(H.White):maxwidth(52/0.082) end,
		RefreshCommand=function(self)
			local player = GAMESTATE:GetMasterPlayerNumber()
			self:settext(player and H.BPM(player, H.Chart(player)) or H.Dash)
		end,
	},
}

H.AddRefresh(af)
return af
