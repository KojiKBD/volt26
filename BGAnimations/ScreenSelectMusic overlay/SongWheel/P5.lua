-- Presentation kit of the song select drawn after the owner's Persona-style
-- mockup: the artwork pieces, the condensed Helvetica of the song rows, and
-- the meter badge (the mockup's "12": the first digit black in a white box,
-- the rest white and outlined, with a hard shadow).
--
-- Used by the song wheel overlay (this folder), its background
-- (ScreenSelectMusic background.lua) and the wheel rows
-- (Graphics/VOLT26/SongWheel/Row.lua).  Owns no behaviour: what to show comes
-- from the engine through the callers.
--
-- Usage: local P = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/P5.lua"))

local P = {}

-- Where every piece of the mockup sits (generated, see Art.lua).
P.Art = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/Art.lua"))

-- The design scale (the 1920x1080 mockup to the theme's screen), as in the
-- music kit's K.Scale.
P.Scale = math.min(_screen.w / 1920, _screen.h / 1080)

-- Colours sampled from the mockup.
P.Red    = color("#e40001")   -- the ground
P.Flag   = color("#fe0003")   -- the focused row's band and flags, P1's square
P.Blue   = color("#00b1ff")   -- P2's square
P.White  = color("#ffffff")
P.Black  = color("#000000")
P.Body   = color("#0b0b0b")   -- the info panel
P.Cyan   = color("#00fffc")   -- white seen through P1's red (exclusion)
P.Orange = color("#ff4e00")   -- white seen through P2's blue (exclusion)
P.Gold   = { Lit=color("#F3A608"), Shade=color("#D38F00"), Seam=color("#823500") }
P.P1Star = { Lit=color("#ff2a2a"), Shade=color("#c40010"), Seam=color("#5a0006") }
P.P2Star = { Lit=color("#38b8ff"), Shade=color("#0086d6"), Seam=color("#00365a") }

-- Idle motion (light breathing, stars turning, the logo rocking) is left out
-- in Performance mode; entrances and the kicks on a new song always play.
function P.IdleMotion()
	return not (VOLT26.Performance and VOLT26.Performance.IsEnabled())
end

function P.PlayerColor(player)
	return player == PLAYER_2 and P.Blue or P.Flag
end

-- Pieces ------------------------------------------------------------------

function P.PiecePath(name)
	local piece = P.Art.Pieces[name]
	return THEME:GetPathG("", "VOLT26/SongSelect/" .. piece.File)
end

-- A sprite of piece `name` where the mockup has it, less (ox, oy): pass the
-- position of the frame it is placed in.
function P.Piece(name, ox, oy, extra)
	local piece = P.Art.Pieces[name]
	local def = Def.Sprite{
		Name = name,
		Texture = P.PiecePath(name),
		InitCommand = function(self)
			self:xy(piece.X - (ox or 0), piece.Y - (oy or 0)):zoom(piece.Zoom or 1)
		end,
	}
	if extra then for k, v in pairs(extra) do def[k] = v end end
	return def
end

-- Text --------------------------------------------------------------------
--
-- The mockup sets the rows in Helvetica Now Display Medium squeezed to 70 %
-- of its width.  The theme's Helvetica bitmap font has a cap height of
-- FontCap pixels at zoom 1, so a cap height in design pixels becomes a zoom.
P.Font = "Helvetica Normal"
P.FontCap = 26

-- t = {Name, Cap, Condense, Tint, Align (0..1), X, Baseline, Rot, Width}
function P.Text(t)
	return Def.BitmapText{
		Name = t.Name,
		Font = t.Font or P.Font,
		InitCommand = function(self)
			local cap, condense = t.Cap or 20, t.Condense or 0.7
			local zoom = cap / P.FontCap
			-- Kept for P.FitText.
			self.p5 = { Cap = cap, Condense = condense, X = t.X or 0, Baseline = t.Baseline or 0 }
			-- Centred on the caps: half a cap height above the baseline.
			self:halign(t.Align or 0):valign(0.5):shadowlength(0)
				:xy(t.X or 0, (t.Baseline or 0) - cap / 2)
				:zoomx(zoom * condense):zoomy(zoom)
				:rotationz(t.Rot or 0):diffuse(t.Tint or P.White)
			if t.Width then self:maxwidth(t.Width / (zoom * condense)) end
			if t.Text then self:settext(t.Text) end
		end,
	}
end

-- Long words ------------------------------------------------------------------

-- Sets `text` on a P.Text actor and shrinks it, whole, to fit `width`, but no
-- further than `minScale` of its size; past that it is left long.  Answers
-- how far it still overflows (0 when it fits).  `squeeze` then narrows what
-- is left to the width instead, for places with no room to scroll.
function P.FitText(actor, text, width, minScale, squeeze)
	local m = actor.p5
	local base = m.Cap / P.FontCap
	actor:maxwidth(0):settext(text or "")
	local natural = actor:GetWidth() * base * m.Condense
	local scale = 1
	if natural > width and natural > 0 then scale = math.max(minScale or 1, width / natural) end
	actor:zoomx(base * m.Condense * scale):zoomy(base * scale)
		:y(m.Baseline - m.Cap * scale / 2)
	local overflow = math.max(0, natural * scale - width)
	if squeeze and overflow > 0 then
		actor:maxwidth(width / (base * m.Condense * scale))
		overflow = 0
	end
	return overflow, math.min(width, natural * scale)
end

-- Shortens `text` with an ellipsis until it fits `width` at minScale (the
-- artist of a wheel row, so the BPM beside it always shows whole).  Answers
-- the drawn width.
function P.FitEllipsis(actor, text, width, minScale)
	text = text or ""
	local overflow, drawn = P.FitText(actor, text, width, minScale)
	if overflow <= 0 then return drawn end
	local chars = {}
	for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars+1] = ch end
	local keep = #chars
	while keep > 1 and overflow > 0 do
		keep = keep - 1
		local cut = table.concat(chars, "", 1, keep):gsub("%s+$", "") .. "..."
		overflow, drawn = P.FitText(actor, cut, width, minScale)
	end
	return drawn
