-- One card per joined player on the right of the song select, as the owner
-- drew them: a white plate with the player's name (cutout lettering), "STEPS
-- BY" the chart's author, "LV" and the meter; the player's best EX and ITG on
-- the black frame; a box of the chart's counts (notes, jumps, holds, mines,
-- rolls, peak NPS, stream); and the chart's density in the slanted graph frame
-- with its stream breakdown.
--
-- The cards' pictures and every anchor come from the artwork
-- (tools/song-select/build_cards_art.py -> Graphics/VOLT26/SongSelect/
-- card1.png, card2.png and CardsArt.lua).  Cards follow the joined players in
-- order, so a lone player takes the first card.  The density is the player's
-- colour: red for player 1, blue for player 2.
local p = ...
local K, S = p.K, p.S
local P = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/P5.lua"))
local Art = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/CardsArt.lua"))

-- The evaluation's bitmap stand-ins for the artwork's Helvetica Now Display
-- (tools/evaluation/build_fonts.py): em sizes in texture pixels.
local FONT = { Label = "VOLT26 Eval Label", Bold = "VOLT26 Eval Bold", Score = "VOLT26 Eval Score" }
local EM = { Label = 48, Bold = 48, Score = 96 }
local CAP_SCORE = 68 / 96

local WHITE, BLACK, GREY = color("#ffffff"), color("#000000"), color("#8e8e8e")
local EX_TINT, ITG_TINT = color("#64e7c8"), color("#f580eb")
local DENSITY = {
	[PLAYER_1] = { deep = color("#3a0000"), peak = color("#ff2a12"), edge = color("#ff7a5c") },
	[PLAYER_2] = { deep = color("#00103a"), peak = color("#0a7dff"), edge = color("#66c6ff") },
}

local STATS = { "notes", "jumps", "holds", "mines", "rolls", "peak nps", "stream" }
local RADAR = {
	notes = "RadarCategory_TapsAndHolds", jumps = "RadarCategory_Jumps", holds = "RadarCategory_Holds",
	mines = "RadarCategory_Mines", rolls = "RadarCategory_Rolls",
}

-- A line of text segments set side by side from a baseline, re-laid out
-- whenever its text changes.  a = {x, y, rot, sx}; segs = {{name, font,
-- size, colour, fixed text}}.
local function run(name, a, segs, maxWidth, centre)
	local frame = Def.ActorFrame{
		Name = name,
		InitCommand = function(self)
			self:xy(a.x, a.y):rotationz(a.rot or 0):zoomx(a.sx or 1)
			self.layout = function()
				local total, widths = 0, {}
				for i, seg in ipairs(segs) do
					local child = self:GetChild(seg[1])
					child:zoomx(child:GetZoomY())
					widths[i] = child:GetZoomedWidth()
					total = total + widths[i]
				end
				local squeeze = (maxWidth and total > maxWidth) and maxWidth / total or 1
				local x = centre and -total * squeeze / 2 or 0
				for i, seg in ipairs(segs) do
					local child = self:GetChild(seg[1])
					child:x(x):zoomx(child:GetZoomY() * squeeze)
					x = x + widths[i] * squeeze
				end
			end
		end,
	}
	for _, seg in ipairs(segs) do
		frame[#frame+1] = LoadFont(FONT[seg[2]])..{
			Name = seg[1],
			InitCommand = function(self)
				self:halign(0):valign(1):zoom(seg[3] / EM[seg[2]]):diffuse(seg[4] or WHITE)
				if seg[5] then self:settext(seg[5]) end
			end,
		}
	end
	return frame
end

-- A digit string padded with zeros to `digits`; the padding is drawn dim.
local function padded(child, value, digits)
	local text = tostring(value)
	local lead = math.max(0, digits - #text)
	child:settext(("0"):rep(lead) .. text)
	if lead > 0 then child:AddAttribute(0, { Length = lead, Diffuse = GREY }) end
end

-- The graph: a point (u along the chart, v up from the bottom) placed between
-- the frame's four corners, so the profile follows the frame's slant.
local function graphPoint(q, u, v)
	local tl, tr, br, bl = q.topLeft, q.topRight, q.bottomRight, q.bottomLeft
	local topX, topY = tl[1] + (tr[1] - tl[1]) * u, tl[2] + (tr[2] - tl[2]) * u
	local botX, botY = bl[1] + (br[1] - bl[1]) * u, bl[2] + (br[2] - bl[2]) * u
	return topX + (botX - topX) * (1 - v), topY + (botY - topY) * (1 - v)
end

local function mix(a, b, t, alpha)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, alpha or 1 }
end

