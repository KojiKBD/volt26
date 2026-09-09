local args = ...
local H = args.H
local player = args.Player
local pn = ToEnumShortString(player)
local accent = H.Accent(player)
-- The right column runs from the preview panel's edge (612) to the screen
-- margin, so the card claims the 28 unused units on its left and keeps equal
-- 12 unit gutters on both sides.  Everything inside is padded 8 from the box.
local cardW = 218

-- Grade artwork.  Tiers 00-04 are drawn as a row of stars rather than reusing
-- the evaluation grade actors: Song Select only needs a static badge, and the
-- evaluation versions spin, pulse, and pull in their easter-egg layers.
local gradeStars = {
	Grade_Tier00 = 5,
	Grade_Tier01 = 4,
	Grade_Tier02 = 3,
	Grade_Tier03 = 2,
	Grade_Tier04 = 1,
}
local gradeLetters = {
	Grade_Tier05 = "s-plus.png",
	Grade_Tier06 = "s.png",
	Grade_Tier07 = "s-minus.png",
	Grade_Tier08 = "a-plus.png",
	Grade_Tier09 = "a.png",
	Grade_Tier10 = "a-minus.png",
	Grade_Tier11 = "b-plus.png",
	Grade_Tier12 = "b.png",
	Grade_Tier13 = "b-minus.png",
	Grade_Tier14 = "c-plus.png",
	Grade_Tier15 = "c.png",
	Grade_Tier16 = "c-minus.png",
	Grade_Tier17 = "d.png",
	Grade_Tier99 = "q.png",
	Grade_Failed = "f.png",
}
local maxGradeStars = 5
local gradeAssetSize = 200
-- EX is a different scoring system from the ITG percentage beside it, so it
-- gets its own colour rather than the muted grey the secondary rows use.
local exColor = color("#57b8ff")

local function gradeAssetPath(file)
	return THEME:GetPathG("", "_grades/assets/"..file)
end

local function formatPercent(value)
	if type(value) ~= "number" then return H.Dash end
	return string.format("%.2f%%", value)
end

local function setGradeIcon(frame, grade, size)
	local letter = frame:GetChild("GradeLetter")
	local file = grade and gradeLetters[grade] or nil
	local stars = grade and gradeStars[grade] or 0

	if file then
		local path = gradeAssetPath(file)
		if frame.loadedPath ~= path then
			local ok = pcall(function() letter:Load(path) end)
			frame.loadedPath = ok and path or nil
		end
		letter:visible(frame.loadedPath ~= nil):zoom(size/gradeAssetSize)
	else
		letter:visible(false)
	end

	local starSize = size * 0.62
	for i=1,maxGradeStars do
		frame:GetChild("GradeStar"..i)
			:visible(i <= stars)
			:zoom(starSize/gradeAssetSize)
			:x(-(i-1)*starSize)
	end

	frame:visible(file ~= nil or stars > 0)
end

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

local function graphVertices(data, graphColor, graphW, graphH)
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

-- Notes radar.
--
-- A pointy-top hexagon: axis 1 sits at the top vertex and the rest run
-- clockwise, in the order VOLT26.ChartRadar publishes them.  Coordinates are
-- relative to the radar ActorFrame's own origin, which is its centre.
local radarAxisCount = VOLT26.ChartRadar.GetAxisCount()
-- Grid rings, as a fraction of the full radius.  Two is enough to read a value
-- off the shape without turning the card into graph paper.
local radarGridLevels = {0.5, 1.0}
-- Calibration aid.  Flip to true and each axis prints its honest reading next
-- to its label -- the share of the chart's notes that pattern accounts for, and
-- the share of measures that are stream -- so the caps in VOLT26.ChartRadar can
-- be retuned against real charts instead of by eye.  Single-player only; the
-- two-player card has no room for the numbers.
local showRadarValues = false
local radarAngles = {}
for i=1, radarAxisCount do
	radarAngles[i] = math.rad(-90 + (i-1) * (360/radarAxisCount))
end

local function radarPoint(radius, index)
	local angle = radarAngles[index]
	return math.cos(angle)*radius, math.sin(angle)*radius
end

local function radarUniformRadii(radius)
	local radii = {}
	for i=1, radarAxisCount do radii[i] = radius end
	return radii
end