end

-- A line of text that scrolls when it is too long for its window: the text
-- shrinks to fit down to MinScale first, and only what still overflows
-- scrolls, to and fro, inside the window.  The text is drawn into its own
-- small texture (an ActorFrameTexture as large as the widest window) and
-- shown through a sprite cropped to the window, so nothing can show outside
-- it.  (Z-buffer masks did not cut it in ITGmania.)
-- t = P.Text's fields plus Width (the widest window), MinScale.
-- P.SetMarquee(frame, text[, window]) fills it.
local MARQUEE_SPEED = 90       -- design pixels a second
local MARQUEE_REST = 1.4       -- seconds at either end
local marquees = 0

function P.Marquee(t)
	marquees = marquees + 1
	local cap = t.Cap or 20
	local width = t.Width
	local height = math.ceil(cap * 2.4)
	-- Draw at the display's resolution, so the sprite maps onto its pixels.
	local display = 1
	if DISPLAY and DISPLAY.GetDisplayHeight then
		display = math.min(3, math.max(1, DISPLAY:GetDisplayHeight() / SCREEN_HEIGHT))
	end
	local s = P.Scale * display
	local texW, texH = math.ceil(width * s), math.ceil(height * s)
	local name = ("VOLT26Marquee%s%d_%d"):format(t.Name or "", marquees, math.floor(GetTimeSinceStart() * 1000))
	local text = {}
	for k, v in pairs(t) do text[k] = v end
	text.Name, text.Width, text.X, text.Rot = "Text", nil, 0, 0
	text.Baseline = height / 2 + cap / 2
	local aft
	return Def.ActorFrame{
		Name = t.Name,
		InitCommand = function(self) self.window, self.minScale, self.full = width, t.MinScale or 0.8, width end,
		Def.ActorFrameTexture{
			Name = "Texture",
			InitCommand = function(self)
				aft = self
				self:setsize(texW, texH):SetTextureName(name)
				self:EnableAlphaBuffer(true):EnablePreserveTexture(false):Create()
			end,
			FreezeCommand = function(self) self:hibernate(1e9) end,
			Def.ActorFrame{
				Name = "Zoom",
				InitCommand = function(self) self:zoom(s) end,
				P.Text(text)..{
					MarqueeCommand = function(self)
						local over = self.overflow or 0
						if over <= 0 then return end
						self:x(0):sleep(MARQUEE_REST):linear(over / MARQUEE_SPEED):x(-over)
							:sleep(MARQUEE_REST):linear(0.12):diffusealpha(0):x(0)
							:linear(0.12):diffusealpha(1):queuecommand("Marquee")
					end,
				},
			},
		},
		Def.Sprite{
			Name = "View",
			InitCommand = function(self)
				self:SetTexture(aft:GetTexture())
				self:align(0, 0.5):xy(t.X or 0, (t.Baseline or 0) - cap / 2)
					:zoom(1 / s):rotationz(t.Rot or 0)
			end,
		},
	}