local function densityVertices(q, data, palette)
	local strip, edge = {}, {}
	if not data or #data.nps == 0 or (data.peak or 0) <= 0 then return strip, edge end
	local count = #data.nps
	for i, value in ipairs(data.nps) do
		local u = count > 1 and (i - 1) / (count - 1) or 0
		local v = math.min(1, value / data.peak) * 0.92
		local bx, by = graphPoint(q, u, 0)
		local tx, ty = graphPoint(q, u, v)
		strip[#strip+1] = { { bx, by, 0 }, mix(palette.deep, palette.peak, 0, 0.95) }
		strip[#strip+1] = { { tx, ty, 0 }, mix(palette.deep, palette.peak, v, 0.95) }
		edge[#edge+1] = { { tx, ty, 0 }, palette.edge }
	end
	return strip, edge
end

-- The stream breakdown (Simply Love's "15 (20) 350 (2) 11"), shortened until
-- it fits.
local function breakdownText(chart, player, actor, width)
	if not chart or S.IsCourseMode() or not VOLT26.ChartAnalysis then return "" end
	local ok, perMeasure = pcall(function() return chart:GetNotesPerMeasure(player) end)
	if not ok or type(perMeasure) ~= "table" then return "" end
	local text = ""
	for level = 0, 3 do
		local okText, value = pcall(VOLT26.ChartAnalysis.GetBreakdownText, perMeasure, level)
		text = okText and value or ""
		actor:settext(text)
		if actor:GetZoomedWidth() <= width then break end
	end
	return text
end

local function percent(value)
	if not value then return K.Dash end
	return ("%.2f"):format(value)
end

local function fill(card, art, player, item)
	local chart = S.Chart(player)
	local data = S.ChartData(player)

	local name = S.PlayerName(player)
	if card.name ~= name then
		card.name = name
		P.SetCutout(card:GetChild("NameFrame"):GetChild("Name"), name)
	end

	local credit = S.StepArtist(chart)
	local steps = card:GetChild("Steps")
	steps:GetChild("Text"):settext(credit ~= "" and ("STEPS BY " .. credit:upper()) or "")
	steps.layout()

	local level = card:GetChild("Level")
	level:GetChild("Meter"):settext(chart and tostring(math.floor((tonumber(chart:GetMeter()) or 0) + 0.5)) or K.Dash)
	level.layout()

	local best = S.Best(player, item, chart)
	local ex, itg = card:GetChild("Ex"), card:GetChild("Itg")
	ex:GetChild("Value"):settext(percent(best and best.ExPercent))
	itg:GetChild("Value"):settext(percent(best and best.PercentDP and best.PercentDP * 100))
	ex.layout()
	itg.layout()

	for i, stat in ipairs(STATS) do
		local line = card:GetChild("Stat" .. i)
		local value = line:GetChild("Value")
		if not chart then
			value:settext(K.Dash)
		elseif RADAR[stat] then
			padded(value, S.Radar(chart, player, RADAR[stat]) or 0, 3)
		elseif stat == "peak nps" then
			value:settext(("%.1f"):format(data.peak or 0))
		else
			value:settext(("%d (%d%%)"):format(data.streamMeasures or 0, math.floor((data.stream or 0) * 100 + 0.5)))
		end
		line.layout()
	end

	local strip, edge = densityVertices(art.graph, chart and data or nil, DENSITY[player] or DENSITY[PLAYER_1])
	P.SetVertices(card:GetChild("Density"), strip)
	P.SetVertices(card:GetChild("DensityEdge"), edge)
	local breakdown = card:GetChild("Breakdown")
	local graphWidth = art.graph.topRight[1] - art.graph.topLeft[1]
	breakdownText(chart, player, breakdown:GetChild("Text"), graphWidth * 0.8)
	breakdown.layout()

	-- A new chart: its graph rises from the floor.
	if card.chart ~= chart then
		card.chart = chart
		for _, child in ipairs({ "Density", "DensityEdge" }) do
			card:GetChild(child):stoptweening():diffusealpha(0):decelerate(0.22):diffusealpha(1)
		end
	end
end

local af = Def.ActorFrame{
	Name="Cards",
	RefreshCommand=function(self)
		local item = S.Item()
		local players = GAMESTATE:GetHumanPlayers()
		for c, art in ipairs(Art.cards) do
			local card = self:GetChild("Card" .. c)
			local player = players[c]
			card:visible(player ~= nil)
			if player then fill(card, art, player, item) end
		end
	end,
}

for c, art in ipairs(Art.cards) do
	local card = Def.ActorFrame{
		Name = "Card" .. c,
		-- Arriving: the cards slide in from the right edge, one after the other.
		OnCommand = function(self)
			self:stoptweening():x(760):sleep(0.14 + (c - 1) * 0.06)
				:decelerate(0.17):x(-14):decelerate(0.06):x(0)
		end,
		Def.Sprite{
			Name = "Picture",
			Texture = THEME:GetPathG("", "VOLT26/SongSelect/" .. art.picture .. ".png"),
			InitCommand = function(self) self:align(0, 0):xy(art.x, art.y) end,
		},
		Def.ActorMultiVertex{ Name = "Density",
			InitCommand = function(self) self:SetDrawState{ Mode = "DrawMode_QuadStrip" } end },
		Def.ActorMultiVertex{ Name = "DensityEdge",
			InitCommand = function(self) self:SetDrawState{ Mode = "DrawMode_LineStrip" }:SetLineWidth(1.5) end },
		-- The name, centred on the artwork's name; the lettering's own tilt
		-- (-3 degrees) plus the frame's turn make the artwork's.
		Def.ActorFrame{
			Name = "NameFrame",
			InitCommand = function(self) self:xy(art.name.cx, art.name.cy):rotationz(art.name.rot + 3) end,
			P.CutoutSlot{ Name = "Name", Id = "Card" .. c .. "Name", X = 0, Y = 0, Scale = K.Scale },
		},
		run("Steps", art.steps, { { "Text", "Bold", art.steps.size, BLACK } },
			art.level.x - art.steps.x - 8),
		-- "LV" and the meter, the meter held to the artwork's digit width.
		Def.ActorFrame{
			Name = "Level",
			InitCommand = function(self)
				local a = art.level
				self:xy(a.x, a.y):rotationz(a.rot)
				self.layout = function()
					local lv, meter = self:GetChild("LV"), self:GetChild("Meter")
					lv:zoomx(lv:GetZoomY())
					if lv:GetZoomedWidth() > a.lvWidth then lv:zoomx(lv:GetZoomY() * a.lvWidth / lv:GetZoomedWidth()) end
					meter:zoomx(meter:GetZoomY())
					local most = a.digit * #meter:GetText()
					if meter:GetZoomedWidth() > most then meter:zoomx(meter:GetZoomY() * most / meter:GetZoomedWidth()) end
					meter:x(math.min(lv:GetZoomedWidth(), a.lvWidth) + a.gap)
				end
			end,
			LoadFont(FONT.Score)..{ Name = "LV", Text = "LV", InitCommand = function(self)
				self:halign(0):valign(1):zoom(art.level.lvCap / CAP_SCORE / EM.Score):diffuse(BLACK) end },
			LoadFont(FONT.Score)..{ Name = "Meter", InitCommand = function(self)
				self:halign(0):valign(1):zoom(art.level.cap / CAP_SCORE / EM.Score):diffuse(BLACK) end },
		},
		run("Ex", art.ex, {
			{ "Tag", "Score", art.ex.small, EX_TINT, "EX " }, { "Value", "Score", art.ex.size, EX_TINT },
			{ "Tail", "Score", art.ex.tail, EX_TINT, " / 100" } }, art.ex.width * 1.18),
		run("Itg", art.itg, {
			{ "Tag", "Score", art.itg.small, ITG_TINT, "ITG " }, { "Value", "Score", art.itg.size, ITG_TINT },
			{ "Tail", "Score", art.itg.tail, ITG_TINT, " / 100" } }, art.itg.width * 1.18),
		run("Breakdown", art.breakdown, { { "Text", "Bold", art.breakdown.size, BLACK } }, nil, true),
	}
	for i, stat in ipairs(STATS) do
		local a = art.stats
		local r = math.rad(a.rot)
		local gap = (i - 1) * a.lineGap
		local anchor = { x = a.x - math.sin(r) * gap, y = a.y + math.cos(r) * gap, rot = a.rot, sx = a.sx }
		card[#card+1] = run("Stat" .. i, anchor, {
			{ "Label", stat == "stream" and "Bold" or "Label", a.size, WHITE, stat .. " · " },
			{ "Value", "Bold", a.size, WHITE } }, 150)
	end
	af[#af+1] = card
end

return af
