-- Shared presentation kit for the end-of-session screens, after the owner's
-- "gameover" artboard (tools/notes-radar/art/radar.svg): the session summary
-- (ScreenEvaluationSummary), the name entry (ScreenNameEntryTraditional) and
-- the game over profile data (ScreenGameOver).
--
-- The screen is split in two halves over the artboard's ground (the two
-- halves' art and the dark band between them): player 1 in the upper half,
-- player 2 in the lower one with the same layout mirrored -- the pictures and
-- the positions are mirrored, the writing is not.  With one player, that
-- player's half sits in the middle of the screen.
--
-- Every figure is an artboard pixel (1920x1080); G.Root scales the whole to
-- the theme's resolution.  The pictures and their positions come from
-- tools/gameover/build_gameover_art.py ("_volt26 gameover art.lua",
-- Graphics/VOLT26/GameOver).
--
-- Usage: local G = LoadActor(THEME:GetPathB("", "_volt26 gameover kit.lua"))

local G = {}
local K = LoadActor(THEME:GetPathB("", "_volt26 music kit.lua"))
local P = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/P5.lua"))
local Art = LoadActor(THEME:GetPathB("", "_volt26 gameover art.lua"))
G.K, G.P, G.Art = K, P, Art

-- The evaluation's bitmap stand-ins for the artwork's Helvetica Now Display
-- (tools/evaluation/build_fonts.py), as on the song select's cards.
G.Font = { Label = "VOLT26 Eval Label", Bold = "VOLT26 Eval Bold", Score = "VOLT26 Eval Score" }
local EM = { Label = 48, Bold = 48, Score = 96 }
local CAP = 68 / 96          -- cap height of the Score face, per em
G.Pink, G.Cyan = color("#f580eb"), color("#64e7c8")
G.White, G.Black = color("#ffffff"), color("#000000")
G.Navy = color("#0b1626")

local C1 = Art.Card.P1        -- player 1's card centre on the artboard
G.Step = Art.Card.Step        -- from one card to the next in a row

local function file(name) return THEME:GetPathG("", "VOLT26/GameOver/" .. name .. ".png") end
local FILES = {
	Bands = "bands", Rank = "rank", JacketFrame = "jacket_frame",
	ScorePlate = "score_plate", ItgLine = "underline_itg", ExLine = "underline_ex",
}

-- Layout ------------------------------------------------------------------

function G.Players()
	return GAMESTATE:GetHumanPlayers()
end

