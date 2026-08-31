local H = ...
local titleZoom = H.BoldZoom(0.105)

local af = Def.ActorFrame{
	Name="SongInfo",
	InitCommand=function(self) self:xy(640,18) end,
	RefreshCommand=function(self)
		local item = H.Item()
		local sourcePlayer, sourceChart = H.PreviewSource()
		if not item or GAMESTATE:IsCourseMode() then sourceChart = nil end
		local title = self:GetChild("Title")
		title:zoom(titleZoom):settext(H.Title(item))
		local titleWidth = title:GetZoomedWidth()
		if titleWidth > 201 then title:zoom(titleZoom * 201/titleWidth) end
		self:GetChild("Artist"):settext(H.Artist(item)):maxwidth(201/H.NormalZoom(0.065))
		local author = sourceChart and sourceChart.GetAuthorCredit and sourceChart:GetAuthorCredit() or ""
		local description = sourceChart and sourceChart.GetDescription and sourceChart:GetDescription() or ""
		local details = {}
		if author ~= "" then details[#details+1] = "STEP ARTIST  "..author end
		if description ~= "" and description ~= author then details[#details+1] = description end
		if sourceChart then details[#details+1] = "BPM "..H.BPM(sourcePlayer, sourceChart) end
		self:GetChild("Details"):settext(table.concat(details, "   -   ")):maxwidth(201/H.NormalZoom(0.037))
	end,
}

af[#af+1] = Def.BitmapText{
	Name="Title", Font=H.FontBold,
	InitCommand=function(self)
		self:xy(0,20):horizalign(left):zoom(titleZoom):diffuse(H.Black)
	end,
}
af[#af+1] = Def.BitmapText{
	Name="Artist", Font=H.Font,
	InitCommand=function(self) self:xy(0,45):horizalign(left):zoom(H.NormalZoom(0.065)):diffuse(H.Muted) end,
}
af[#af+1] = Def.BitmapText{
	Name="Details", Font=H.Font,
	InitCommand=function(self) self:xy(1,68):horizalign(left):zoom(H.NormalZoom(0.037)):diffuse(H.Black) end,
}

H.AddRefresh(af)
return af
