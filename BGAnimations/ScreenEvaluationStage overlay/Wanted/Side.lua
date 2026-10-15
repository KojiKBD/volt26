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
-- The plates (name, level, modifiers, scores) are on every page.  Below them
-- each page has its own body (VOLT26.EvaluationPage.Pages, turned with
-- MenuLeft / MenuRight; the side listens for VOLT26EvaluationPage
-- {Side=, Page=}, Page counted from 0):
--   wanted  the judgment ladder, holds box and grade
--   notes   per-column judgments under the noteskin's arrows (Notes.lua)
--   timing  the offset histogram and statistics, in the same container
--           (Timing.lua)
--   qr      the GrooveStats QR code and the best scores (Qr.lua)
-- The graph is on the first three pages.
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

-- ---------------------------------------------------------------------------
-- Motion (see "Motion" in docs/evaluation-wanted.md).  Everything waits off
-- screen until the overlay broadcasts VOLT26EvaluationWantedIntro (when the
-- victory / defeat transition clears), then comes in from the side's outer
-- edge: the head plate, the page body, the ladder row by row, the scores, the
-- graph drawing itself left to right and last the grade.  OffCommand sends it
-- all back out the way it came.
local AWAY = mirror and 1 or -1            -- the side's outer edge, screen x
local M = {
	head = 0,       body = 0.08,       rows = 0.30,   rowStep = 0.045,
	scores = 0.34,  scoreStep = 0.07,  graph = 0.42,  grade = 0.85,
	slide = 1100,   turn = 9,          pageSlide = 190,
}

-- A frame turned and zoomed about (px, py) of its parent: the returned outer
-- frame sits at the pivot, `inner` takes the children at their own places.
local function pivotFrame(name, px, py)
	local inner = Def.ActorFrame{
		Name="Inner",
		InitCommand=function(self) self:xy(-px, -py) end,
	}
	local outer = Def.ActorFrame{
		Name=name,
		InitCommand=function(self) self:xy(px, py) end,
		inner,
	}
	return outer, inner
end

-- A plate that slides in from the outer edge, turning as it lands.  `scale`
-- converts artboard pixels to the frame's units (1 for the art, S for the
-- cutouts); `delay` is its place in the intro.
local function slider(frame, px, py, scale, delay)
	local slide = M.slide * scale
	frame.InitCommand = function(self)
		self:xy(px + AWAY * slide, py):rotationz(-AWAY * M.turn)
	end
	frame.VOLT26EvaluationWantedIntroMessageCommand = function(self)
		self:finishtweening():xy(px + AWAY * slide, py):rotationz(-AWAY * M.turn)
			:sleep(delay)
			:decelerate(0.26):x(px - AWAY * 18 * scale):rotationz(AWAY * 1.2)
			:decelerate(0.10):x(px):rotationz(0)
	end
	frame.OffCommand = function(self)
		self:finishtweening():sleep(math.max(0, 0.08 - delay))
			:accelerate(0.22):x(px + AWAY * slide):rotationz(-AWAY * M.turn)
	end
	return frame
end

-- A line that steps in from the outer edge after the plates have landed.
local function stepIn(actor, delay)
	return Def.ActorFrame{
		InitCommand=function(self) self:x(AWAY * 70):diffusealpha(0) end,
		VOLT26EvaluationWantedIntroMessageCommand=function(self)
			self:finishtweening():x(AWAY * 70):diffusealpha(0)
				:sleep(delay):decelerate(0.18):x(0):diffusealpha(1)
		end,
		actor,
	}
end