-- Where a player's half is: the centre of its card and whether it is
-- mirrored (player 2's).  `solo` (one player) puts the half in the middle.
function G.Anchor(player, solo)
	local mirror = player == PLAYER_2
	local c = mirror and Art.Card.P2 or Art.Card.P1
	local y = c.Y
	if solo then y = 540 + (c.Y - (mirror and Art.Card.P2.Y or Art.Card.P1.Y)) end
	return { X = c.X, Y = y, M = mirror and -1 or 1 }
end

-- A point of player 1's card in the card's own frame, mirrored with m = -1.
function G.At(x, y, m)
	return (x - C1.X) * (m or 1), y - C1.Y
end

-- The root: design pixels scaled to the theme.
function G.Root(t)
	t = t or {}
	t.InitCommand = function(self) self:xy(K.Left, K.Top):zoom(K.Scale) end
	return Def.ActorFrame(t)
end

-- The ground: the artboard's navy, both halves' art and the band.  With one
-- player a darker panel runs across the middle, where that player's half is.
function G.Background(solo)
	return G.Root{
		Name = "GameOverGround",
		Def.Sprite{
			Texture = file("background"),
			InitCommand = function(self) self:xy(960, 540) end,
		},
		Def.Quad{
			InitCommand = function(self)
				self:xy(960, 540):zoomto(1920, 560):diffuse(G.Navy):diffusealpha(solo and 0.82 or 0)
			end,
		},
	}
end

-- A picture of the card at its place (mirrored pictures for m = -1, except
-- `upright` ones, like RANK, which must still read).
function G.Piece(name, m, upright)
	local a = Art.Pieces[name]
	return Def.Sprite{
		Name = name,
		Texture = file(FILES[name]),
		InitCommand = function(self)
			self:xy(G.At(a.X, a.Y, m))
			if not upright then self:zoomx(m) end
		end,
	}
end

-- Text --------------------------------------------------------------------

-- A run of text pieces set side by side from a baseline: segs =
-- {{name, cap, colour, text, face}}, in `face` (default the Score face, which
-- has digits and few letters) unless a piece names its own.  The frame's `layout`
-- re-places them after a settext.
local function run(name, segs, face)
	face = face or "Score"
	local frame = Def.ActorFrame{
		Name = name,
		InitCommand = function(self)
			self.layout = function()
				local x = 0
				for _, seg in ipairs(segs) do
					local child = self:GetChild(seg[1])
					child:x(x)
					x = x + child:GetZoomedWidth()
				end
				self.width = x
			end
		end,
	}
	for _, seg in ipairs(segs) do
		local f = seg[5] or face
		frame[#frame+1] = LoadFont(G.Font[f])..{
			Name = seg[1],
			InitCommand = function(self)
				local cap = f == "Score" and CAP or 0.72
				self:halign(0):valign(1):zoom(seg[2] / cap / EM[f]):diffuse(seg[3] or G.White)
				if seg[4] then self:settext(seg[4]) end
			end,
		}
	end
	return frame
end
G.Run = run

-- A score line of the card ("ITG 99.53/100"): tag, value and tail in one
-- colour, on the artboard's slope.  spec = Art.Itg or Art.Ex; `width` is
-- about how long the drawn line is, so a mirrored line starts where the
-- drawn one ended.
local LINE_WIDTH = { Itg = 138, Ex = 136 }
function G.ScoreLine(key, tag, tint, m, tagCap)
	local spec = Art[key]
	local r = math.rad(spec.Rot)
	local x, y, rot = spec.X, spec.Y, spec.Rot
	if m < 0 then
		local w = LINE_WIDTH[key] or 136
		x, y, rot = spec.X + w * math.cos(r), spec.Y + w * math.sin(r), -spec.Rot
	end
	local lx, ly = G.At(x, y, m)
	local line = run(key, {
		{ "Tag", tagCap or spec.TagCap, tint, tag .. " ", "Bold" },
		{ "Value", spec.Cap, tint, "--" },
		{ "Tail", spec.TailCap, tint, "/100" },
	})
	local init = line.InitCommand
	line.InitCommand = function(self)
		init(self)
		self:xy(lx, ly):rotationz(rot)
		self.layout()
	end
	return line
end

function G.SetLine(line, value, tail)
	line:GetChild("Value"):settext(value or K.Dash)
	if tail then line:GetChild("Tail"):settext(tail) end
	line.layout()
end

-- Cutout lettering ----------------------------------------------------------

-- A cutout slot of a VOLT26.Cutout style, at (x, y) of the card frame.  The
-- slot works in theme units (its size is the style's, so strings the startup
-- warm-up drew are found in the cache), hence the counter-zoom.
function G.Slot(name, styleName, x, y, halign, m)
	local style = VOLT26.Cutout.Style(styleName)
	local opts = {}
	for k, v in pairs(style.opts) do opts[k] = v end
	if m < 0 and opts.tiltDeg then opts.tiltDeg = -opts.tiltDeg end
	return Def.ActorFrame{
		Name = name,
		InitCommand = function(self) self:xy(x, y):zoom(1 / K.Scale) end,
		VOLT26.Cutout.CreateSlot{
			maxW = style.maxW, maxH = style.maxH, maxChars = style.maxChars,
			halign = halign or 0.5, valign = 0.5, opts = opts,
		}..{ Name = "Slot" },
	}
end

function G.SetSlot(frame, text)
	frame:GetChild("Slot"):playcommand("CutoutSet", { text = text or "" })
end

-- Grades ------------------------------------------------------------------

-- The star grades, laid out as the song wheel lays them out (overlay/
-- SongWheel/Grade.lua), in the 200 px units of the grade pictures.
local STARS = {
	[1] = { { 0, 0, 0.8 } },
	[2] = { { -39, 40, 0.6 }, { 39, -40, 0.6 } },
	[3] = { { -45, 40, 0.5 }, { 0, -40, 0.5 }, { 45, 40, 0.5 } },
	[4] = { { -46, -46, 0.5 }, { 46, -46, 0.5 }, { -46, 46, 0.5 }, { 46, 46, 0.5 } },
	[5] = { { 0, -54, 0.35 }, { -52, -16, 0.35 }, { 52, -16, 0.35 }, { -32, 50, 0.35 }, { 32, 50, 0.35 } },
}
local STAR_SCALE = 0.85

-- The grade spot: a cutout letter (style EvalGrade, drawn at startup) or the
-- stars, about the artboard's grade picture.
function G.Grade(m)
	local x, y = G.At(Art.Grade.X, Art.Grade.Y, m)
	local stars = Def.ActorFrame{ Name = "Stars" }
	for i = 1, 5 do
		stars[#stars+1] = Def.Sprite{
			Name = "Star" .. i, Texture = P.GradeStarPath,
			InitCommand = function(self) self:visible(false) end,
		}
	end
	return Def.ActorFrame{
		Name = "Grade",
		InitCommand = function(self) self:xy(x, y) end,
		stars,
		G.Slot("Letter", "EvalGrade", 0, 0, 0.5, m),
	}
end

-- Shows `grade` (a Grade_* name) on a G.Grade frame; nil hides it.
function G.SetGrade(frame, grade)
	local letter = grade and VOLT26.Cutout.GradeLetters[grade] or nil
	local _, count = P.Grade(grade)
	frame:GetChild("Letter"):visible(letter ~= nil)
	if letter then G.SetSlot(frame:GetChild("Letter"), letter) end
	local stars = frame:GetChild("Stars")
	for i = 1, 5 do
		local star = stars:GetChild("Star" .. i)
		local at = (not letter) and STARS[count] and STARS[count][i]
		star:visible(at and true or false)
		if at then
			star:xy(at[1] * STAR_SCALE, at[2] * STAR_SCALE):zoom(at[3] * STAR_SCALE)
			if count == 5 then
				star:rainbow():effectperiod(2.4):effectoffset((i - 1) * 0.34)
			else
				star:stopeffect():diffuse(G.White)
			end
		end
	end
end

-- The card ---------------------------------------------------------------

-- The jacket's upright box inside the slanted frame (jackets are never
-- turned, .agents/presentation.md).
local JACKET = { W = 198, H = 190 }
do
	local cx, cy = 0, 0
	for _, c in ipairs(Art.Jacket.Corners) do cx, cy = cx + c[1] / 4, cy + c[2] / 4 end
	JACKET.X, JACKET.Y = cx, cy
