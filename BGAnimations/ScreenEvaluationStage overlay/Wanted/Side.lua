-- One player's side of the WANTED page: the plates of the artwork with the
-- player's name, level, modifiers, EX and ITG scores, grade, judgment ladder,
-- holds/mines/rolls and graph.  Player 1 is laid out as drawn; player 2 is the
-- mirror image (pictures flipped, text placed at mirrored anchors and turned
-- the other way, but still reading left to right).
--
-- Returns two actors: `art`, in artboard pixels (placed under the page's
-- zoomed root), and `cutouts`, the name and grade in cutout lettering, in
-- theme units (cutout slots render at display resolution and must not sit
-- under a zoom).
--
-- The side listens for VOLT26EvaluationPage {Side=, Page=}: page 0 is this
-- page; any other page shows an inherited pane over the ladder (placed by
-- default.lua), so the ladder's text, the grade and the graph are hidden and
-- only the plates stay.
local p = ...
local Art, T, player, side = p.Art, p.Text, p.player, p.side
local mirror = side == PLAYER_2
local card = VOLT26.EvaluationPage.GetCard(player)

local function hex(s) return color(s) end
-- The artwork's judgment colours: bright for the label and count, dark for a
-- count's leading zeros.
local ROW = {
	W0   = { hex("#00edff"), hex("#00a4a8") },
	W1   = { hex("#ffffff"), hex("#8e8e8e") },
	W2   = { hex("#ff8b00"), hex("#a35500") },
	W3   = { hex("#13bf00"), hex("#0f7500") },
	W4   = { hex("#ff00ed"), hex("#9b0097") },
	W5   = { hex("#c65500"), hex("#6d2c00") },
	Miss = { hex("#ff0000"), hex("#8c0000") },
}
local OFF = hex("#3a3a3a")
local EX_TINT, ITG_TINT = hex("#64e7c8"), hex("#f580eb")
local WHITE, BLACK, GREY = hex("#ffffff"), hex("#000000"), hex("#8e8e8e")
local COUNT_DIGITS = 5

local function mx(x) return mirror and 1920 - x or x end

-- A picture of the artwork at its crop rectangle (mirrored for player 2).
local function picture(name, crop)
	return Def.Sprite{
		Name=name,
		Texture=THEME:GetPathG("", "VOLT26/Wanted/" .. name .. ".png"),
		InitCommand=function(self)
			self:align(0, 0):xy(crop.x, crop.y)
			-- Flipped about its left edge, which lands on the mirrored one.
			if mirror then self:x(1920 - crop.x):zoomx(-1) end
		end,
	}
end

-- The graph's corners, swapped left for right when mirrored so the song still
-- runs left to right.
local function graphQuad()
	local g = Art.graph
	if not mirror then return g end
	local function m(pt) return { 1920 - pt[1], pt[2] } end
	return { topLeft = m(g.topRight), topRight = m(g.topLeft), bottomRight = m(g.bottomLeft), bottomLeft = m(g.bottomRight) }
end

