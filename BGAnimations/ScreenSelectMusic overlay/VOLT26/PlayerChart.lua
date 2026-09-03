local args = ...
local H = args.H
local player = args.Player
local pn = ToEnumShortString(player)
local accent = H.Accent(player)
-- The right column runs from the preview panel's edge (612) to the screen
-- margin, so the card claims the 28 unused units on its left and keeps equal
-- 12 unit gutters on both sides.  Everything inside is padded 8 from the box.
local cardW = 218
local graphW = cardW - 16

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

local function graphVertices(data, graphColor, graphH)
	local vertices = {}
	if not data or #data.nps == 0 or data.peak <= 0 then return vertices end
	local count = #data.nps
	for i, value in ipairs(data.nps) do
		local x = count == 1 and 0 or (i-1)/(count-1)*graphW
		local y = -math.min(graphH, graphH*value/data.peak)
		vertices[#vertices+1] = {{x,0,0}, {graphColor[1],graphColor[2],graphColor[3],0.18}}
		vertices[#vertices+1] = {{x,y,0}, {graphColor[1],graphColor[2],graphColor[3],0.92}}
	end
	return vertices
end

local function chartLabel(chart)
	if not chart then return H.Dash end
	local fields = {}
	local name = chart.GetChartName and chart:GetChartName() or ""
	local description = chart.GetDescription and chart:GetDescription() or ""
	if name ~= "" then fields[#fields+1] = name end
	if description ~= "" and description ~= name then fields[#fields+1] = description end
	return #fields > 0 and table.concat(fields, "   -   ") or ToEnumShortString(chart:GetStepsType()):upper()
end

local function authorLabel(chart)
	local author = chart and chart.GetAuthorCredit and chart:GetAuthorCredit() or ""
	return author ~= "" and "STEP ARTIST  "..author or "STEP ARTIST  --"
end

local af = Def.ActorFrame{
	Name=pn.."Chart",
	RefreshCommand=function(self)
		local joined = GAMESTATE:IsHumanPlayer(player) and H.Item() ~= nil
		self:visible(joined)
		if not joined then return end

		local single = #GAMESTATE:GetHumanPlayers() == 1
		local panelY = single and 133 or (player == PLAYER_1 and 126 or 286)
		local panelH = single and 289 or 152
		local graphTop = single and 78 or 63
		-- Single player had 64 units of empty box below the stats; the graph
		-- takes most of it back rather than leaving the card looking unfinished.
		local graphH = single and 100 or 24
		self:xy(624, panelY)

		self:GetChild("Background"):zoomto(cardW,panelH)

		local chart = H.Chart(player)
		local data = H.ChartData(player)
		local difficulty = chart and ToEnumShortString(chart:GetDifficulty()):upper() or H.Dash
		local difficultyColor = chart and VOLT26.ChartData.GetDifficultyColor(chart:GetDifficulty()) or accent
		self:GetChild("PlayerLabel"):settext(H.PlayerName(player)):maxwidth(66/H.BoldZoom(0.058))
		self:GetChild("Difficulty"):settext(difficulty):diffuse(H.Muted)
		self:GetChild("Meter"):settext(chart and chart:GetMeter() or H.Dash):diffuse(difficultyColor)
		setLocalizedText(self, "Description", "DescriptionCJK", chartLabel(chart), H.BoldZoom(0.052), 0.48, 199)
		setLocalizedText(self, "Author", "AuthorCJK", authorLabel(chart), H.NormalZoom(0.041), 0.37, 88)
		-- Grouped with plain spacing like the NOTES / JUMPS line below instead of
		-- dashes: the row only affords 106 units, and the separators cost more
		-- of them than the numbers they were framing.
		self:GetChild("Info"):settext(string.format(
			"BPM %s   LENGTH %s   RATE %.2fx",
			H.BPM(player, chart), H.Length(), VOLT26.MusicSelection.GetMusicRate()))

		local graph = self:GetChild("Graph")
		local vertices = graphVertices(data, difficultyColor, graphH)
		graph:xy(8,graphTop+graphH):SetNumVertices(#vertices):SetVertices(vertices)
		self:GetChild("GraphLabel"):xy(8,graphTop-8):settext(
			data.peak > 0 and string.format("DENSITY / MEASURE   PEAK %.1f NPS", data.peak*VOLT26.MusicSelection.GetMusicRate()) or "DENSITY DATA UNAVAILABLE")

		for i=0,4 do
			self:GetChild("VGrid"..i):xy(8+i*graphW/4,graphTop):zoomto(1,graphH)
		end
		for i=0,2 do
			self:GetChild("HGrid"..i):xy(8,graphTop+i*graphH/2):zoomto(graphW,1)
		end

		local afterGraph = graphTop + graphH
		local tech = #data.tech > 0 and table.concat(data.tech, "   ") or "NO TECH ANNOTATIONS"
		self:GetChild("TechTitle"):xy(8,afterGraph+18):settext("TECH")
		self:GetChild("Tech"):xy(8,afterGraph+32):settext(tech):maxwidth(200/H.BoldZoom(0.044))
		self:GetChild("Stats"):xy(8,afterGraph+50):settext(string.format(
			"NOTES %d   JUMPS %d   HOLDS %d   MINES %d",
			data.notes or 0, data.jumps or 0, data.holds or 0, data.mines or 0))
		self:GetChild("Extra"):xy(8,afterGraph+71):visible(single):settext(string.format(
			"ROLLS %d   HANDS %d   TAP + HOLD OBJECTS %d",
			data.rolls or 0, data.hands or 0, data.notes or 0))
	end,
}

af[#af+1] = Def.Quad{Name="Background", InitCommand=function(self) self:align(0,0):diffuse(H.Surface):diffusealpha(H.SurfaceAlpha) end}

af[#af+1] = Def.BitmapText{
	Name="PlayerLabel", Font=H.FontBold, Text=pn,
	InitCommand=function(self) self:xy(8,12):horizalign(left):zoom(H.BoldZoom(0.058)):diffuse(H.Black) end,
}
af[#af+1] = Def.BitmapText{
	Name="Difficulty", Font=H.FontBold,
	InitCommand=function(self) self:xy(76,12):horizalign(left):zoom(H.BoldZoom(0.058)):diffuse(H.Muted):maxwidth(96/H.BoldZoom(0.058)) end,
}
af[#af+1] = Def.BitmapText{
	Name="Meter", Font=H.FontBold,
	InitCommand=function(self) self:xy(210,12):horizalign(right):zoom(H.BoldZoom(0.092)):diffuse(accent) end,
}
af[#af+1] = Def.BitmapText{
	Name="Description", Font=H.FontBold,
	InitCommand=function(self) self:xy(8,29):horizalign(left):zoom(H.BoldZoom(0.052)):diffuse(H.Black) end,
}
af[#af+1] = Def.BitmapText{
	Name="DescriptionCJK", Font="Common Normal",
	InitCommand=function(self) self:xy(8,29):horizalign(left):zoom(0.48):diffuse(H.Black):visible(false) end,
}
af[#af+1] = Def.BitmapText{
	Name="Author", Font=H.Font,
	InitCommand=function(self) self:xy(8,43):horizalign(left):zoom(H.NormalZoom(0.041)):diffuse(H.Muted) end,
}
af[#af+1] = Def.BitmapText{
	Name="AuthorCJK", Font="Common Normal",
	InitCommand=function(self) self:xy(8,43):horizalign(left):zoom(0.37):diffuse(H.Muted):visible(false) end,
}
af[#af+1] = Def.BitmapText{
	Name="Info", Font=H.FontBold,
	InitCommand=function(self) self:xy(210,43):horizalign(right):zoom(H.BoldZoom(0.042)):diffuse(H.Black):maxwidth(112/H.BoldZoom(0.042)) end,
}

for i=0,4 do
	af[#af+1] = Def.Quad{Name="VGrid"..i, InitCommand=function(self) self:align(0,0):diffuse(H.White):diffusealpha(0.13) end}
end
for i=0,2 do
	af[#af+1] = Def.Quad{Name="HGrid"..i, InitCommand=function(self) self:align(0,0):diffuse(H.White):diffusealpha(0.13) end}
end

af[#af+1] = Def.ActorMultiVertex{
	Name="Graph",
	InitCommand=function(self) self:SetDrawState({Mode="DrawMode_QuadStrip"}) end,
}
af[#af+1] = Def.BitmapText{
	Name="GraphLabel", Font=H.FontBold,
	InitCommand=function(self) self:horizalign(left):zoom(H.BoldZoom(0.039)):diffuse(H.Muted) end,
}
af[#af+1] = Def.BitmapText{
	Name="Stats", Font=H.Font,
	InitCommand=function(self) self:horizalign(left):zoom(H.NormalZoom(0.044)):diffuse(H.Black):maxwidth(200/H.NormalZoom(0.044)) end,
}
af[#af+1] = Def.BitmapText{
	Name="TechTitle", Font=H.FontBold,
	InitCommand=function(self) self:horizalign(left):zoom(H.BoldZoom(0.052)):diffuse(H.Black) end,
}
af[#af+1] = Def.BitmapText{
	Name="Tech", Font=H.FontBold,
	InitCommand=function(self) self:horizalign(left):zoom(H.BoldZoom(0.044)):diffuse(H.Black) end,
}
af[#af+1] = Def.BitmapText{
	Name="Extra", Font=H.Font,
	InitCommand=function(self) self:horizalign(left):zoom(H.NormalZoom(0.044)):diffuse(H.Black) end,
}
H.AddSettledRefresh(af, 0.35, 16, 0)
return af
