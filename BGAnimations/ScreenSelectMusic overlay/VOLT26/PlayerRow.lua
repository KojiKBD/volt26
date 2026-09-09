local args = ...
local H = args.H
local player = args.Player
local pn = ToEnumShortString(player)
local accent = H.Accent(player)

-- One horizontal row per player, holding everything about that player: the
-- difficulty column, the card, and the chart preview.  Nothing here is shared
-- information -- the song, its BPM, its length and its pack all live in the
-- header above.

local gap = 16
local difficultyW = 206
local previewW = 196
local headerH = 44
local slotGap = 6
local radarW = 280
local contentPadX = 18
local contentPadY = 14
local blockGap = 12
local countersPadY = 8

local rowX = H.RowsX
local rowW = H.RowsW
local cardX = rowX + difficultyW + gap
local cardW = rowW - difficultyW - previewW - 2*gap
local previewX = rowX + rowW - previewW
local contentW = cardW - radarW - 1
local contentX = cardX + contentPadX
local contentInnerW = contentW - contentPadX*2

local difficulties = {
	{"Difficulty_Beginner",  "NOVICE"},
	{"Difficulty_Easy",      "EASY"},
	{"Difficulty_Medium",    "MEDIUM"},
	{"Difficulty_Hard",      "HARD"},
	{"Difficulty_Challenge", "CHALLENGE"},
}

local counters = {
	{"NOTES", "notes"},
	{"JUMPS", "jumps"},
	{"HOLDS", "holds"},
	{"MINES", "mines"},
	{"ROLLS", "rolls"},
	{"HANDS", "hands"},
}

-- The design shortens two of the radar's axis names to keep both ends of the
-- hexagon inside the column.
local axisNames = {
	FOOTSWITCH = "FOOTSW",
	SIDESWITCH = "SIDESW",
}

local gradeStars = {
	Grade_Tier00 = 5, Grade_Tier01 = 4, Grade_Tier02 = 3,
	Grade_Tier03 = 2, Grade_Tier04 = 1,
}
local gradeLetters = {
	Grade_Tier05 = "s-plus.png",  Grade_Tier06 = "s.png",       Grade_Tier07 = "s-minus.png",
	Grade_Tier08 = "a-plus.png",  Grade_Tier09 = "a.png",       Grade_Tier10 = "a-minus.png",
	Grade_Tier11 = "b-plus.png",  Grade_Tier12 = "b.png",       Grade_Tier13 = "b-minus.png",
	Grade_Tier14 = "c-plus.png",  Grade_Tier15 = "c.png",       Grade_Tier16 = "c-minus.png",
	Grade_Tier17 = "d.png",       Grade_Tier99 = "q.png",       Grade_Failed = "f.png",
}
local maxGradeStars = 5
local gradeAssetSize = 200
local gradeIconSize = 15
local transparent = color("0,0,0,0")

local radarLabelDistance = 1.28
local radarLabelWidth = 46
local radarEdgeMargin = 8
local radarMaxRadius = math.floor(
	(radarW/2 - radarLabelWidth - radarEdgeMargin) / (math.cos(math.rad(30)) * radarLabelDistance))

local radarAxisCount = VOLT26.ChartRadar.GetAxisCount()
local radarAngles = {}
for i=1, radarAxisCount do
	radarAngles[i] = math.rad(-90 + (i-1) * (360/radarAxisCount))
end

local function gradeAssetPath(file)
	return THEME:GetPathG("", "_grades/assets/"..file)
end

local function radarPoint(radius, index)
	local angle = radarAngles[index]
	return math.cos(angle)*radius, math.sin(angle)*radius
end

local function uniformRadii(radius)
	local radii = {}
	for i=1, radarAxisCount do radii[i] = radius end
	return radii
end