local art = Def.ActorFrame{ Name="Side" .. ToEnumShortString(side) }
art[#art+1] = picture("panel_head", Art.head)

-- The ladder, the holds box and the graph frame.
local body = Def.ActorFrame{ Name="Body" }
body[#body+1] = picture("panel_body", Art.body)
art[#art+1] = body

-- What the inherited panes cover: hidden on any other page.
local ladder = Def.ActorFrame{ Name="Ladder" }
art[#art+1] = ladder

-- Level: "LV" and the chart's meter, the digits held to the artwork's width.
local level, meter = Art.level, tostring(card.meter)
art[#art+1] = T.Run({ x = level.x, y = level.y, rot = level.rot }, {
	{ font = "Score", size = level.lvCap / T.CAP.Score, color = BLACK, text = "LV", width = level.lvWidth },
	{ font = "Score", size = level.cap / T.CAP.Score, color = BLACK, text = meter,
		pad = level.gap, width = level.digit * #meter },
}, mirror)

-- Modifiers, wrapped on the white plate right of the level.
art[#art+1] = LoadFont(T.Font.Bold)..{
	Name="Modifiers",
	InitCommand=function(self)
		local a = Art.mods
		local zoom = a.size / T.EM.Bold
		local width = 250
		-- The face's line spacing (1.2 em) at 19 px is the artwork's 22.8 px
		-- line gap.  Three lines fit on the plate; more are squeezed.
		self:zoom(zoom):diffuse(BLACK):halign(mirror and 1 or 0):valign(0)
			:wrapwidthpixels(width / zoom):maxheight(3 * a.lineGap / zoom):settext(card.modifiers)
		self:xy(mx(a.x), a.y - a.size * T.CAP.Bold):rotationz(mirror and -a.rot or a.rot)
	end,
}

-- EX and ITG scores, each held to the length of the rule under it.
local function score(anchor, tag, value, tint)
	return T.Run(anchor, {
		{ font = "Score", size = 20.5, color = tint, text = tag .. " " },
		{ font = "Score", size = anchor.size, color = tint, text = value },
		{ font = "Score", size = 31.8, color = tint, text = " / 100" },
	}, mirror, anchor.width)
end
art[#art+1] = score(Art.ex, "EX", card.ex, EX_TINT)
art[#art+1] = score(Art.itg, "ITG", card.itg, ITG_TINT)

-- The judgment ladder: "Label · 00015", the count's leading zeros dark.
for index, row in ipairs(card.rows) do
	local anchor = Art.rows[index]
	if anchor then
		local tints = ROW[row.key]
		local bright, dim = tints[1], tints[2]
		if not row.enabled then bright, dim = OFF, OFF end
		local digits, lead = T.Padded(row.count, COUNT_DIGITS)
		-- Rows beside the holds box stop short of it (anchor.width).
		ladder[#ladder+1] = T.Run(anchor, {
			{ font = "Label", size = anchor.size, color = bright, text = row.label .. " · " },
			{ font = "Label", size = anchor.size, color = bright, text = digits, dim = { lead, dim } },
		}, mirror, anchor.width)
	end
end

-- Holds, mines and rolls: done / possible, the done count padded to the
-- possible count's width.
local extras = { { "holds", card.holds }, { "mines", card.mines }, { "rolls", card.rolls } }
for index, entry in ipairs(extras) do
	local a = Art.extra
	local anchor = { x = a.x, y = a.y, rot = a.rot, sx = a.sx, sy = a.sy }
	-- Lines follow the turned text block: offset along its own vertical.
	local gap = (index - 1) * a.lineGap
	local r = math.rad(a.rot)
	anchor.x, anchor.y = a.x - math.sin(r) * gap, a.y + math.cos(r) * gap
	local possible = entry[2].possible
	local digits, lead = T.Padded(entry[2].actual, #tostring(possible))
	ladder[#ladder+1] = T.Run(anchor, {
		{ font = "Label", size = a.size, color = WHITE, text = entry[1] .. " · " },
		{ font = "Bold", size = a.size, color = WHITE, text = digits .. "/" .. possible, dim = { lead, GREY } },
	}, mirror)
end

-- The graph.
ladder[#ladder+1] = LoadActor("./Graph.lua", {
	Art = Art, quad = graphQuad(), graph = VOLT26.EvaluationPage.GetGraph(player),
	colors = { W0 = ROW.W0[1], W1 = ROW.W1[1], W2 = ROW.W2[1], W3 = ROW.W3[1], W4 = ROW.W4[1], W5 = ROW.W5[1] },
	font = T.Font.Bold, fontZoom = 20 / T.EM.Bold,
	palette = side == PLAYER_2 and "blue" or "red",
})

art.VOLT26EvaluationPageMessageCommand = function(self, params)
	if params.Side ~= side then return end
	self:GetChild("Ladder"):visible(params.Page == 0)
end

-- ---------------------------------------------------------------------------
-- Cutout lettering, in theme units.  S converts artboard pixels.
local S, OX = p.S, p.OX
local function placed(box)
	return OX + mx(box.cx) * S, box.cy * S
end

local cutouts = Def.ActorFrame{ Name="Cutouts" .. ToEnumShortString(side) }

local function slot(styleName, box, text, extraTilt)
	local style = VOLT26.Cutout.Style(styleName)
	if not style then return nil end
	local opts = {}
	for k, v in pairs(style.opts) do opts[k] = v end
	if mirror and opts.tiltDeg then opts.tiltDeg = -opts.tiltDeg end
	return VOLT26.Cutout.CreateSlot{
		maxW = style.maxW, maxH = style.maxH, maxChars = style.maxChars,
		halign = 0.5, valign = 0.5, opts = opts,
		onInit = function(s)
			local x, y = placed(box)
			s:xy(x, y)
		end,
	}..{
		OnCommand=function(self) self:playcommand("CutoutSet", { text = text }) end,
	}
end

local name = slot("EvalName", Art.name, card.name)
if name then cutouts[#cutouts+1] = name end

local grade = Def.ActorFrame{ Name="Grade" }
if card.gradeLetter then
	local letter = slot("EvalGrade", Art.grade, card.gradeLetter)
	if letter then grade[#grade+1] = letter end
elseif card.gradeStars > 0 then
	-- Star grades: the grade star picture, as many as the song wheel shows.
	local layouts = {
		[1] = { { 0, 0, 0.8 } },
		[2] = { { -39, 40, 0.6 }, { 39, -40, 0.6 } },
		[3] = { { -45, 40, 0.5 }, { 0, -40, 0.5 }, { 45, 40, 0.5 } },
		[4] = { { -46, -46, 0.5 }, { 46, -46, 0.5 }, { -46, 46, 0.5 }, { 46, 46, 0.5 } },
		[5] = { { 0, -54, 0.35 }, { -52, -16, 0.35 }, { 52, -16, 0.35 }, { -32, 50, 0.35 }, { 32, 50, 0.35 } },
	}
	local stars = Def.ActorFrame{
		InitCommand=function(self)
			local x, y = placed(Art.grade)
			self:xy(x, y):zoom(S * 0.8):rotationz(mirror and -Art.grade.rot or Art.grade.rot)
		end,
	}
	for _, at in ipairs(layouts[card.gradeStars]) do
		stars[#stars+1] = Def.Sprite{
			Texture=THEME:GetPathG("", "_grades/assets/star.png"),
			InitCommand=function(self)
				self:xy(at[1], at[2]):zoom(at[3])
				if card.gradeStars == 5 then self:rainbow():effectperiod(2.4) end
			end,
		}
	end
	grade[#grade+1] = stars
end
grade.VOLT26EvaluationPageMessageCommand = function(self, params)
	if params.Side ~= side then return end
	self:visible(params.Page == 0)
end
cutouts[#cutouts+1] = grade

return { art = art, cutouts = cutouts }