-- Every radar shape is a quad strip, the one draw mode this card already
-- depends on for the density graph: a filled area is a fan of degenerate quads
-- anchored on the centre, and a ring or outline is a band between two radii.
local function radarFanVertices(radii, rgba)
	local vertices = {}
	for i=1, radarAxisCount+1 do
		local index = i <= radarAxisCount and i or 1
		local x, y = radarPoint(radii[index] or 0, index)
		vertices[#vertices+1] = {{0,0,0}, rgba}
		vertices[#vertices+1] = {{x,y,0}, rgba}
	end
	return vertices
end

local function radarBandVertices(radii, width, rgba)
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

-- The note counts, as the single-player card's left-hand column.  TAP + HOLD
-- OBJECTS is gone: it printed the same number as NOTES.
local statRows = {
	{"NOTES", "notes"},
	{"JUMPS", "jumps"},
	{"HOLDS", "holds"},
	{"MINES", "mines"},
	{"ROLLS", "rolls"},
	{"HANDS", "hands"},
}

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
		-- The best-score row sits between STEP ARTIST and the density graph, so
		-- the graph starts lower than it used to and gives the row its height
		-- back.  Two-player cards only have 152 units to spend, which is why
		-- their graph keeps just enough height to stay readable.
		local bestY = single and 62 or 57
		local gradeSize = single and 18 or 15
		-- Below the density graph the single-player card is one row: the note
		-- counts as a narrow column on the left, the radar filling the space to
		-- their right.  The two-player card has only 152 units of height and no
		-- room for a six-row column, so there the counts stay on one line above
		-- a half-width graph and the radar sits beside that instead.
		local graphTop = single and 92 or 90
		local graphW = single and (cardW - 16) or 104
		local graphH = single and 68 or 40
		local statsY = 70                 -- two-player only: the single line
		local statTop = 184               -- single-player only: the column
		local statStep = 16
		local radarCX = single and 139 or 160
		local radarCY = single and 224 or 104
		local radarR = single and 30 or 26
		local radarGap = single and 7 or 6
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

		-- Personal best for the hovered chart.  ITG percentage and grade come
		-- from the profile's own high score list; EX comes from the VOLT26
		-- score index, because the engine never stores the emulated W0 split.
		local best = VOLT26.ScoreIndex.GetBest(player, H.Item(), chart)
		local bestText = self:GetChild("Best")
		bestText:xy(8,bestY):settext("ITG  "..formatPercent(best and best.PercentDP and best.PercentDP*100 or nil))
		self:GetChild("BestEx")
			:xy(8 + bestText:GetZoomedWidth() + 12, bestY)
			:settext("EX  "..formatPercent(best and best.ExPercent or nil))
		local gradeIcon = self:GetChild("GradeIcon")
		gradeIcon:xy(210,bestY)
		setGradeIcon(gradeIcon, best and best.Grade or nil, gradeSize)

		local graph = self:GetChild("Graph")
		local vertices = graphVertices(data, difficultyColor, graphW, graphH)
		graph:xy(8,graphTop+graphH):SetNumVertices(#vertices):SetVertices(vertices)
		local peak = data.peak*VOLT26.MusicSelection.GetMusicRate()
		local graphLabel = self:GetChild("GraphLabel")
		if data.peak > 0 then
			graphLabel:settext(single
				and string.format("DENSITY / MEASURE   PEAK %.1f NPS", peak)
				or string.format("PEAK %.1f NPS", peak))
		else
			graphLabel:settext("DENSITY DATA UNAVAILABLE")
		end
		graphLabel:xy(8,graphTop-8):maxwidth(graphW/H.BoldZoom(0.039))

		for i=0,4 do
			self:GetChild("VGrid"..i):xy(8+i*graphW/4,graphTop):zoomto(1,graphH)
		end
		for i=0,2 do
			self:GetChild("HGrid"..i):xy(8,graphTop+i*graphH/2):zoomto(graphW,1)
		end

		-- The counts read as a column beside the radar on the single-player
		-- card, and fall back to one line on the two-player card.
		self:GetChild("Stats"):visible(not single):xy(8,statsY)
			:maxwidth(118/H.NormalZoom(0.044))
			:settext(string.format(
				"NOTES %d   JUMPS %d   HOLDS %d   MINES %d",
				data.notes or 0, data.jumps or 0, data.holds or 0, data.mines or 0))
		for i, row in ipairs(statRows) do
			self:GetChild("StatRow"..i)
				:visible(single)
				:xy(8, statTop + (i-1)*statStep)
				:settext(string.format("%s  %d", row[1], data[row[2]] or 0))
		end

		-- Notes radar.  It replaces the old "XO 5   FS 11" counter line: the
		-- same tech data, plus how much of the chart is stream, drawn as a shape
		-- that can be compared against another chart at a glance.
		local axes = data.radar
		local hasRadar = data.techAvailable and type(axes) == "table" and #axes == radarAxisCount

		-- The axis labels name the thing, so the radar carries no heading.  This
		-- line exists only to say when there is nothing to draw.
		self:GetChild("RadarTitle")
			:visible(single and not hasRadar)
			:xy(8, 170)
			:settext("NO TECH DATA")

		local radar = self:GetChild("Radar")
		radar:visible(hasRadar)
		if hasRadar then
			-- The calibration readout roughly doubles every label's length, so
			-- it needs its own smaller zoom to stay inside the card.
			local labelZoom = H.BoldZoom(showRadarValues and single and 0.026 or 0.032)
			radar:xy(radarCX, radarCY)

			setVertices(radar:GetChild("Base"),
				radarFanVertices(radarUniformRadii(radarR), {0,0,0,0.55}))
			for i, level in ipairs(radarGridLevels) do
				setVertices(radar:GetChild("Ring"..i),
					radarBandVertices(radarUniformRadii(radarR*level), 1, {1,1,1,0.16}))
			end
			for i=1, radarAxisCount do
				radar:GetChild("Spoke"..i)
					:zoomto(radarR, 1)
					:rotationz(-90 + (i-1) * (360/radarAxisCount))
			end

			local radii = {}
			for i, axis in ipairs(axes) do radii[i] = radarR * axis.Scaled end
			local fill = {difficultyColor[1], difficultyColor[2], difficultyColor[3], 0.45}
			local edge = {difficultyColor[1], difficultyColor[2], difficultyColor[3], 0.95}
			setVertices(radar:GetChild("Fill"), radarFanVertices(radii, fill))
			setVertices(radar:GetChild("Outline"), radarBandVertices(radii, 1.4, edge))

			for i, axis in ipairs(axes) do
				local x, y = radarPoint(radarR + radarGap, i)
				local cosine = math.cos(radarAngles[i])
				local label = radar:GetChild("Label"..i)
				local caption = single and axis.Label or axis.Short
				if single and showRadarValues then
					caption = string.format("%s %.1f%%", axis.Label, axis.Raw*100)
				end
				label:xy(x, y):zoom(labelZoom)
					:settext(caption)
					-- An axis at half its cap or more is what makes a chart
					-- worth picking out, so it gets the difficulty colour.
					:diffuse(axis.Value >= 0.5 and difficultyColor or H.Muted)
				if math.abs(cosine) < 0.01 then
					label:horizalign(center)
				else
					label:horizalign(cosine > 0 and left or right)
				end
			end
		end
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

af[#af+1] = Def.BitmapText{
	Name="Best", Font=H.FontBold,
	InitCommand=function(self) self:horizalign(left):zoom(H.BoldZoom(0.048)):diffuse(H.Black) end,
}
af[#af+1] = Def.BitmapText{
	Name="BestEx", Font=H.FontBold,
	InitCommand=function(self) self:horizalign(left):zoom(H.BoldZoom(0.048)):diffuse(exColor) end,
}

local gradeIcon = Def.ActorFrame{
	Name="GradeIcon",
	InitCommand=function(self) self:visible(false) end,
}
gradeIcon[#gradeIcon+1] = Def.Sprite{
	Name="GradeLetter",
	InitCommand=function(self) self:align(1,0.5):visible(false) end,
}
for i=1,maxGradeStars do
	gradeIcon[#gradeIcon+1] = Def.Sprite{
		Name="GradeStar"..i,
		Texture=gradeAssetPath("star.png"),
		InitCommand=function(self) self:align(1,0.5):visible(false) end,
	}
end
af[#af+1] = gradeIcon

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
	Name="RadarTitle", Font=H.FontBold,
	InitCommand=function(self) self:horizalign(left):zoom(H.BoldZoom(0.052)):diffuse(H.Black) end,
}

-- The radar's own frame, so the whole thing can be positioned and hidden as a
-- unit.  Its origin is the hexagon's centre and every child is placed relative
-- to it, which is what lets the same actors serve both card sizes.
local radarFrame = Def.ActorFrame{ Name="Radar" }
local function radarShape(name)
	return Def.ActorMultiVertex{
		Name=name,
		InitCommand=function(self) self:SetDrawState({Mode="DrawMode_QuadStrip"}) end,
	}
end
radarFrame[#radarFrame+1] = radarShape("Base")
for i=1, #radarGridLevels do
	radarFrame[#radarFrame+1] = radarShape("Ring"..i)
end
for i=1, radarAxisCount do
	radarFrame[#radarFrame+1] = Def.Quad{
		Name="Spoke"..i,
		-- Anchored at the centre and rotated outwards, so one quad per axis is
		-- all the spokes cost.
		InitCommand=function(self) self:align(0,0.5):diffuse(H.White):diffusealpha(0.12) end,
	}
end
radarFrame[#radarFrame+1] = radarShape("Fill")
radarFrame[#radarFrame+1] = radarShape("Outline")
for i=1, radarAxisCount do
	radarFrame[#radarFrame+1] = Def.BitmapText{
		Name="Label"..i, Font=H.FontBold,
		InitCommand=function(self) self:diffuse(H.Muted) end,
	}
end
af[#af+1] = radarFrame
for i=1, #statRows do
	af[#af+1] = Def.BitmapText{
		Name="StatRow"..i, Font=H.Font,
		InitCommand=function(self)
			self:horizalign(left):zoom(H.NormalZoom(0.040)):diffuse(H.Black)
				:maxwidth(58/H.NormalZoom(0.040))
		end,
	}
end
H.AddSettledRefresh(af, 0.35, 16, 0)
return af