end

-- The text actor of a marquee (for colour attributes and the like).
function P.MarqueeText(frame)
	return frame:GetChild("Texture"):GetChild("Zoom"):GetChild("Text")
end

-- Answers the drawn width (at most the window).
function P.SetMarquee(frame, text, window)
	local actor = P.MarqueeText(frame)
	window = math.min(window or frame.window, frame.full)
	local overflow, drawn = P.FitText(actor, text, window, frame.minScale)
	actor:stoptweening():x(0):diffusealpha(1)
	actor.overflow = overflow
	if overflow > 0 then actor:queuecommand("Marquee") end
	-- The texture is redrawn every frame only while the text scrolls; a text
	-- that fits is drawn for a moment and then kept (a hibernating
	-- ActorFrameTexture is not drawn, so its texture keeps its picture).
	local texture = frame:GetChild("Texture")
	texture:stoptweening():hibernate(0)
	if overflow <= 0 then texture:sleep(0.25):queuecommand("Freeze") end
	-- The sprite shows only the window.
	frame:GetChild("View"):cropright(1 - window / frame.full)
	return drawn
end

-- Meter badge ----------------------------------------------------------------
--
-- Built from two strips of digit cells (Graphics/VOLT26/SongSelect/Digits *),
-- each split into its black and its white ink so a palette can recolour them:
-- a chosen difficulty shows its badge as if seen through the player's square
-- (white turns cyan under P1's red, orange under P2's blue).
local digits = P.Art.Digits
local MAX_DIGITS = 3
-- How far each digit tucks under the one before it, in cell pixels, and how
-- large the plain digits stand beside the boxed one (as in the mockup, a
-- little shorter than the box with its shadow).
local TUCK_AFTER_BOX = 22
local TUCK_PLAIN = 8
local PLAIN_SCALE = 0.86

P.Ink = {
	Plain = { Black=P.Black, White=P.White },
	P1Box = { Black=P.Flag, White=P.Cyan },
	P1    = { Black=P.Black, White=P.Cyan },
	P2Box = { Black=P.Blue, White=P.Orange },
	P2    = { Black=P.Black, White=P.Orange },
}

local function digitPath(kind, ink)
	return THEME:GetPathG("", ("VOLT26/SongSelect/Digits %s %s 10x1.png"):format(kind, ink))
end

-- An empty badge; P.SetBadge fills it.  t = {Name, X, Y, Zoom, Rot}
function P.Badge(t)
	local af = Def.ActorFrame{
		Name = t.Name or "Badge",
		InitCommand = function(self)
			self:xy(t.X or 0, t.Y or 0):zoom(t.Zoom or 1):rotationz(t.Rot or 0)
		end,
	}
	for i = 1, MAX_DIGITS do
		local kind = i == 1 and "boxed" or "plain"
		af[#af+1] = Def.ActorFrame{
			Name = "Digit" .. i,
			Def.Sprite{ Name="Black", Texture=digitPath(kind, "black"),
				InitCommand=function(self) self:animate(false):setstate(0) end },
			Def.Sprite{ Name="White", Texture=digitPath(kind, "white"),
				InitCommand=function(self) self:animate(false):setstate(0) end },
		}
	end
	return af
end

