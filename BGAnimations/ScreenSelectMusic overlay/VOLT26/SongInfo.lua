local H = ...
local titleZoom = H.BoldZoom(0.105)

local function hasNonASCII(text)
	return tostring(text or ""):find("[\128-\255]") ~= nil
end

local function setLocalizedText(frame, latinName, cjkName, text, latinZoom, cjkZoom, width)
	local useCJK = hasNonASCII(text)
	local latin = frame:GetChild(latinName)
	local cjk = frame:GetChild(cjkName)
	latin:visible(not useCJK):settext(text):zoom(latinZoom):maxwidth(width/latinZoom)
	cjk:visible(useCJK):settext(text):zoom(cjkZoom):maxwidth(width/cjkZoom)
end

local af = Def.ActorFrame{
	Name="SongInfo",
	InitCommand=function(self) self:xy(624,18) end,
	RefreshCommand=function(self)
		local item = H.Item()
		local sourcePlayer, sourceChart = H.PreviewSource()
		if not item or GAMESTATE:IsCourseMode() then sourceChart = nil end
		local title = self:GetChild("Title")
		title:zoom(titleZoom):settext(H.Title(item))
		local titleWidth = title:GetZoomedWidth()
		if titleWidth > 217 then title:zoom(titleZoom * 217/titleWidth) end
		setLocalizedText(self, "Artist", "ArtistCJK", H.Artist(item), H.NormalZoom(0.065), 0.48, 217)
		local author = sourceChart and sourceChart.GetAuthorCredit and sourceChart:GetAuthorCredit() or ""
		local description = sourceChart and sourceChart.GetDescription and sourceChart:GetDescription() or ""
		local details = {}
		if author ~= "" then details[#details+1] = "STEP ARTIST  "..author end
		if description ~= "" and description ~= author then details[#details+1] = description end
		if sourceChart then details[#details+1] = "BPM "..H.BPM(sourcePlayer, sourceChart) end
		setLocalizedText(self, "Details", "DetailsCJK", table.concat(details, "   -   "), H.NormalZoom(0.037), 0.34, 217)
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
	Name="ArtistCJK", Font="Common Normal",
	InitCommand=function(self) self:xy(0,45):horizalign(left):zoom(0.48):diffuse(H.Muted):visible(false) end,
}
af[#af+1] = Def.BitmapText{
	Name="Details", Font=H.Font,
	InitCommand=function(self) self:xy(1,68):horizalign(left):zoom(H.NormalZoom(0.037)):diffuse(H.Black) end,
}
af[#af+1] = Def.BitmapText{
	Name="DetailsCJK", Font="Common Normal",
	InitCommand=function(self) self:xy(1,68):horizalign(left):zoom(0.34):diffuse(H.Black):visible(false) end,
}

H.AddSettledRefresh(af, 0.35, 16, 0)
return af
