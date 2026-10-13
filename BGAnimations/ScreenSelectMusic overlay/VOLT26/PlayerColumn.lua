local args = ...
local H = args.H
local player = args.Player
local pn = ToEnumShortString(player)
local accent = H.Accent(player)

-- One vertical column per player, standing beside the wheel on that player's
-- own side and holding everything about that player: the readings, the density
-- graph, the notes radar and the difficulty list against the wheel.  Nothing
-- here is shared information -- the song, its BPM, its length and its pack all
-- live in the band above -- and nothing crosses to the other player's side.
--
-- The right column is the left one's mirror image, so `mirror` reverses every
-- horizontal decision below: what sits against the screen edge on one side sits
-- against the screen edge on the other, and the difficulty list stays against
-- the wheel for both.

local mirror = H.IsMirrored(player)
local columnX = H.ColumnX(player)
local columnW = H.ColumnW
local outerEdge = mirror and (columnX + columnW) or columnX
local innerEdge = mirror and columnX or (columnX + columnW)
-- Inward is to the right on the left column and to the left on the right one.
local inward = mirror and -1 or 1
local outerAlign = mirror and right or left
local innerAlign = mirror and left or right

local padX = 18
local shapesGap = 22
local difficultyW = 240
local radarW = columnW - difficultyW - shapesGap
local slotGap = 6
local slotMaxHeight = 54
local countersPadY = 8

-- A point `distance` in from the screen edge of the column, and one `distance`
-- in from the wheel.
local function fromOuter(distance) return outerEdge + inward*distance end
local function fromInner(distance) return innerEdge - inward*distance end

-- The left edge of a block `distance` in from the screen edge of the column,
-- for actors that are placed by their corner rather than by their text anchor.
local function blockX(distance, width)
	return mirror and (outerEdge - distance - width) or (outerEdge + distance)
end

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
local gradeIconSize = 18
local transparent = color("0,0,0,0")

-- The notes radar is the owner's star artwork, kept exactly as drawn.  The
-- dark star and its glow (backdrop.png) stand for "full on every axis"; the
-- chart's own reading is an orange star raised inside it, aimed at the dark
-- star's own points and valleys, so a chart full on every axis fills it
-- exactly.  Every point is split into a lit half and a shaded half with a
-- dotted seam down its ridge, like a folded paper star.  The axis names and
-- icons are the artwork's own (labels.png).  All three come from
-- tools/notes-radar/build_radar_art.py.
local radarArt = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/VOLT26/RadarArt.lua"))
local radarStar = {
	Lit   = color("#F3A608"),
	Shade = color("#D38F00"),
	Seam  = color("#823500"),
	Label = color("#FFF700"),
	-- The seams' dot pitch and dot size, in radar radii, measured from the
	-- artwork's orange star.
	SeamPitch = 0.124,
	SeamDot = 0.008,
	-- Plain-text fallback labels, when labels.png is missing, stand this many
	-- radii out along their axis.
	FallbackDistance = 1.14,
	FallbackWidth = 70,
}

local radarAssetDir = "Graphics/VOLT26/SongSelection/NotesRadar/"
-- GetCurrentThemeDirectory() is relative ("Themes/VOLT26/"); a Sprite would
-- resolve a relative Texture against this file's own folder, so anchor it.
local function radarAsset(file)
	local path = "/" .. THEME:GetCurrentThemeDirectory() .. radarAssetDir .. file
	path = path:gsub("^//", "/")
	return FILEMAN:DoesFileExist(path) and path or nil
end
local radarBackdropPath = radarAsset("backdrop.png")
local radarLabelsPath = radarAsset("labels.png")

-- The largest radar, backdrop and labels included, that fits a block of the
-- given size.  The artwork's labels overlap the points; the plain-text
-- fallback stands outside them, so without the artwork the sides keep room.
local radarReach = radarArt.Reach
local function radarRadiusFor(width, height, plainLabels)
	local sideRoom = plainLabels and radarStar.FallbackWidth or 0
	return math.floor(math.min(
		(width/2 - 6 - sideRoom) / math.max(radarReach.Left, radarReach.Right),
		height / (radarReach.Up + radarReach.Down)))