-- Every radar shape is a quad strip: a filled area is a fan of degenerate quads
-- anchored on the centre, an outline is a band between two radii.
local function fanVertices(radii, rgba)
	local vertices = {}
	for i=1, radarAxisCount+1 do
		local index = i <= radarAxisCount and i or 1
		local x, y = radarPoint(radii[index] or 0, index)
		vertices[#vertices+1] = {{0,0,0}, rgba}
		vertices[#vertices+1] = {{x,y,0}, rgba}
	end
	return vertices
end

local function bandVertices(radii, width, rgba)
	local vertices = {}
	local half = width/2
	for i=1, radarAxisCount+1 do
		local index = i <= radarAxisCount and i or 1
		local radius = radii[index] or 0
		local ix, iy = radarPoint(math.max(0, radius-half), index)
		local ox, oy = radarPoint(radius+half, index)
		vertices[#vertices+1] = {{ix,iy,0}, rgba}
		vertices[#vertices+1] = {{ox,oy,0}, rgba}
	end
	return vertices
end

local function setVertices(actor, vertices)
	actor:SetNumVertices(#vertices):SetVertices(vertices)
end

-- The density profile is sampled to a fixed width so a short chart and a long
-- one are read the same way, and so the peaks stay visible on a chart with more
-- measures than the graph has pixels.
local densitySamples = 96

local function densityVertices(data, graphW, graphH)
	local vertices = {}
	if not data or #data.nps == 0 or data.peak <= 0 then return vertices end
	local count = #data.nps
	local tint = {accent[1], accent[2], accent[3], 0.85}
	for sample = 0, densitySamples do
		local position = sample/densitySamples
		local index = math.min(count, math.max(1, math.floor(position*(count-1)) + 1))
		local value = data.nps[index] or 0
		local x = position*graphW
		local y = -math.min(graphH, graphH*value/data.peak)
		vertices[#vertices+1] = {{x,0,0}, tint}
		vertices[#vertices+1] = {{x,y,0}, tint}
	end
	return vertices
end

local function stepsForDifficulty(difficulty)
	local song = H.Item()
	if not song or GAMESTATE:IsCourseMode() or not song.GetStepsByStepsType then return nil end
	local style = GAMESTATE:GetCurrentStyle()
	local stepsType = style and style:GetStepsType() or nil
	if not stepsType then return nil end
	local ok, charts = pcall(function() return song:GetStepsByStepsType(stepsType) end)
	if not ok or not charts then return nil end
	for chart in ivalues(charts) do
		if ToEnumShortString(chart:GetDifficulty()) == ToEnumShortString(difficulty) then return chart end
	end
	return nil
end

local function formatPercent(value)
	if type(value) ~= "number" then return H.Dash end
	return string.format("%.2f", value)
end

local function setGradeIcon(frame, grade)
	local letter = frame:GetChild("GradeLetter")
	local file = grade and gradeLetters[grade] or nil
	local stars = grade and gradeStars[grade] or 0

	if file then
		local path = gradeAssetPath(file)
		if frame.loadedPath ~= path then
			local ok = pcall(function() letter:Load(path) end)
			frame.loadedPath = ok and path or nil
		end
		letter:visible(frame.loadedPath ~= nil):zoom(gradeIconSize/gradeAssetSize)
	else
		letter:visible(false)
	end

	-- A star grade shows the whole row so the tier reads as a position on a
	-- scale; a letter grade has no stars to place, so the row stays empty.
	for i=1, maxGradeStars do
		frame:GetChild("GradeStar"..i)
			:visible(stars > 0)
			:zoom(gradeIconSize/gradeAssetSize)
			:x((i-1)*gradeIconSize)
			:diffuse(i <= stars and accent or H.Line)
	end
end

local af = Def.ActorFrame{
	Name=pn.."Row",
	RefreshCommand=function(self)
		local joined = GAMESTATE:IsHumanPlayer(player)
		self:visible(joined)
		if not joined then return end

		local rowTop, rowH = H.RowGeometry(player)
		local bodyTop = rowTop + headerH
		local bodyH = rowH - headerH
		local chart = H.Chart(player)
		local data = H.ChartData(player)

		self:playcommand("LayOut", {RowTop=rowTop, RowHeight=rowH, BodyTop=bodyTop, BodyHeight=bodyH})
		self:playcommand("Fill", {Chart=chart, Data=data, BodyTop=bodyTop, BodyHeight=bodyH, RowTop=rowTop})
	end,
}

-- ---------------------------------------------------------------- difficulty

local difficultyColumn = Def.ActorFrame{
	Name="Difficulty",
	LayOutCommand=function(self, p)
		local slotH = (p.BodyHeight - slotGap*(#difficulties-1))/#difficulties
		self:GetChild("Badge"):xy(rowX, p.RowTop + headerH/2)
		local badgeLabel = self:GetChild("BadgeLabel")
		H.SetLabel(badgeLabel, pn, 11)
		local badgeWidth = badgeLabel:GetZoomedWidth() + 16
		self:GetChild("Badge"):zoomto(badgeWidth, 18)
		badgeLabel:xy(rowX + badgeWidth/2, p.RowTop + headerH/2)
		local caption = self:GetChild("Caption")
		H.SetLabel(caption, H.String("Difficulty"), 11, difficultyW - badgeWidth - 10)
		caption:xy(rowX + badgeWidth + 10, p.RowTop + headerH/2)

		for i=1, #difficulties do
			local top = p.BodyTop + (i-1)*(slotH + slotGap)
			self:GetChild("Border"..i):xy(rowX, top):zoomto(difficultyW, slotH)
			self:GetChild("Slot"..i):xy(rowX+1, top+1):zoomto(difficultyW-2, slotH-2)
			self:GetChild("Name"..i):xy(rowX+16, top + slotH/2)
			self:GetChild("Meter"..i):xy(rowX+difficultyW-16, top + slotH/2)
		end
	end,
	FillCommand=function(self, p)
		for i, entry in ipairs(difficulties) do
			local steps = stepsForDifficulty(entry[1])
			local selected = steps ~= nil and steps == p.Chart
			local border = self:GetChild("Border"..i)
			local slot = self:GetChild("Slot"..i)
			if selected then
				slot:diffuse(accent):diffusealpha(0.55)
					:diffuserightedge(color(("%f,%f,%f,0.04"):format(accent[1], accent[2], accent[3])))
				border:diffuse(accent)
			else
				slot:diffuse(color("1,1,1,0.055")):diffuserightedge(transparent)
				border:diffuse(H.Line)
			end
			local nameTint = selected and H.Ink or (steps and H.Mute or H.Dim)
			H.SetLabel(self:GetChild("Name"..i), entry[2], 12, difficultyW-90)
			self:GetChild("Name"..i):diffuse(nameTint)
			H.SetDisplay(self:GetChild("Meter"..i), steps and steps:GetMeter() or "", 26)
			self:GetChild("Meter"..i):diffuse(selected and H.Ink or (steps and H.Mute or H.Dim))
		end
	end,
}
difficultyColumn[#difficultyColumn+1] = Def.Quad{
	Name="Badge",
	InitCommand=function(self) self:align(0,0.5):diffuse(accent) end,
}
difficultyColumn[#difficultyColumn+1] = H.LabelText{Name="BadgeLabel", Px=11, Tint=H.Ink, Align=center}
difficultyColumn[#difficultyColumn+1] = H.LabelText{Name="Caption", Px=11, Tint=H.Mute}
for i=1, #difficulties do
	difficultyColumn[#difficultyColumn+1] = H.Rule{Name="Border"..i}
	difficultyColumn[#difficultyColumn+1] = Def.Quad{
		Name="Slot"..i,
		InitCommand=function(self) self:align(0,0) end,
	}
	difficultyColumn[#difficultyColumn+1] = H.LabelText{Name="Name"..i, Px=12, Tint=H.Mute}
	difficultyColumn[#difficultyColumn+1] = H.DisplayText{Name="Meter"..i, Px=26, Tint=H.Mute, Align=right}
end
af[#af+1] = difficultyColumn

-- --------------------------------------------------------------------- card

local card = Def.ActorFrame{
	Name="Card",
	LayOutCommand=function(self, p)
		self:GetChild("Border"):xy(cardX-1, p.RowTop-1):zoomto(cardW+2, p.RowHeight+2)
		self:GetChild("Background"):xy(cardX, p.RowTop):zoomto(cardW, p.RowHeight)
		self:GetChild("Accent"):xy(cardX, p.RowTop):zoomto(cardW, 2)
		self:GetChild("HeaderRule"):xy(cardX, p.BodyTop):zoomto(cardW, 1)
		self:GetChild("RadarRule"):xy(cardX + contentW, p.BodyTop):zoomto(1, p.BodyHeight)

		local headerMiddle = p.RowTop + headerH/2 + 1
		self:GetChild("Badge"):xy(cardX + contentPadX, headerMiddle)
		self:GetChild("BadgeLabel"):y(headerMiddle)
		self:GetChild("Name"):y(headerMiddle)
		self:GetChild("ChartLine"):y(headerMiddle)
		self:GetChild("Rate"):y(headerMiddle)
		self:GetChild("Author"):y(headerMiddle)
	end,
	FillCommand=function(self, p)
		local headerMiddle = p.RowTop + headerH/2 + 1
		local badgeLabel = self:GetChild("BadgeLabel")
		H.SetLabel(badgeLabel, pn, 11)
		local badgeWidth = badgeLabel:GetZoomedWidth() + 16
		self:GetChild("Badge"):zoomto(badgeWidth, 18)
		badgeLabel:x(cardX + contentPadX + badgeWidth/2)
		H.SetDisplay(self:GetChild("Name"), H.PlayerName(player), 23, 240)
		self:GetChild("Name"):x(cardX + contentPadX + badgeWidth + 12)

		-- The right of the header reads back what the player has actually
		-- chosen, laid out from the card's right edge so a long step artist
		-- credit gives ground instead of pushing the rate off the card.
		local chart = p.Chart
		local difficulty = chart and ToEnumShortString(chart:GetDifficulty()):upper() or ""
		local meter = chart and tostring(chart:GetMeter()) or H.Dash
		local author = chart and chart.GetAuthorCredit and chart:GetAuthorCredit() or ""

		local right = cardX + cardW - contentPadX
		local authorText = self:GetChild("Author")
		H.SetLabel(authorText, author ~= "" and ("STEPS BY "..author) or "", 11, 220)
		authorText:x(right)
		right = right - (author ~= "" and authorText:GetZoomedWidth() + 22 or 0)

		local rate = self:GetChild("Rate")
		H.SetLabel(rate, string.format("RATE %.2fx", VOLT26.MusicSelection.GetMusicRate()), 11)
		rate:x(right)
		right = right - rate:GetZoomedWidth() - 22

		local chartLine = self:GetChild("ChartLine")
		H.SetLabel(chartLine, difficulty ~= "" and (difficulty.." "..meter) or "", 11, 220)
		chartLine:x(right)
	end,
}
card[#card+1] = H.Rule{Name="Border"}
card[#card+1] = H.Rule{Name="Background", Tint=H.Panel}
card[#card+1] = H.Rule{Name="Accent", Tint=accent}
card[#card+1] = H.Rule{Name="HeaderRule"}
card[#card+1] = H.Rule{Name="RadarRule"}
card[#card+1] = Def.Quad{Name="Badge", InitCommand=function(self) self:align(0,0.5):diffuse(accent) end}
card[#card+1] = H.LabelText{Name="BadgeLabel", Px=11, Tint=H.Ink, Align=center}
card[#card+1] = H.DisplayText{Name="Name", Px=23, Tint=H.Ink}
card[#card+1] = H.LabelText{Name="ChartLine", Px=11, Tint=H.Mute, Align=right}
card[#card+1] = H.LabelText{Name="Rate", Px=11, Tint=H.Mute, Align=right}
card[#card+1] = H.LabelText{Name="Author", Px=11, Tint=H.Dim, Align=right}
af[#af+1] = card

-- --------------------------------------------------------------- card body

local body = Def.ActorFrame{
	Name="Body",
	LayOutCommand=function(self, p)
		local inner = p.BodyHeight - contentPadY*2
		-- The score row is a 9 unit label sitting on a 40 unit number, both
		-- anchored on the same baseline.
		local scoreH = 58
		local countersH = 9 + 21 + countersPadY*2 + 6
		local graphH = inner - scoreH - countersH - blockGap*2
		local top = p.BodyTop + contentPadY

		local countersTop = top + scoreH + blockGap
		local graphTop = countersTop + countersH + blockGap
		local plotTop = graphTop + 14
		-- Only what FillCommand needs later is kept on the frame.
		self.scoreBaseline = top + scoreH
		self.plotHeight = math.max(20, graphH - 14)

		self:GetChild("CountersTopRule"):xy(contentX, countersTop):zoomto(contentInnerW, 1)
		self:GetChild("CountersBottomRule")
			:xy(contentX, countersTop + countersH):zoomto(contentInnerW, 1)

		local cellWidth = contentInnerW/#counters
		for i=1, #counters do
			local x = contentX + (i-0.5)*cellWidth
			self:GetChild("CounterLabel"..i):xy(x, countersTop + countersPadY + 5)
			self:GetChild("CounterValue"..i):xy(x, countersTop + countersPadY + 24)
		end

		local plotHeight = self.plotHeight
		self:GetChild("GraphLabel"):xy(contentX, graphTop + 4)
		self:GetChild("GraphPeak"):xy(contentX + contentInnerW, graphTop + 4)
		self:GetChild("PlotBorder"):xy(contentX-1, plotTop-1):zoomto(contentInnerW+2, plotHeight+2)
		self:GetChild("Plot"):xy(contentX, plotTop):zoomto(contentInnerW, plotHeight)
		for i=1, 15 do
			self:GetChild("PlotGrid"..i)
				:xy(contentX + i*contentInnerW/16, plotTop):zoomto(0.6, plotHeight)
		end
		self:GetChild("Density"):xy(contentX, plotTop + plotHeight)
	end,
	FillCommand=function(self, p)
		local data = p.Data
		local best = VOLT26.ScoreIndex.GetBest(player, H.Item(), p.Chart)

		local x = contentX
		local baseline = self.scoreBaseline
		local function scoreBlock(labelName, valueName, suffixName, labelText, valueText, tint)
			local label = self:GetChild(labelName)
			H.SetLabel(label, labelText, 9)
			label:xy(x, baseline - 50)
			local value = self:GetChild(valueName)
			H.SetDisplay(value, valueText, 40)
			value:xy(x, baseline):diffuse(tint)
			local width = value:GetZoomedWidth()
			if suffixName then
				local suffix = self:GetChild(suffixName)
				H.SetDisplay(suffix, "%", 18)
				suffix:xy(x + width + 3, baseline)
				width = width + 3 + suffix:GetZoomedWidth()
			end
			x = x + math.max(width, label:GetZoomedWidth()) + 34
		end

		scoreBlock("BestLabel", "BestValue", "BestSuffix", "BEST - ITG",
			formatPercent(best and best.PercentDP and best.PercentDP*100 or nil), H.Ink)
		scoreBlock("ExLabel", "ExValue", "ExSuffix", "EX",
			formatPercent(best and best.ExPercent or nil),
			best and best.ExPercent and H.Ink or H.Mute)

		local gradeLabel = self:GetChild("GradeLabel")
		H.SetLabel(gradeLabel, "GRADE", 9)
		gradeLabel:xy(x, baseline - 50)
		local gradeIcon = self:GetChild("GradeIcon")
		gradeIcon:xy(x, baseline - gradeIconSize/2 - 4)
		setGradeIcon(gradeIcon, best and best.Grade or nil)

		for i, counter in ipairs(counters) do
			local value = data[counter[2]] or 0
			H.SetLabel(self:GetChild("CounterLabel"..i), counter[1], 9)
			H.SetDisplay(self:GetChild("CounterValue"..i), value, 21)
			-- A count of zero is a fact about the chart, not a number to read,
			-- so it steps back to the label colour.
			self:GetChild("CounterValue"..i):diffuse(value > 0 and H.Ink or H.Dim)
		end

		H.SetLabel(self:GetChild("GraphLabel"), "DENSITY / MEASURE", 9)
		local peak = data.peak*VOLT26.MusicSelection.GetMusicRate()
		H.SetLabel(self:GetChild("GraphPeak"),
			data.peak > 0 and string.format("PEAK %.1f NPS", peak) or "NO DENSITY DATA", 9)
		self:GetChild("GraphPeak"):diffuse(data.peak > 0 and accent or H.Dim)

		local density = self:GetChild("Density")
		local vertices = densityVertices(data, contentInnerW, self.plotHeight)
		setVertices(density, vertices)
	end,
}
body[#body+1] = H.LabelText{Name="BestLabel", Px=9, Tint=H.Dim}
body[#body+1] = H.DisplayText{Name="BestValue", Px=40, Tint=H.Ink, VAlign=bottom}
body[#body+1] = H.DisplayText{Name="BestSuffix", Px=18, Tint=H.Mute, VAlign=bottom}
body[#body+1] = H.LabelText{Name="ExLabel", Px=9, Tint=H.Dim}
body[#body+1] = H.DisplayText{Name="ExValue", Px=40, Tint=H.Mute, VAlign=bottom}
body[#body+1] = H.DisplayText{Name="ExSuffix", Px=18, Tint=H.Mute, VAlign=bottom}
body[#body+1] = H.LabelText{Name="GradeLabel", Px=9, Tint=H.Dim}

local gradeIcon = Def.ActorFrame{Name="GradeIcon"}
gradeIcon[#gradeIcon+1] = Def.Sprite{
	Name="GradeLetter",
	InitCommand=function(self) self:align(0,0.5):visible(false):diffuse(accent) end,
}
for i=1, maxGradeStars do
	gradeIcon[#gradeIcon+1] = Def.Sprite{
		Name="GradeStar"..i,
		Texture=gradeAssetPath("star.png"),
		InitCommand=function(self) self:align(0,0.5):visible(false):diffuse(accent) end,
	}
end
body[#body+1] = gradeIcon

body[#body+1] = H.Rule{Name="CountersTopRule"}
body[#body+1] = H.Rule{Name="CountersBottomRule"}
for i=1, #counters do
	body[#body+1] = H.LabelText{Name="CounterLabel"..i, Px=9, Tint=H.Dim, Align=center}
	body[#body+1] = H.DisplayText{Name="CounterValue"..i, Px=21, Tint=H.Ink, Align=center}
end

body[#body+1] = H.LabelText{Name="GraphLabel", Px=9, Tint=H.Dim}
body[#body+1] = H.LabelText{Name="GraphPeak", Px=9, Tint=accent, Align=right}
body[#body+1] = H.Rule{Name="PlotBorder"}
body[#body+1] = H.Rule{Name="Plot", Tint=H.Panel2}
for i=1, 15 do
	body[#body+1] = H.Rule{Name="PlotGrid"..i}
end
body[#body+1] = Def.ActorMultiVertex{
	Name="Density",
	InitCommand=function(self) self:SetDrawState({Mode="DrawMode_QuadStrip"}) end,
}
af[#af+1] = body

-- --------------------------------------------------------------------- radar

local radarColumn = Def.ActorFrame{
	Name="RadarColumn",
	LayOutCommand=function(self, p)
		local columnX = cardX + contentW + 1
		self:GetChild("Caption"):xy(columnX + 18, p.BodyTop + 16)
		-- The hexagon is centred in whatever the caption leaves.  The cap is what
		-- keeps the widest axis label inside the column: a label sits at 1.28
		-- radii, the two side axes stand at cos(30) of that, and the label
		-- itself is allowed radarLabelWidth beyond that point.
		local available = p.BodyHeight - 34
		local radius = math.min(radarMaxRadius, available/2 - 16)
		self.radarRadius = radius
		self:GetChild("Radar"):xy(columnX + radarW/2, p.BodyTop + 30 + available/2)
	end,
	FillCommand=function(self, p)
		H.SetLabel(self:GetChild("Caption"), "NOTES RADAR", 9)
		local data = p.Data
		local axes = data.radar
		local hasRadar = data.techAvailable and type(axes) == "table" and #axes == radarAxisCount
		local radar = self:GetChild("Radar")
		radar:visible(hasRadar)
		if not hasRadar then return end

		local radius = self.radarRadius
		setVertices(radar:GetChild("Outer"), bandVertices(uniformRadii(radius), 1, {1,1,1,0.16}))
		setVertices(radar:GetChild("Inner"), bandVertices(uniformRadii(radius*0.5), 1, {1,1,1,0.10}))
		for i=1, radarAxisCount do
			radar:GetChild("Spoke"..i)
				:zoomto(radius, 1)
				:rotationz(-90 + (i-1) * (360/radarAxisCount))
		end

		local radii = {}
		for i, axis in ipairs(axes) do radii[i] = radius * axis.Scaled end
		setVertices(radar:GetChild("Fill"), fanVertices(radii, {accent[1], accent[2], accent[3], 0.50}))
		setVertices(radar:GetChild("Outline"), bandVertices(radii, 1.5, {accent[1], accent[2], accent[3], 1}))

		for i, axis in ipairs(axes) do
			local label = radar:GetChild("Label"..i)
			local x, y = radarPoint(radius*radarLabelDistance, i)
			local cosine = math.cos(radarAngles[i])
			H.SetLabel(label, axisNames[axis.Label] or axis.Label, 9, radarLabelWidth)
			label:xy(x, y):diffuse(axis.Value >= 0.5 and accent or H.Dim)
			if math.abs(cosine) < 0.01 then
				label:horizalign(center)
			else
				label:horizalign(cosine > 0 and left or right)
			end
		end
	end,
}
radarColumn[#radarColumn+1] = H.LabelText{Name="Caption", Px=9, Tint=H.Dim}

local radar = Def.ActorFrame{Name="Radar"}
local function radarShape(name)
	return Def.ActorMultiVertex{
		Name=name,
		InitCommand=function(self) self:SetDrawState({Mode="DrawMode_QuadStrip"}) end,
	}
end
radarColumn[#radarColumn+1] = radar
radar[#radar+1] = radarShape("Outer")
radar[#radar+1] = radarShape("Inner")
for i=1, radarAxisCount do
	radar[#radar+1] = Def.Quad{
		Name="Spoke"..i,
		-- Anchored at the centre and rotated outwards, so one quad per axis is
		-- all the spokes cost.
		InitCommand=function(self) self:align(0,0.5):diffuse(H.Line) end,
	}
end
radar[#radar+1] = radarShape("Fill")
radar[#radar+1] = radarShape("Outline")
for i=1, radarAxisCount do
	radar[#radar+1] = H.LabelText{Name="Label"..i, Px=9, Tint=H.Dim}
end
af[#af+1] = radarColumn

-- ------------------------------------------------------------------ preview

af[#af+1] = LoadActor(
	THEME:GetPathB("ScreenSelectMusic", "overlay/VOLT26/ChartStrip.lua"),
	{H=H, Player=player, X=previewX, Width=previewW}
)

H.AddSettledRefresh(af, 0.30, 18, 0)
return af