-- Shows `value` (a number or a string of digits) on a badge.  boxInk colours
-- the boxed first digit, plainInk the rest (P.Ink entries; default Plain).
function P.SetBadge(badge, value, boxInk, plainInk)
	local text = tostring(value or ""):gsub("[^0-9]", ""):sub(1, MAX_DIGITS)
	badge:visible(text ~= "")
	if text == "" then return end
	boxInk, plainInk = boxInk or P.Ink.Plain, plainInk or P.Ink.Plain

	-- Lay the digits out left to right by their ink, then centre the row.
	local placed, cursor = {}, 0
	for i = 1, #text do
		local d = tonumber(text:sub(i, i))
		local strip = i == 1 and digits.Boxed or digits.Plain
		local scale = i == 1 and 1 or PLAIN_SCALE
		local ink = strip.Ink[d + 1]
		if i == 2 then cursor = cursor - TUCK_AFTER_BOX elseif i > 2 then cursor = cursor - TUCK_PLAIN end
		placed[i] = { d=d, scale=scale, x=cursor + (strip.CellW / 2 - ink[1]) * scale }
		cursor = cursor + (ink[2] - ink[1]) * scale
	end
	for i = 1, MAX_DIGITS do
		local slot = badge:GetChild("Digit" .. i)
		local p = placed[i]
		slot:visible(p ~= nil)
		if p then
			local ink = i == 1 and boxInk or plainInk
			-- Each digit's outline overlaps the one before it, as in the mockup.
			slot:x(p.x - cursor / 2):zoom(p.scale):draworder(i)
			slot:GetChild("Black"):setstate(p.d):diffuse(ink.Black)
			slot:GetChild("White"):setstate(p.d):diffuse(ink.White)
		end
	end
	badge:SortByDrawOrder()
end

-- Song facts the rows and the focused row share ------------------------------

local function rate()
	return VOLT26.MusicSelection.GetMusicRate()
end

function P.BPMText(item)
	if not item then return "" end
	local ok, random = pcall(function() return item.IsDisplayBpmRandom and item:IsDisplayBpmRandom() end)
	if ok and random then return "??? BPM" end
	local okBpms, bpms = pcall(function() return item:GetDisplayBpms() end)
	if not okBpms or type(bpms) ~= "table" or not tonumber(bpms[1]) or not tonumber(bpms[2]) then return "" end
	local low = math.floor(bpms[1] * rate() + 0.5)
	local high = math.floor(bpms[2] * rate() + 0.5)
	if low <= 0 and high <= 0 then return "" end
	if low == high then return low .. " BPM" end
	return ("%d-%d BPM"):format(low, high)
end

-- "ARTIST - BPM" of the mockup, as its two parts: the artist, and the BPM
-- with its separator (" - 180 BPM").  The BPM always shows whole; a long
-- artist gives way.
function P.ArtistParts(song)
	if not song then return "", "" end
	local artist = song.GetDisplayArtist and song:GetDisplayArtist() or ""
	local bpm = P.BPMText(song)
	if artist ~= "" and bpm ~= "" then return artist, " - " .. bpm end
	return artist, bpm
end

-- A wheel row's artist line: the whole line (artist and BPM together) first
-- shrinks to fit, down to minScale; if it is still too long, the artist is
-- shortened with an ellipsis at that size.  The BPM always shows whole.
function P.SetArtistLineShrink(x0, artistActor, bpmActor, artist, bpm, width, minScale)
	local _, a = P.FitText(artistActor, artist, 1e6, 1)
	local _, b = P.FitText(bpmActor, bpm, 1e6, 1)
	local scale = 1
	if a + b > width and a + b > 0 then scale = math.max(minScale, width / (a + b)) end
	P.FitText(bpmActor, bpm, b * scale + 0.5, scale)
	local room = math.max(0, width - b * scale)
	local drawn = artist ~= "" and P.FitEllipsis(artistActor, artist, room, scale) or 0
	if artist == "" then artistActor:settext("") end
	bpmActor:x(x0 + drawn)
end

-- Places an artist and its BPM on one line of `width` starting at x0: the
-- BPM is measured first and keeps its full size; the artist takes what is
-- left (fit = function(text, room) -> drawn width).
function P.SetArtistLine(x0, bpmActor, artist, bpm, width, fit)
	local _, bpmW = P.FitText(bpmActor, bpm, width, 1)
	local room = math.max(0, width - bpmW)
	local drawn = fit(artist, room)
	bpmActor:x(x0 + drawn)
end

