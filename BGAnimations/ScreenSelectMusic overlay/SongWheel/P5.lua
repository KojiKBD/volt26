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

-- "ARTIST - BPM" of the mockup.
function P.ArtistLine(song)
	if not song then return "" end
	local artist = song.GetDisplayArtist and song:GetDisplayArtist() or ""
	local bpm = P.BPMText(song)
	if artist ~= "" and bpm ~= "" then return artist .. " - " .. bpm end
	return artist ~= "" and artist or bpm
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

-- Cutout lettering (player names, the song length) --------------------------
--
-- VOLT26.Cutout sizes its texture in screen units; the song select is drawn in
-- a frame scaled from the 1920x1080 design, so the slot stands in a frame that
-- undoes that scale and gets its figures converted.  t = {Name, X, Y, MaxW,
-- MaxH, Base, Tilt, HAlign, VAlign, MaxChars, Scale}
-- TEMPORARY (2026-10-12): the slots did not show in the first test in
-- ITGmania.  Until the cause is known, a slot that has not finished after two
-- seconds writes to the log which of its ancestors keeps it from drawing
-- (hidden, see-through or tweening: VOLT26.Cutout only draws a pass when all
-- of them are visible, opaque and still).
local function blocker(actor)
	while actor do
		local name = actor:GetName() or "?"
		if not actor:GetVisible() then return "hidden " .. name end
		if actor:GetDiffuseAlpha() < 1 then return ("alpha %.2f %s"):format(actor:GetDiffuseAlpha(), name) end
		if actor:GetTweenTimeLeft() > 0 then return ("tween %.2f %s"):format(actor:GetTweenTimeLeft(), name) end
		actor = actor:GetParent()
	end
	return "none"
end

function P.CutoutSlot(t)
	local s = t.Scale
	return Def.ActorFrame{
		Name = t.Name,
		InitCommand = function(self)
			self:xy(t.X, t.Y):zoom(1 / s)
			self.waited = 0
			self:SetUpdateFunction(function(frame, delta)
				if frame.ready or not frame.text then return end
				frame.waited = frame.waited + (delta or 0)
				if frame.waited < 2 then return end
				frame.waited = 0
				Trace(("[VOLT26 cutout] %s '%s' waiting, blocked by: %s"):format(
					t.Name or "?", frame.text, blocker(frame:GetChild("Slot"))))
			end)
		end,
		VOLT26.Cutout.CreateSlot{
			x = 0, y = 0,
			maxW = t.MaxW * s, maxH = t.MaxH * s,
			halign = t.HAlign or 0, valign = t.VAlign or 0.5,
			maxChars = t.MaxChars or 16,
			opts = { base = t.Base * s, tiltDeg = t.Tilt or -3 },
			onReady = function(slot)
				local frame = slot:GetParent()
				if frame and not frame.ready then
					frame.ready = true
					Trace(("[VOLT26 cutout] %s '%s' ready"):format(t.Name or "?", tostring(frame.text)))
				end
			end,
		}..{ Name = "Slot" },
	}
end

function P.SetCutout(frame, text)
	frame.text, frame.ready, frame.waited = text or "", false, 0
	frame:GetChild("Slot"):playcommand("CutoutSet", { text = text or "" })
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