end

local radarAxisCount = VOLT26.ChartRadar.GetAxisCount()
local radarTips, radarValleys = radarArt.Tips, radarArt.Valleys

local function gradeAssetPath(file)
	return THEME:GetPathG("", "_grades/assets/"..file)
end

-- Every point of the star is two triangles meeting on the ridge from the
-- centre to the tip: the one on its anticlockwise side is shaded, the one on
-- its clockwise side lit, which is how the artwork folds its points.  `tips`
-- and `valleys` are the readings from VOLT26.ChartRadar.StarRadii (with an
-- inner ratio of 1, so a valley is the mean of its two points); each scales
-- the artwork's own point or valley, and `radius` turns radar radii into
-- pixels.
local function starVertices(tips, valleys, radius, lit, shade)
	local vertices = {}
	for i=1, radarAxisCount do
		local before = i == 1 and radarAxisCount or i-1
		local t, b, a = radarTips[i], radarValleys[before], radarValleys[i]
		local ts, bs, as = tips[i]*radius, valleys[before]*radius, valleys[i]*radius
		local tx, ty = t[1]*ts, t[2]*ts
		local bx, by = b[1]*bs, b[2]*bs
		local ax, ay = a[1]*as, a[2]*as
		vertices[#vertices+1] = {{0,0,0}, shade}
		vertices[#vertices+1] = {{bx,by,0}, shade}
		vertices[#vertices+1] = {{tx,ty,0}, shade}
		vertices[#vertices+1] = {{0,0,0}, lit}
		vertices[#vertices+1] = {{tx,ty,0}, lit}
		vertices[#vertices+1] = {{ax,ay,0}, lit}
	end
	return vertices
end

-- The dotted seams: small squares at an even pitch along the ridge from the
-- centre to every point, as in the artwork.
local function seamVertices(tips, radius, rgba)
	local vertices = {}
	local pitch = math.max(5, radius*radarStar.SeamPitch)
	local half = math.max(0.75, radius*radarStar.SeamDot/2)
	for i=1, radarAxisCount do
		local t = radarTips[i]
		local length = math.sqrt(t[1]*t[1] + t[2]*t[2]) * tips[i] * radius
		local dx, dy = t[1]/math.sqrt(t[1]*t[1] + t[2]*t[2]), t[2]/math.sqrt(t[1]*t[1] + t[2]*t[2])
		local d = pitch
		while d < length - pitch*0.5 do
			local x, y = dx*d, dy*d
			vertices[#vertices+1] = {{x-half,y-half,0}, rgba}
			vertices[#vertices+1] = {{x+half,y-half,0}, rgba}
			vertices[#vertices+1] = {{x+half,y+half,0}, rgba}
			vertices[#vertices+1] = {{x-half,y+half,0}, rgba}
			d = d + pitch
		end
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
			:x(inward*(i-1)*gradeIconSize)
			:diffuse(i <= stars and accent or H.Line)
	end
end

local af = Def.ActorFrame{
	Name=pn.."Column",
	RefreshCommand=function(self)
		local joined = GAMESTATE:IsHumanPlayer(player) and H.Item() ~= nil
		self:visible(joined)
		if not joined then return end

		local top, height = H.Band()
		local metrics = H.ColumnMetrics()
		local chart = H.Chart(player)
		local data = H.ChartData(player)

		self:playcommand("LayOut", {Top=top, Height=height, Metrics=metrics})
		self:playcommand("Fill", {Chart=chart, Data=data, Metrics=metrics})
	end,
}

-- ------------------------------------------------------------------- ground

-- One container for the whole column: the readings, the graph, the radar and
-- the difficulty list all live inside it, separated by rules rather than by
-- boxes of their own.  It stands on the shared scrim, so the screen's backdrop
-- reads through it the way it does behind the songwheel.  That rules out the
-- usual box -- a filled line-coloured quad behind a filled panel-coloured one
-- -- because the quad behind would show straight through the scrim and seal it
-- again; the edge is drawn as three rules instead, with the accent line
-- closing the top.
local ground = Def.ActorFrame{
	Name="Ground",
	LayOutCommand=function(self, p)
		self:GetChild("Background"):xy(columnX, p.Top):zoomto(columnW, p.Height)
		self:GetChild("EdgeL"):xy(columnX-1, p.Top-1):zoomto(1, p.Height+2)
		self:GetChild("EdgeR"):xy(columnX+columnW, p.Top-1):zoomto(1, p.Height+2)
		self:GetChild("EdgeB"):xy(columnX-1, p.Top+p.Height):zoomto(columnW+2, 1)
		self:GetChild("Accent"):xy(columnX, p.Top):zoomto(columnW, 2)
		self:GetChild("HeaderRule")
			:xy(columnX, p.Metrics.HeaderTop + p.Metrics.HeaderHeight):zoomto(columnW, 1)
	end,
}
ground[#ground+1] = H.Rule{Name="Background", Tint=H.Panel, Alpha=H.ScrimAlpha}
ground[#ground+1] = H.Rule{Name="EdgeL"}
ground[#ground+1] = H.Rule{Name="EdgeR"}
ground[#ground+1] = H.Rule{Name="EdgeB"}
ground[#ground+1] = H.Rule{Name="Accent", Tint=accent}
ground[#ground+1] = H.Rule{Name="HeaderRule"}
af[#af+1] = ground

-- ------------------------------------------------------------------- header

-- The player on the screen's own side of the column, and what they have chosen
-- laid out from the wheel outwards, so a long step artist credit gives ground
-- instead of pushing the rate off the column.
local header = Def.ActorFrame{
	Name="Header",
	LayOutCommand=function(self, p)
		local middle = p.Metrics.HeaderTop + p.Metrics.HeaderHeight/2
		self:GetChild("Badge"):y(middle)
		self:GetChild("BadgeLabel"):y(middle)
		self:GetChild("Name"):y(middle)
		self:GetChild("ChartLine"):y(middle)
		self:GetChild("Rate"):y(middle)
		self:GetChild("Author"):y(middle)
	end,
	FillCommand=function(self, p)
		local badgeLabel = self:GetChild("BadgeLabel")
		H.SetLabel(badgeLabel, pn, 11)
		local badgeWidth = badgeLabel:GetZoomedWidth() + 16
		self:GetChild("Badge"):x(blockX(padX, badgeWidth)):zoomto(badgeWidth, 18)
		badgeLabel:x(blockX(padX, badgeWidth) + badgeWidth/2)
		H.SetDisplay(self:GetChild("Name"), H.PlayerName(player), 27, 230)
		self:GetChild("Name"):x(fromOuter(padX + badgeWidth + 12))

		local chart = p.Chart
		local difficulty = chart and ToEnumShortString(chart:GetDifficulty()):upper() or ""
		local meter = chart and tostring(chart:GetMeter()) or H.Dash
		local author = chart and chart.GetAuthorCredit and chart:GetAuthorCredit() or ""

		local edge = padX
		local authorText = self:GetChild("Author")
		H.SetLabel(authorText, author ~= "" and ("STEPS BY "..author) or "", 11, 170)
		authorText:x(fromInner(edge))
		edge = edge + (author ~= "" and authorText:GetZoomedWidth() + 20 or 0)

		local rate = self:GetChild("Rate")
		H.SetLabel(rate, string.format("RATE %.2fx", VOLT26.MusicSelection.GetMusicRate()), 11)
		rate:x(fromInner(edge))
		edge = edge + rate:GetZoomedWidth() + 20

		local chartLine = self:GetChild("ChartLine")
		H.SetLabel(chartLine, difficulty ~= "" and (difficulty.." "..meter) or "", 11, 170)
		chartLine:x(fromInner(edge))
	end,
}
header[#header+1] = Def.Quad{Name="Badge", InitCommand=function(self) self:align(0,0.5):diffuse(accent) end}
header[#header+1] = H.LabelText{Name="BadgeLabel", Px=11, Tint=H.Ink, Align=center}
header[#header+1] = H.DisplayText{Name="Name", Px=27, Tint=H.Ink, Align=outerAlign}
header[#header+1] = H.LabelText{Name="ChartLine", Px=11, Tint=H.Mute, Align=innerAlign}
header[#header+1] = H.LabelText{Name="Rate", Px=11, Tint=H.Mute, Align=innerAlign}
header[#header+1] = H.LabelText{Name="Author", Px=11, Tint=H.Dim, Align=innerAlign}
af[#af+1] = header

-- -------------------------------------------------------------------- score

-- Three cells of the same width, read from the screen edge inwards: what the
-- player has scored here, what they scored in EX, and the grade that came with
-- it.  Equal cells rather than measured ones, so the two columns line up with
-- each other across the wheel.
local scoreCellCount = 3

local score = Def.ActorFrame{
	Name="Score",
	LayOutCommand=function(self, p)
		local m = p.Metrics
		local cellW = columnW/scoreCellCount
		local baseline = m.ScoreTop + m.ScoreHeight - 8
		self.cellW = cellW
		self.baseline = baseline
		for i=1, scoreCellCount-1 do
			self:GetChild("CellRule"..i)
				:xy(columnX + i*cellW, m.ScoreTop + 8):zoomto(1, m.ScoreHeight - 16)
		end
	end,
	FillCommand=function(self, p)
		local best = VOLT26.ScoreIndex.GetBest(player, H.Item(), p.Chart)
		local cellW = self.cellW
		local baseline = self.baseline

		local function cellAnchor(index)
			return fromOuter((index-1)*cellW + padX)
		end

		local function scoreCell(index, labelName, valueName, suffixName, labelText, valueText, tint)
			local x = cellAnchor(index)
			local label = self:GetChild(labelName)
			H.SetLabel(label, labelText, 9)
			label:xy(x, baseline - 52)
			local value = self:GetChild(valueName)
			H.SetDisplay(value, valueText, 40)
			value:xy(x, baseline):diffuse(tint)
			local suffix = self:GetChild(suffixName)
			H.SetDisplay(suffix, "%", 18)
			suffix:xy(x + inward*(value:GetZoomedWidth() + 3), baseline)
		end

		scoreCell(1, "BestLabel", "BestValue", "BestSuffix", "BEST - ITG",
			formatPercent(best and best.PercentDP and best.PercentDP*100 or nil), H.Ink)
		scoreCell(2, "ExLabel", "ExValue", "ExSuffix", "EX",
			formatPercent(best and best.ExPercent or nil),
			best and best.ExPercent and H.Ink or H.Mute)

		local x = cellAnchor(3)
		local gradeLabel = self:GetChild("GradeLabel")
		H.SetLabel(gradeLabel, "GRADE", 9)
		gradeLabel:xy(x, baseline - 52)
		local gradeIcon = self:GetChild("GradeIcon")
		gradeIcon:xy(x, baseline - gradeIconSize/2 - 6)
		setGradeIcon(gradeIcon, best and best.Grade or nil)
	end,
}
for i=1, scoreCellCount-1 do
	score[#score+1] = H.Rule{Name="CellRule"..i}
end
score[#score+1] = H.LabelText{Name="BestLabel", Px=9, Tint=H.Dim, Align=outerAlign}
score[#score+1] = H.DisplayText{Name="BestValue", Px=40, Tint=H.Ink, Align=outerAlign, VAlign=bottom}
score[#score+1] = H.DisplayText{Name="BestSuffix", Px=18, Tint=H.Mute, Align=outerAlign, VAlign=bottom}
score[#score+1] = H.LabelText{Name="ExLabel", Px=9, Tint=H.Dim, Align=outerAlign}
score[#score+1] = H.DisplayText{Name="ExValue", Px=40, Tint=H.Mute, Align=outerAlign, VAlign=bottom}
score[#score+1] = H.DisplayText{Name="ExSuffix", Px=18, Tint=H.Mute, Align=outerAlign, VAlign=bottom}
score[#score+1] = H.LabelText{Name="GradeLabel", Px=9, Tint=H.Dim, Align=outerAlign}

local gradeIcon = Def.ActorFrame{Name="GradeIcon"}
gradeIcon[#gradeIcon+1] = Def.Sprite{
	Name="GradeLetter",
	InitCommand=function(self) self:align(mirror and 1 or 0, 0.5):visible(false):diffuse(accent) end,
}
for i=1, maxGradeStars do
	gradeIcon[#gradeIcon+1] = Def.Sprite{
		Name="GradeStar"..i,
		Texture=gradeAssetPath("star.png"),
		InitCommand=function(self) self:align(mirror and 1 or 0, 0.5):visible(false):diffuse(accent) end,
	}
end
score[#score+1] = gradeIcon
af[#af+1] = score

-- ----------------------------------------------------------------- counters

local counterCells = Def.ActorFrame{
	Name="Counters",
	LayOutCommand=function(self, p)
		local m = p.Metrics
		local innerW = columnW - padX*2
		local x = columnX + padX
		self:GetChild("TopRule"):xy(x, m.CountersTop):zoomto(innerW, 1)
		self:GetChild("BottomRule"):xy(x, m.CountersTop + m.CountersHeight):zoomto(innerW, 1)

		local cellWidth = innerW/#counters
		for i=1, #counters do
			local cellX = x + (i-0.5)*cellWidth
			self:GetChild("CounterLabel"..i):xy(cellX, m.CountersTop + countersPadY + 8)
			self:GetChild("CounterValue"..i):xy(cellX, m.CountersTop + countersPadY + 34)
		end
	end,
	FillCommand=function(self, p)
		for i, counter in ipairs(counters) do
			local value = p.Data[counter[2]] or 0
			H.SetLabel(self:GetChild("CounterLabel"..i), counter[1], 9)
			H.SetDisplay(self:GetChild("CounterValue"..i), value, 26)
			-- A count of zero is a fact about the chart, not a number to read,
			-- so it steps back to the label colour.
			self:GetChild("CounterValue"..i):diffuse(value > 0 and H.Ink or H.Dim)
		end
	end,
}
counterCells[#counterCells+1] = H.Rule{Name="TopRule"}
counterCells[#counterCells+1] = H.Rule{Name="BottomRule"}
for i=1, #counters do
	counterCells[#counterCells+1] = H.LabelText{Name="CounterLabel"..i, Px=9, Tint=H.Dim, Align=center}
	counterCells[#counterCells+1] = H.DisplayText{Name="CounterValue"..i, Px=26, Tint=H.Ink, Align=center}
end
af[#af+1] = counterCells

-- -------------------------------------------------------------------- graph

local graph = Def.ActorFrame{
	Name="Graph",
	LayOutCommand=function(self, p)
		local m = p.Metrics
		local innerW = columnW - padX*2
		local plotTop = m.GraphTop + 18
		local plotHeight = m.GraphHeight - 18
		self.plotWidth = innerW
		self.plotHeight = plotHeight

		self:GetChild("GraphLabel"):xy(fromOuter(padX), m.GraphTop + 4)
		self:GetChild("GraphPeak"):xy(fromInner(padX), m.GraphTop + 4)
		self:GetChild("PlotBorder"):xy(columnX + padX - 1, plotTop - 1):zoomto(innerW + 2, plotHeight + 2)
		self:GetChild("Plot"):xy(columnX + padX, plotTop):zoomto(innerW, plotHeight)
		for i=1, 15 do
			self:GetChild("PlotGrid"..i)
				:xy(columnX + padX + i*innerW/16, plotTop):zoomto(0.6, plotHeight)
		end
		self:GetChild("Density"):xy(columnX + padX, plotTop + plotHeight)
	end,
	FillCommand=function(self, p)
		local data = p.Data
		H.SetLabel(self:GetChild("GraphLabel"), "DENSITY / MEASURE", 9)
		local peak = data.peak*VOLT26.MusicSelection.GetMusicRate()
		H.SetLabel(self:GetChild("GraphPeak"),
			data.peak > 0 and string.format("PEAK %.1f NPS", peak) or "NO DENSITY DATA", 9)
		self:GetChild("GraphPeak"):diffuse(data.peak > 0 and accent or H.Dim)
		setVertices(self:GetChild("Density"), densityVertices(data, self.plotWidth, self.plotHeight))
	end,
}
graph[#graph+1] = H.LabelText{Name="GraphLabel", Px=9, Tint=H.Dim, Align=outerAlign}
graph[#graph+1] = H.LabelText{Name="GraphPeak", Px=9, Tint=accent, Align=innerAlign}
graph[#graph+1] = H.Rule{Name="PlotBorder"}
graph[#graph+1] = H.Rule{Name="Plot", Tint=H.Panel2}
for i=1, 15 do
	graph[#graph+1] = H.Rule{Name="PlotGrid"..i}
end
graph[#graph+1] = Def.ActorMultiVertex{
	Name="Density",
	InitCommand=function(self) self:SetDrawState({Mode="DrawMode_QuadStrip"}) end,
}
af[#af+1] = graph

-- -------------------------------------------------------------------- radar

-- The star takes the screen edge of the column and the difficulty list stands
-- beside it against the wheel, where the left and right the player presses to
-- change it are pointing.
local radarColumn = Def.ActorFrame{
	Name="RadarColumn",
	LayOutCommand=function(self, p)
		local m = p.Metrics
		local areaTop = m.ShapesTop + 20
		local available = m.ShapesHeight - 20
		local radius = radarRadiusFor(radarW, available, radarLabelsPath == nil)
		local reach = radarReach.Up + radarReach.Down
		self.radarRadius = radius
		self:GetChild("Caption"):xy(fromOuter(padX), m.ShapesTop + 6)
		self:GetChild("Radar"):xy(blockX(0, radarW) + radarW/2,
			areaTop + (available - radius*reach)/2 + radius*radarReach.Up)
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
		local backdrop = radar:GetChild("Backdrop")
		if backdrop then backdrop:zoom(radius/radarArt.ArtRadius) end

		local tips, valleys = VOLT26.ChartRadar.StarRadii(axes, 1)
		local reading = radar:GetChild("Reading")
		setVertices(reading:GetChild("Faces"),
			starVertices(tips, valleys, radius, radarStar.Lit, radarStar.Shade))
		setVertices(reading:GetChild("Seams"), seamVertices(tips, radius, radarStar.Seam))
		-- A new chart's star grows out of the centre rather than snapping.
		if self.lastChart ~= p.Chart then
			self.lastChart = p.Chart
			reading:stoptweening():zoom(0.82):decelerate(0.16):zoom(1)
		end

		local art = radar:GetChild("Labels")
		if art then
			art:zoom(radius/radarArt.ArtRadius)
			return
		end
		for i, axis in ipairs(axes) do
			local label = radar:GetChild("Label"..i)
			local t = radarTips[i]
			local x, y = t[1]*radius*radarStar.FallbackDistance, t[2]*radius*radarStar.FallbackDistance
			local length = math.sqrt(t[1]*t[1] + t[2]*t[2])
			local cosine = t[1]/length
			H.SetLabel(label, axis.Label, 9, radarStar.FallbackWidth)
			label:xy(x, y):diffuse(axis.Value >= 0.5 and radarStar.Label or H.Dim)
			if math.abs(cosine) < 0.3 then
				label:horizalign(center)
			else
				label:horizalign(cosine > 0 and left or right)
			end
		end
	end,
}
radarColumn[#radarColumn+1] = H.LabelText{Name="Caption", Px=9, Tint=H.Dim, Align=outerAlign}

local function radarShape(name, mode)
	return Def.ActorMultiVertex{
		Name=name,
		InitCommand=function(self) self:SetDrawState({Mode=mode}) end,
	}
end

local radar = Def.ActorFrame{Name="Radar"}
radarColumn[#radarColumn+1] = radar
if radarBackdropPath then
	-- The owner's dark star and its glow, centred on the star.
	radar[#radar+1] = Def.Sprite{Name="Backdrop", Texture=radarBackdropPath}
end
radar[#radar+1] = Def.ActorFrame{
	Name="Reading",
	radarShape("Faces", "DrawMode_Triangles"),
	radarShape("Seams", "DrawMode_Quads"),
}
if radarLabelsPath then
	-- The artwork already places every name and icon around its own star, so
	-- one sprite centred on the star and scaled to its radius is the layout.
	radar[#radar+1] = Def.Sprite{Name="Labels", Texture=radarLabelsPath}
else
	for i=1, radarAxisCount do
		radar[#radar+1] = H.LabelText{Name="Label"..i, Px=9, Tint=H.Dim}
	end
end
af[#af+1] = radarColumn

-- --------------------------------------------------------------- difficulty

local difficultyColumn = Def.ActorFrame{
	Name="Difficulty",
	LayOutCommand=function(self, p)
		local m = p.Metrics
		local listTop = m.ShapesTop + 20
		local listHeight = m.ShapesHeight - 20
		local slotH = math.min(slotMaxHeight,
			(listHeight - slotGap*(#difficulties-1))/#difficulties)
		local blockLeft = blockX(radarW + shapesGap, difficultyW)
		-- The whole list is centred on the star beside it rather than
		-- hanging from the caption, so the two shapes read as one band.
		local top = listTop + (listHeight - (slotH*#difficulties + slotGap*(#difficulties-1)))/2

		self:GetChild("Caption"):xy(mirror and (blockLeft + difficultyW) or blockLeft, m.ShapesTop + 6)
		for i=1, #difficulties do
			local slotTop = top + (i-1)*(slotH + slotGap)
			self:GetChild("Slot"..i):xy(blockLeft, slotTop):zoomto(difficultyW, slotH)
			-- The bar marks the side the wheel is on, so the selected slot
			-- points at the left and right that change it.
			self:GetChild("Bar"..i)
				:xy(mirror and blockLeft or (blockLeft + difficultyW - 3), slotTop)
				:zoomto(3, slotH)
			self:GetChild("Name"..i)
				:xy(mirror and (blockLeft + difficultyW - 15) or (blockLeft + 15), slotTop + slotH/2)
			self:GetChild("Meter"..i)
				:xy(mirror and (blockLeft + 12) or (blockLeft + difficultyW - 12), slotTop + slotH/2)
		end
	end,
	FillCommand=function(self, p)
		H.SetLabel(self:GetChild("Caption"), H.String("Difficulty"), 9)
		for i, entry in ipairs(difficulties) do
			local steps = stepsForDifficulty(entry[1])
			local selected = steps ~= nil and steps == p.Chart
			-- The slots carry no box of their own.  The one in play wears the
			-- songwheel's highlight and nothing else does, so the list reads
			-- as a list with a selection rather than five competing panels.
			self:GetChild("Slot"..i):visible(selected)
			self:GetChild("Bar"..i):visible(selected)
			local tint = selected and H.Ink or (steps and H.Mute or H.Dim)
			H.SetLabel(self:GetChild("Name"..i), entry[2], 12, difficultyW-74)
			self:GetChild("Name"..i):diffuse(tint)
			H.SetDisplay(self:GetChild("Meter"..i), steps and steps:GetMeter() or "", 30)
			self:GetChild("Meter"..i):diffuse(selected and accent or tint)
		end
	end,
}
difficultyColumn[#difficultyColumn+1] =
	H.LabelText{Name="Caption", Px=9, Tint=H.Dim, Align=outerAlign}
for i=1, #difficulties do
	difficultyColumn[#difficultyColumn+1] = Def.Quad{
		Name="Slot"..i,
		InitCommand=function(self)
			-- The wash falls away from the bar, which stands on the wheel's
			-- side of the slot.
			self:align(0,0):diffuse(accent):diffusealpha(0.22):visible(false)
			if mirror then
				self:diffuserightedge(transparent)
			else
				self:diffuseleftedge(transparent)
			end
		end,
	}
	difficultyColumn[#difficultyColumn+1] = Def.Quad{
		Name="Bar"..i,
		InitCommand=function(self) self:align(0,0):diffuse(accent):visible(false) end,
	}
	difficultyColumn[#difficultyColumn+1] =
		H.LabelText{Name="Name"..i, Px=12, Tint=H.Mute, Align=mirror and right or left}
	difficultyColumn[#difficultyColumn+1] =
		H.DisplayText{Name="Meter"..i, Px=30, Tint=H.Mute, Align=mirror and left or right}
end
af[#af+1] = difficultyColumn

H.AddSettledRefresh(af, 0.30, mirror and -18 or 18, 0)
return af
