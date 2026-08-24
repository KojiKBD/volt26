local args = ...
local H = args.H
local player = args.Player
local pn = ToEnumShortString(player)
local accent = H.Accent(player)
local graphW, graphH = 270, 42

local function graphVertices(data, graphColor)
	local vertices = {}
	if not data or #data.nps == 0 or data.peak <= 0 then return vertices end
	local count = #data.nps
	for i, value in ipairs(data.nps) do
		local x = count == 1 and 0 or (i-1)/(count-1)*graphW
		local y = -math.min(graphH, graphH*value/data.peak)
		vertices[#vertices+1] = {{x,0,0}, {graphColor[1],graphColor[2],graphColor[3],0.35}}
		vertices[#vertices+1] = {{x,y,0}, {graphColor[1],graphColor[2],graphColor[3],0.95}}
	end
	return vertices
end

local af = Def.ActorFrame{
	Name=pn.."Chart",
	InitCommand=function(self) self:xy(278,args.Y) end,
	RefreshCommand=function(self)
		local joined = GAMESTATE:IsHumanPlayer(player) and H.Item() ~= nil
		self:visible(joined)
		if not joined then return end
		local chart = H.Chart(player)
		local data = H.ChartData(player)
		local difficulty = chart and ToEnumShortString(chart:GetDifficulty()):upper() or H.Dash
		local difficultyColor = chart and VOLT26.ChartData.GetDifficultyColor(chart:GetDifficulty()) or accent
		self:GetChild("Difficulty"):settext(difficulty):diffuse(difficultyColor)
		self:GetChild("Meter"):settext(chart and chart:GetMeter() or H.Dash):diffuse(difficultyColor)
		self:GetChild("Peak"):settext(data.peak > 0 and string.format("PEAK %.1f NPS", data.peak * VOLT26.MusicSelection.GetMusicRate()) or "NO DENSITY DATA")
		local vertices = graphVertices(data, difficultyColor)
		self:GetChild("Graph"):SetNumVertices(#vertices):SetVertices(vertices)
		self:GetChild("Stats"):settext(string.format(
			"NOTES %d  |  JUMPS %d  |  HOLDS %d  |  MINES %d  |  ROLLS %d  |  HANDS %d  |  %s",
			data.notes or 0, data.jumps or 0, data.holds or 0, data.mines or 0,
			data.rolls or 0, data.hands or 0, H.Length()))
		local tech = #data.tech > 0 and table.concat(data.tech, "  //  ") or "NO ENGINE TECH FLAGS"
		self:GetChild("Tech"):settext("TECH  "..tech)
		self:GetChild("EndTime"):settext(H.Length())
	end,
}

af[#af+1] = H.Polygon({{-5,0},{350,-3},{345,96},{2,99}}, color("#080808ee"))
af[#af+1] = Def.Quad{InitCommand=function(self) self:align(0,0):xy(-3,-1):zoomto(92,3):rotationz(-1):diffuse(accent) end}
af[#af+1] = Def.Quad{InitCommand=function(self) self:align(0,0):xy(7,94):zoomto(332,2):rotationz(0.5):diffuse(accent):diffusealpha(0.75) end}

af[#af+1] = Def.BitmapText{
	Font=H.Font, Text=pn,
	InitCommand=function(self) self:xy(8,8):horizalign(left):zoom(0.112):diffuse(accent) end,
}
af[#af+1] = Def.BitmapText{
	Name="Difficulty", Font=H.Font,
	InitCommand=function(self) self:xy(8,27):horizalign(left):zoom(0.055):diffuse(accent):maxwidth(62/0.055) end,
}
af[#af+1] = Def.BitmapText{
	Name="Meter", Font=H.Font,
	InitCommand=function(self) self:xy(8,50):horizalign(left):zoom(0.12):diffuse(accent) end,
}
af[#af+1] = Def.BitmapText{
	Name="Peak", Font=H.Font,
	InitCommand=function(self) self:xy(8,76):horizalign(left):zoom(0.038):diffuse(H.Muted):maxwidth(66/0.038) end,
}

for i=0,4 do
	af[#af+1] = Def.Quad{
		InitCommand=function(self) self:align(0,0):xy(77+i*graphW/4,10):zoomto(1,graphH):diffuse(H.White):diffusealpha(0.15) end,
	}
end
for i=0,2 do
	af[#af+1] = Def.Quad{
		InitCommand=function(self) self:align(0,0):xy(77,10+i*graphH/2):zoomto(graphW,1):diffuse(H.White):diffusealpha(0.16) end,
	}
end

af[#af+1] = Def.ActorMultiVertex{
	Name="Graph",
	InitCommand=function(self) self:xy(77,52):SetDrawState({Mode="DrawMode_QuadStrip"}) end,
}
af[#af+1] = Def.BitmapText{
	Font=H.Font, Text="NPS / MEASURE",
	InitCommand=function(self) self:xy(78,6):horizalign(left):zoom(0.032):diffuse(H.Muted) end,
}
af[#af+1] = Def.BitmapText{
	Font=H.Font, Text="0:00",
	InitCommand=function(self) self:xy(77,57):horizalign(left):zoom(0.029):diffuse(H.Muted) end,
}
af[#af+1] = Def.BitmapText{
	Name="EndTime", Font=H.Font,
	InitCommand=function(self) self:xy(347,57):horizalign(right):zoom(0.029):diffuse(H.Muted) end,
}
af[#af+1] = Def.BitmapText{
	Name="Stats", Font=H.Font,
	InitCommand=function(self) self:xy(8,69):horizalign(left):zoom(0.035):diffuse(H.White):maxwidth(334/0.035) end,
}
af[#af+1] = Def.BitmapText{
	Name="Tech", Font=H.Font,
	InitCommand=function(self) self:xy(8,86):horizalign(left):zoom(0.033):diffuse(H.Muted):maxwidth(334/0.033) end,
}

H.AddRefresh(af)
return af