-- A figure that stamps down onto its place (px, py).
local function stamp(actor, px, py, delay)
	local outer, inner = pivotFrame("Stamp", px, py)
	inner[#inner+1] = actor
	outer.InitCommand = function(self) self:xy(px, py):zoom(1.8):diffusealpha(0) end
	outer.VOLT26EvaluationWantedIntroMessageCommand = function(self)
		self:finishtweening():zoom(1.8):diffusealpha(0):sleep(delay)
			:accelerate(0.12):zoom(0.94):diffusealpha(1)
			:decelerate(0.08):zoom(1)
	end
	return outer
end

local HEAD_PIVOT = { mx(Art.head.x + Art.head.w / 2), Art.head.y + Art.head.h / 2 }
local BODY_PIVOT = { mx(Art.page.x + Art.page.w / 2), Art.page.y + Art.page.h / 2 }

local art = Def.ActorFrame{ Name="Side" .. ToEnumShortString(side) }

-- The head plate's picture is under the page bodies; its text is drawn over
-- them (headText below) and moves with it.
local headPlate, headPlateInner = pivotFrame("HeadPlate", HEAD_PIVOT[1], HEAD_PIVOT[2])
headPlateInner[#headPlateInner+1] = picture("panel_head", Art.head)
art[#art+1] = slider(headPlate, HEAD_PIVOT[1], HEAD_PIVOT[2], 1, M.head)

-- One frame per page; only the shown page's is visible.
local PAGES = VOLT26.EvaluationPage.Pages
local pageFrames = {}
local body, bodyInner = pivotFrame("Body", BODY_PIVOT[1], BODY_PIVOT[2])
art[#art+1] = slider(body, BODY_PIVOT[1], BODY_PIVOT[2], 1, M.body)
for index, name in ipairs(PAGES) do
	pageFrames[name] = Def.ActorFrame{
		Name="Page_" .. name,
		InitCommand=function(self) self:visible(index == 1) end,
	}
	bodyInner[#bodyInner+1] = pageFrames[name]
end

local headText, headTextInner = pivotFrame("HeadText", HEAD_PIVOT[1], HEAD_PIVOT[2])
art[#art+1] = slider(headText, HEAD_PIVOT[1], HEAD_PIVOT[2], 1, M.head)

-- The ladder, the holds box and the graph frame.
local ladder = pageFrames.wanted
ladder[#ladder+1] = picture("panel_body", Art.body)

local pageArgs = { Art = Art, T = T, player = player, mirror = mirror, ROW = ROW, OFF = OFF }
pageFrames.notes[#pageFrames.notes+1] = picture("panel_notes", Art.page)
pageFrames.notes[#pageFrames.notes+1] = LoadActor("./Notes.lua", pageArgs)
pageFrames.timing[#pageFrames.timing+1] = picture("panel_notes", Art.page)
pageFrames.timing[#pageFrames.timing+1] = LoadActor("./Timing.lua", pageArgs)
pageFrames.qr[#pageFrames.qr+1] = picture("panel_qr", Art.page)
pageFrames.qr[#pageFrames.qr+1] = LoadActor("./Qr.lua", pageArgs)

-- The owner's NOTES and Qr titles: placed (mirrored for player 2) but never
-- flipped, so they still read.
local function title(name, box)
	return Def.Sprite{
		Name=name,
		Texture=THEME:GetPathG("", "VOLT26/Wanted/" .. name .. ".png"),
		InitCommand=function(self)
			self:xy(mx(box.cx), box.cy):zoomto(box.w, box.h):rotationz(mirror and -box.rot or box.rot)
		end,
	}
end
pageFrames.notes[#pageFrames.notes+1] = title("label_notes", Art.notes.label)
pageFrames.qr[#pageFrames.qr+1] = title("label_qr", Art.qr.label)

-- Level: "LV" and the chart's meter, the digits held to the artwork's width.
local level, meter = Art.level, tostring(card.meter)
headTextInner[#headTextInner+1] = T.Run({ x = level.x, y = level.y, rot = level.rot }, {
	{ font = "Score", size = level.lvCap / T.CAP.Score, color = BLACK, text = "LV", width = level.lvWidth },
	{ font = "Score", size = level.cap / T.CAP.Score, color = BLACK, text = meter,
		pad = level.gap, width = level.digit * #meter },
}, mirror)

-- Modifiers, wrapped on the white plate right of the level.
headTextInner[#headTextInner+1] = LoadFont(T.Font.Bold)..{
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
-- Each stamps down once the plate has landed.
for index, entry in ipairs({ { Art.ex, "EX", card.ex, EX_TINT }, { Art.itg, "ITG", card.itg, ITG_TINT } }) do
	local a = entry[1]
	headTextInner[#headTextInner+1] = stamp(score(a, entry[2], entry[3], entry[4]),
		mx(a.x + (a.width or 0) / 2), a.y - a.size * 0.35,
		M.scores + (index - 1) * M.scoreStep)
end

-- The judgment ladder: "Label · 00015", the count's leading zeros dark.
for index, row in ipairs(card.rows) do
	local anchor = Art.rows[index]
	if anchor then
		local tints = ROW[row.key]
		local bright, dim = tints[1], tints[2]
		if not row.enabled then bright, dim = OFF, OFF end
		local digits, lead = T.Padded(row.count, COUNT_DIGITS)
		-- Rows beside the holds box stop short of it (anchor.width).
		ladder[#ladder+1] = stepIn(T.Run(anchor, {
			{ font = "Label", size = anchor.size, color = bright, text = row.label .. " · " },
			{ font = "Label", size = anchor.size, color = bright, text = digits, dim = { lead, dim } },
		}, mirror, anchor.width), M.rows + (index - 1) * M.rowStep)
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
	ladder[#ladder+1] = stepIn(T.Run(anchor, {
		{ font = "Label", size = a.size, color = WHITE, text = entry[1] .. " · " },
		{ font = "Bold", size = a.size, color = WHITE, text = digits .. "/" .. possible, dim = { lead, GREY } },
	}, mirror), M.rows + (#card.rows + index - 1) * M.rowStep)
end

-- The graph, over the page bodies (on every page but the QR page).  It
-- travels with the body and draws itself in once the body has landed.  Its
-- slanted frame (panel_graph, cut out of the page pictures) is here too, not
-- in the pages, so turning between pages that all have the graph leaves it
-- still; it fades only on the way to and from the QR page.
local graphSlide, graphInner = pivotFrame("GraphSlide", BODY_PIVOT[1], BODY_PIVOT[2])
graphInner[#graphInner+1] = Def.ActorFrame{
	Name="GraphFade",
	picture("panel_graph", Art.page),
	LoadActor("./Graph.lua", {
		Art = Art, quad = graphQuad(), graph = VOLT26.EvaluationPage.GetGraph(player),
		colors = { W0 = ROW.W0[1], W1 = ROW.W1[1], W2 = ROW.W2[1], W3 = ROW.W3[1], W4 = ROW.W4[1], W5 = ROW.W5[1] },
		font = T.Font.Bold, fontZoom = 20 / T.EM.Bold,
		palette = side == PLAYER_2 and "blue" or "red",
		introDelay = M.graph,
	}),
}
art[#art+1] = slider(graphSlide, BODY_PIVOT[1], BODY_PIVOT[2], 1, M.body)

-- Turning a page: the page that was shown slides off toward where the input
-- came from (MenuRight: to the left) and the new one slides in from the other
-- side.  `frames` maps page names to their frames, `slide` is the distance in
-- the frames' units.  Without a direction (the first broadcast) the page is
-- simply shown.  An interrupted turn is settled first.
local function turnPage(frames, old, new, direction, slide)
	for name, frame in pairs(frames) do
		frame:finishtweening():x(0):diffusealpha(1):visible(name == old)
	end
	if not direction or old == new then
		for name, frame in pairs(frames) do frame:visible(name == new) end
		return
	end
	if frames[old] then
		frames[old]:accelerate(0.1):x(-direction * slide):diffusealpha(0):queuecommand("PageGone")
	end
	if frames[new] then
		frames[new]:visible(true):x(direction * slide):diffusealpha(0)
			:sleep(0.05):decelerate(0.16):x(0):diffusealpha(1)
		frames[new]:playcommand("PageShown")
	end
end
for _, frame in pairs(pageFrames) do
	frame.PageGoneCommand = function(self) self:visible(false):x(0):diffusealpha(1) end
end

art.InitCommand = function(self) self.page = PAGES[1] end
art.VOLT26EvaluationPageMessageCommand = function(self, params)
	if params.Side ~= side then return end
	local shown = PAGES[(params.Page or 0) + 1] or PAGES[1]
	local frames = {}
	local inner = self:GetChild("Body"):GetChild("Inner")
	for _, name in ipairs(PAGES) do frames[name] = inner:GetChild("Page_" .. name) end
	turnPage(frames, self.page, shown, params.Direction, M.pageSlide)
	self.page = shown
	local fade = self:GetChild("GraphSlide"):GetChild("Inner"):GetChild("GraphFade")
	fade:finishtweening()
	if params.Direction then
		fade:linear(shown ~= "qr" and 0.18 or 0.1):diffusealpha(shown ~= "qr" and 1 or 0)
	else
		fade:diffusealpha(shown ~= "qr" and 1 or 0)
	end
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

-- The name moves with the head plate, in screen units about the same pivot.
local headPivotX, headPivotY = OX + HEAD_PIVOT[1] * S, HEAD_PIVOT[2] * S
local nameSlide, nameInner = pivotFrame("NameSlide", headPivotX, headPivotY)
local name = slot("EvalName", Art.name, card.name)
if name then nameInner[#nameInner+1] = name end
cutouts[#cutouts+1] = slider(nameSlide, headPivotX, headPivotY, S, M.head)

-- The grade, about its own centre: stamped down last in the intro, and in and
-- out as the WANTED page comes and goes.
local gradeX, gradeY = placed(Art.grade)
local grade, gradeInner = pivotFrame("Grade", gradeX, gradeY)
if card.gradeLetter then
	local letter = slot("EvalGrade", Art.grade, card.gradeLetter)
	if letter then gradeInner[#gradeInner+1] = letter end
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
			self:xy(gradeX, gradeY):zoom(S * 0.8):rotationz(mirror and -Art.grade.rot or Art.grade.rot)
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
	gradeInner[#gradeInner+1] = stars
end
local GRADE_TURN = AWAY * 25
grade.InitCommand = function(self)
	self:xy(gradeX, gradeY):zoom(3):rotationz(GRADE_TURN):diffusealpha(0)
end
grade.VOLT26EvaluationWantedIntroMessageCommand = function(self)
	self:finishtweening():zoom(3):rotationz(GRADE_TURN):diffusealpha(0):sleep(M.grade)
		:accelerate(0.14):zoom(0.9):rotationz(0):diffusealpha(1)
		:decelerate(0.06):zoom(1.06)
		:accelerate(0.06):zoom(1)
end
grade.VOLT26EvaluationPageMessageCommand = function(self, params)
	if params.Side ~= side then return end
	local shown = (params.Page or 0) == 0
	if not params.Direction then self:visible(shown) return end
	self:finishtweening()
	if shown then
		self:visible(true):zoom(1.7):rotationz(GRADE_TURN * 0.5):diffusealpha(0)
			:sleep(0.08):accelerate(0.12):zoom(1):rotationz(0):diffusealpha(1)
	elseif self:GetVisible() then
		self:accelerate(0.1):zoom(0.6):diffusealpha(0):queuecommand("Gone")
	end
end
grade.GoneCommand = function(self) self:visible(false):zoom(1):diffusealpha(1) end
grade.OffCommand = function(self)
	self:finishtweening():accelerate(0.14):zoom(0.2):rotationz(-GRADE_TURN):diffusealpha(0)
end
cutouts[#cutouts+1] = grade

-- The timing page's title, in cutout lettering where NOTES has its title
-- (the artwork has no timing page; NOTES and Qr are the owner's pictures).
-- It turns with its page, in screen units.
local labels = {
	{ page = "timing", text = "TIMING", box = Art.notes.label },
}
for _, entry in ipairs(labels) do
	local label = slot("EvalLabel", entry.box, entry.text)
	if label then
		cutouts[#cutouts+1] = Def.ActorFrame{
			InitCommand=function(self) self:visible(false) self.page = PAGES[1] end,
			VOLT26EvaluationPageMessageCommand=function(self, params)
				if params.Side ~= side then return end
				local shown = PAGES[(params.Page or 0) + 1] or PAGES[1]
				local was = self.page
				self.page = shown
				local mine = { [entry.page] = self }
				-- Only its own page matters: from or to it, it turns; otherwise
				-- it stays hidden.
				local old = was == entry.page and entry.page or "other"
				local new = shown == entry.page and entry.page or "other"
				if old == new then self:visible(new == entry.page) return end
				turnPage(mine, old, new, params.Direction, M.pageSlide * S)
			end,
			PageGoneCommand=function(self) self:visible(false):x(0):diffusealpha(1) end,
			OffCommand=function(self) self:finishtweening():linear(0.12):diffusealpha(0) end,
			label,
		}
	end
end

return { art = art, cutouts = cutouts }