end

local NAME_X = Art.Name.Box[1] + 2
local NAME_Y = (Art.Pieces.Bands.Y - Art.Pieces.Bands.H / 2) + 35
local TITLE = { X = Art.Title.Box[1] + 4, Baseline = 185, Cap = 30, Width = 380 }

-- One card: the bands (the player's name in cutout lettering on the black,
-- `title` on the white), RANK and the meter, the jacket in its frame, the
-- grade and the ITG / EX plate.  parts = {Rank=false, Scores=false} leaves
-- those out; parts.TagA / TagB rename the plate's lines.  Fill it with G.FillCard or by hand (children by name).
function G.Card(name, m, parts)
	parts = parts or {}
	local card = Def.ActorFrame{ Name = name }
	card[#card+1] = G.Piece("Bands", m)
	if parts.Rank ~= false then
		card[#card+1] = G.Piece("Rank", m, true)
		local bx, by = G.At(Art.Badge.X, Art.Badge.Y, m)
		card[#card+1] = P.Badge{ Name = "Badge", X = bx, Y = by, Zoom = 0.52, Rot = 5 * m }
	end
	local tx = select(1, G.At(TITLE.X, 0, m))
	card[#card+1] = P.Text{ Name = "Title", Cap = TITLE.Cap, X = tx, Baseline = select(2, G.At(0, TITLE.Baseline, m)),
		Align = m < 0 and 1 or 0, Tint = G.Black, Width = TITLE.Width }
	local nx, ny = G.At(NAME_X, NAME_Y, m)
	card[#card+1] = G.Slot("Name", "SongCardName", nx, ny, m < 0 and 1 or 0, m)
	card[#card+1] = G.Piece("JacketFrame", m)
	local jx, jy = G.At(JACKET.X, JACKET.Y, m)
	card[#card+1] = Def.Sprite{ Name = "Jacket", InitCommand = function(self) self:xy(jx, jy):visible(false) end }
	card[#card+1] = LoadFont(G.Font.Bold)..{
		Name = "JacketText",
		InitCommand = function(self) self:xy(jx, jy):zoom(0.9):diffuse(G.White):maxwidth(JACKET.W / 0.9 - 20) end,
	}
	card[#card+1] = G.Grade(m)
	if parts.Scores ~= false then
		card[#card+1] = G.Piece("ScorePlate", m)
		card[#card+1] = G.Piece("ItgLine", m)
		card[#card+1] = G.Piece("ExLine", m)
		card[#card+1] = G.ScoreLine("Itg", parts.TagA or "ITG", G.Pink, m, parts.TagCap)
		card[#card+1] = G.ScoreLine("Ex", parts.TagB or "EX", G.Cyan, m, parts.TagCap)
	end
	return card
end

-- A picture in the card's jacket box: a path, else `fallback` written there.
function G.SetJacket(card, path, fallback)
	local art, text = card:GetChild("Jacket"), card:GetChild("JacketText")
	if path and K.LoadStill(art, path) then
		K.Cover(art, JACKET.W, JACKET.H)
		art:visible(true)
		text:settext("")
	else
		art:visible(false)
		text:settext(fallback or "")
	end
end

function G.SetTitle(card, text)
	P.FitText(card:GetChild("Title"), text or "", TITLE.Width, 0.7, true)
end

-- The name a player played a stage under: the profile's, else P1 / P2.
local function stageName(player, snapshot)
	local name = snapshot and snapshot.profile
	if not name or name == "" or name == "[GUEST]" then return ToEnumShortString(player) end
	return name
end

local function itemTitle(item)
	if not item then return "" end
	if item.GetCourseType then return item:GetDisplayFullTitle() end
	return item:GetDisplayMainTitle()
end

local function itemArt(item)
	if not item then return nil end
	if item.GetCourseType then return (K.CourseArt(item)) end
	return (K.SongArt(item))
end

local function percent(value)
	value = tonumber(value)
	if not value then return K.Dash end
	return ("%.2f"):format(value)
end

-- Fills a card with what `player` scored on stage `index` of the session.
-- Answers false (and hides the card) when the player has no score there
-- (joined later).
function G.FillCard(card, player, index)
	local snapshot = index and VOLT26.Evaluation.GetPlayerStageSnapshot(player, index)
	local stage = index and VOLT26.Evaluation.GetStageContext(index)
	local item = stage and (stage.item or stage.song)
	if not snapshot or not item then
		card:visible(false)
		return false
	end
	card:visible(true)
	G.SetSlot(card:GetChild("Name"), stageName(player, snapshot))
	G.SetTitle(card, itemTitle(item))
	local badge = card:GetChild("Badge")
	if badge then P.SetBadge(badge, snapshot.meter) end
	G.SetJacket(card, itemArt(item), K.Initials(itemTitle(item)))
	G.SetGrade(card:GetChild("Grade"), snapshot.grade)
	local itg, ex = card:GetChild("Itg"), card:GetChild("Ex")
	if itg then G.SetLine(itg, percent(snapshot.score and snapshot.score * 100)) end
	if ex then G.SetLine(ex, percent(snapshot.exscore)) end
	return true
end

-- Session data --------------------------------------------------------------

function G.StageCount()
	return VOLT26.Evaluation.GetStageCount()
end

-- The stages `player` has a score on, in the order they were played.
function G.PlayerStages(player)
	local list = {}
	for i = 1, G.StageCount() do
		if VOLT26.Evaluation.GetPlayerStageSnapshot(player, i) then list[#list+1] = i end
	end
	return list
end

-- The best grade `player` reached this session (the lowest tier), or nil.
function G.BestGrade(player)
	local best, bestTier
	for _, i in ipairs(G.PlayerStages(player)) do
		local s = VOLT26.Evaluation.GetPlayerStageSnapshot(player, i)
		local tier = s and s.grade and tonumber(tostring(s.grade):match("Tier(%d+)"))
		if tier and (not bestTier or tier < bestTier) then best, bestTier = s.grade, tier end
	end
	return best
end

-- A score plate of its own (the card's, with its two lines), centred at
-- (x, y) of player 1's artboard and zoomed: for the game over's figures.
-- Its lines are "Itg" (pink) and "Ex" (cyan), tagged tagA and tagB.
function G.Plate(name, m, x, y, zoom, tagA, tagB, tagCap)
	local plate = Art.Pieces.ScorePlate
	local ox, oy = G.At(x, y, m)
	local ix, iy = G.At(plate.X, plate.Y, m)
	return Def.ActorFrame{
		Name = name,
		InitCommand = function(self) self:xy(ox, oy):zoom(zoom or 1) end,
		Def.ActorFrame{
			Name = "Inner",
			InitCommand = function(self) self:xy(-ix, -iy) end,
			G.Piece("ScorePlate", m),
			G.Piece("ItgLine", m),
			G.Piece("ExLine", m),
			G.ScoreLine("Itg", tagA or "", G.Pink, m, tagCap),
			G.ScoreLine("Ex", tagB or "", G.Cyan, m, tagCap),
		},
	}
end

-- The lines of a G.Plate, and its underlines.
function G.PlateLines(plate)
	local inner = plate:GetChild("Inner")
	return inner:GetChild("Itg"), inner:GetChild("Ex"), inner:GetChild("ItgLine"), inner:GetChild("ExLine")
end

-- The screen's title in cutout lettering, on the band between the halves
-- (with one player, above the half).
function G.Title(text, solo)
	local y = solo and 150 or Art.Band.Y
	return Def.ActorFrame{
		Name = "Title",
		InitCommand = function(self) self:diffusealpha(0) end,
		OnCommand = function(self)
			self:sleep(0.25):linear(0.2):diffusealpha(1)
			G.SetSlot(self:GetChild("Text"), (text or ""):upper())
		end,
		OffCommand = function(self) self:stoptweening():linear(0.15):diffusealpha(0) end,
		G.Slot("Text", "GameOverTitle", 960, y, 0.5, 1),
	}
end

-- Motion ------------------------------------------------------------------

-- A half arriving: in from its own side (player 1 from the left, player 2
-- from the right), after `delay`.
function G.Arrive(self, m, delay)
	local x = self:GetX()
	self:addx(-700 * m):diffusealpha(0):sleep(delay or 0)
		:decelerate(0.32):x(x + 14 * m):diffusealpha(1):decelerate(0.08):x(x)
end

function G.Leave(self, m)
	self:stoptweening():accelerate(0.2):addx(-700 * m):diffusealpha(0)
end

return G