-- The highest meter among the charts the current style can play: the "RANK"
-- of a row.  Kept per song, since rows ask on every scroll step.
local topMeters = setmetatable({}, { __mode = "k" })
function P.TopMeter(song)
	if not song then return nil end
	local cached = topMeters[song]
	if cached ~= nil then return cached or nil end
	local top = nil
	local ok, steps = pcall(function()
		if SongUtil and SongUtil.GetPlayableSteps then return SongUtil.GetPlayableSteps(song) end
		local style = GAMESTATE:GetCurrentStyle()
		return song:GetStepsByStepsType(style:GetStepsType())
	end)
	if ok and type(steps) == "table" then
		for _, chart in ipairs(steps) do
			local meter = tonumber(chart:GetMeter())
			if meter and (not top or meter > top) then top = meter end
		end
	end
	topMeters[song] = top and math.floor(top + 0.5) or false
	return top and math.floor(top + 0.5) or nil
end

-- Cutout lettering (player names, the pack, the song length, PACK
-- SELECTION) ------------------------------------------------------------------
--
-- VOLT26.Cutout draws a string only while every ancestor of its slot is
-- visible, opaque and still, and an ActorFrame counts the tweens of all its
-- descendants as its own.  The song select's overlay always has one running
-- somewhere (the leaderboard's looping bounce, among others), so a slot in it
-- never draws.  The slots therefore live in the screen's background
-- (P.CutoutHost, loaded by ScreenSelectMusic background.lua, off screen),
-- and the overlay and the wheel rows show them through ActorProxies
-- (P.CutoutSlot).  The two find each other by message.
--
-- Every slot is declared here once, by id, in design pixels.  The pack and the
-- player names take their size from VOLT26.Cutout.StyleDesign
-- (Scripts/VOLT26_CutoutStyles.lua), where the startup warm-up reads it too,
-- so the strings it pre-renders are the ones these slots ask for.
local function shared(name, halign)
	local d = VOLT26.Cutout.StyleDesign[name]
	return { MaxW=d.MaxW, MaxH=d.MaxH, Base=d.Base, Tilt=d.Tilt, HAlign=halign, MaxChars=d.MaxChars, Opts=d.Opts }
end
P.CutoutSpecs = {
	Card1Name = shared("SongCardName", 0.5),
	Card2Name = shared("SongCardName", 0.5),
	FooterP1  = shared("SongFooterName", 1),
	FooterP2  = shared("SongFooterName", 1),
	Pack      = shared("SongPack", 0.5),
	-- The focused song's grade (Grade.lua): white with one player, in each
	-- player's colour with two.
	Grade     = shared("SongGrade", 0.5),
	GradeP1   = shared("SongGradeP1", 0.5),
	GradeP2   = shared("SongGradeP2", 0.5),
	Length    = { MaxW=170, MaxH=62, Base=46, Tilt=-7, HAlign=1, MaxChars=8 },
	BackLabel = { MaxW=440, MaxH=96, Base=50, Tilt=-2, HAlign=0, MaxChars=32 },
}

local function cutoutOpts(spec, s)
	local opts = { base = spec.Base * s, tiltDeg = spec.Tilt or -3 }
	if spec.Opts then for k, v in pairs(spec.Opts) do opts[k] = v end end
	return opts
end

-- The width a string takes in a slot, in design pixels (the slot shrinks a
-- string to fit MaxW x MaxH).
function P.CutoutWidth(id, text, s)
	local spec = P.CutoutSpecs[id]
	if not spec or not text or text == "" then return 0 end
	local ok, layout = pcall(function() return VOLT26.Cutout.Layout(text, cutoutOpts(spec, s)) end)
	if not ok or not layout then return spec.MaxW end
	local b = layout.bounds
	local w, h = b[3] - b[1], b[4] - b[2]
	if w <= 0 or h <= 0 then return 0 end
	return w * math.min(1, spec.MaxW * s / w, spec.MaxH * s / h) / s
end

-- The slots themselves, for the background.  `s` is the design scale of the
-- frame the host is placed in.
function P.CutoutHost(s)
	local slots = {}
	local function announce()
		MESSAGEMAN:Broadcast("VOLT26SongCutoutHost", { Slots = slots })
	end
	local host = Def.ActorFrame{
		Name = "CutoutHost",
		-- Off screen: the slots must be drawn to render, but are seen only
		-- through the proxies.
		InitCommand = function(self) self:xy(-4000, 0):zoom(1 / s) end,
		OnCommand = function(self) announce() end,
		VOLT26SongCutoutQueryMessageCommand = function(self) announce() end,
	}
	for id, spec in pairs(P.CutoutSpecs) do
		host[#host+1] = VOLT26.Cutout.CreateSlot{
			x = 0, y = 0,
			maxW = spec.MaxW * s, maxH = spec.MaxH * s,
			halign = spec.HAlign or 0, valign = spec.VAlign or 0.5,
			maxChars = spec.MaxChars or 16,
			opts = cutoutOpts(spec, s),
			onInit = function(slot) slots[id] = slot end,
		}..{
			VOLT26SongCutoutSetMessageCommand = function(self, p)
				if p.Id == id then self:playcommand("CutoutSet", { text = p.Text }) end
			end,
		}
	end
	return host
end

-- Where a slot shows: t = {Name, Id, X, Y, Scale}.  The slot's own alignment
-- (CutoutSpecs) decides which edge of the lettering sits on X, Y.
function P.CutoutSlot(t)
	local s = t.Scale
	return Def.ActorFrame{
		Name = t.Name,
		InitCommand = function(self)
			self.id, self.text = t.Id, nil
			self:xy(t.X, t.Y):zoom(1 / s)
		end,
		OnCommand = function(self)
			if not self.bound then MESSAGEMAN:Broadcast("VOLT26SongCutoutQuery") end
		end,
		VOLT26SongCutoutHostMessageCommand = function(self, p)
			local slot = p.Slots and p.Slots[t.Id]
			if not slot or self.bound then return end
			self.bound = true
			self:GetChild("Proxy"):SetTarget(slot)
			-- A string set before the host was found.
			if self.text then
				MESSAGEMAN:Broadcast("VOLT26SongCutoutSet", { Id = t.Id, Text = self.text })
			end
		end,
		Def.ActorProxy{ Name = "Proxy" },
	}
end

function P.SetCutout(frame, text)
	text = text or ""
	if frame.text == text then return end
	frame.text = text
	MESSAGEMAN:Broadcast("VOLT26SongCutoutSet", { Id = frame.id, Text = text })
end

-- Density graphs -------------------------------------------------------------
--
-- The NPS of every measure as a filled profile, sampled to a fixed width so a
-- short chart and a long one read the same way.  Drawn by an
-- ActorMultiVertex in DrawMode_QuadStrip from its bottom-left corner.
local DENSITY_SAMPLES = 96

function P.DensityVertices(data, w, h, colour)
	local vertices = {}
	if not data or #data.nps == 0 or data.peak <= 0 then return vertices end
	local count = #data.nps
	local tint = { colour[1], colour[2], colour[3], 1 }
	for sample = 0, DENSITY_SAMPLES do
		local position = sample / DENSITY_SAMPLES
		local index = math.min(count, math.max(1, math.floor(position * (count - 1)) + 1))
		local value = data.nps[index] or 0
		local x = position * w
		vertices[#vertices+1] = { {x, 0, 0}, tint }
		vertices[#vertices+1] = { {x, -math.min(h, h * value / data.peak), 0}, tint }
	end
	return vertices
end

function P.SetVertices(actor, vertices)
	actor:SetNumVertices(#vertices)
	if #vertices > 0 then actor:SetVertices(vertices) end
end

-- Grades ---------------------------------------------------------------------

local gradeStars = { Grade_Tier00 = 5, Grade_Tier01 = 4, Grade_Tier02 = 3, Grade_Tier03 = 2, Grade_Tier04 = 1 }
local gradeLetters = {
	Grade_Tier05 = "s-plus.png", Grade_Tier06 = "s.png", Grade_Tier07 = "s-minus.png",
	Grade_Tier08 = "a-plus.png", Grade_Tier09 = "a.png", Grade_Tier10 = "a-minus.png",
	Grade_Tier11 = "b-plus.png", Grade_Tier12 = "b.png", Grade_Tier13 = "b-minus.png",
	Grade_Tier14 = "c-plus.png", Grade_Tier15 = "c.png", Grade_Tier16 = "c-minus.png",
	Grade_Tier17 = "d.png", Grade_Tier99 = "q.png", Grade_Failed = "f.png",
}
P.GradeAssetSize = 200

-- Answers the grade's letter picture (a path) or its number of stars.
function P.Grade(grade)
	if not grade then return nil, 0 end
	local file = gradeLetters[grade]
	if file then return THEME:GetPathG("", "_grades/assets/" .. file), 0 end
	return nil, gradeStars[grade] or 0
end
P.GradeStarPath = THEME:GetPathG("", "_grades/assets/star.png")

return P
