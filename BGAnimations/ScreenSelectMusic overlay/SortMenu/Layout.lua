-- VOLT26 SortMenu composition constants.
--
-- The menu is a dock: a single horizontal bar of square tiles pinned to the
-- bottom of the screen, and -- when a category is open -- a second bar of text
-- pills floating just above it.  Nothing else is drawn, so every figure below
-- describes either the bar, a tile or a pill.
--
-- Measurements are in a 1920x1080 design space whose origin is the centre of
-- the screen, uniformly scaled to whatever the engine's resolution is.  The
-- screen's own Layout.lua keeps its table local to its own children, so the
-- shared figures -- the palette, the faces -- are restated here rather than
-- reached for.

local L = {
	HalfW = 960,
	HalfH = 540,
	Dash  = "--",
	Dot   = "\226\128\162", -- a bullet, as the separator inside a pill's figure
}

-- Palette.  The greys match the song select screen exactly; the two reds are
-- the accent at full strength and the deep fill the focused tile washes with.
L.Bg      = color("#0a0a0c")
L.Panel   = color("#141417")
L.Panel2  = color("#1c1c21")
L.Line    = color("#26262c")
L.Ink     = color("#f2f0ec")
L.Mute    = color("#8a8a94")
L.Dim     = color("#5a5a64")
L.Accent  = color("#e03a2f")
L.Deep    = color("#3d1114")
L.Border  = color("#482426")

-- Typography.  Two faces, the same glyphs: the letter-spaced "VOLT26 Light
-- Label" for every uppercase label, and plain Helvetica Normal for names.  Both
-- share Helvetica's 26-unit cap height, so a design pixel size lands by
-- dividing by 26 rather than by guessing per screen.  Bitmap faces stop being
-- legible below a floor a hinted vector face would survive, so anything under
-- it is lifted.
L.Label   = "VOLT26 Light Label"
L.Display = "Helvetica Normal"

local capHeight = 26
local labelFloor = 11

function L.Zoom(px) return px/capHeight end
function L.LabelZoom(px) return math.max(px, labelFloor)/capHeight end

-- Uppercase that survives the accented characters the Italian, Spanish and
-- French strings actually use.  Lua's own upper() is byte-based and would
-- corrupt a multi-byte sequence, so the Latin-1 supplement is mapped explicitly
-- to its own capitals, and every other byte above ASCII is left alone.
local accents = {
	["à"]="À", ["á"]="Á", ["â"]="Â", ["ã"]="Ã", ["ä"]="Ä", ["å"]="Å",
	["è"]="È", ["é"]="É", ["ê"]="Ê", ["ë"]="Ë",
	["ì"]="Ì", ["í"]="Í", ["î"]="Î", ["ï"]="Ï",
	["ò"]="Ò", ["ó"]="Ó", ["ô"]="Ô", ["õ"]="Õ", ["ö"]="Ö",
	["ù"]="Ù", ["ú"]="Ú", ["û"]="Û", ["ü"]="Ü",
	["ñ"]="Ñ", ["ç"]="Ç", ["ý"]="Ý", ["æ"]="Æ", ["ø"]="Ø",
}

function L.Upper(text)
	text = tostring(text or "")
	text = text:gsub("[\194-\244][\128-\191]*", function(glyph)
		return accents[glyph] or glyph
	end)
	return (text:gsub("%l", string.upper))
end

function L.String(key)
	if THEME:HasString("ScreenSelectMusic", key) then
		return THEME:GetString("ScreenSelectMusic", key)
	end
	return key
end

-- Text factories.  Each takes the design's own figures -- {Name, Px, Tint,
-- Align, X, Y, Width} -- so a component reads the way the design does and the
-- shared defaults live in one place.
local function textActor(font, zoomFor, defaultTint)
	return function(t)
		return Def.BitmapText{
			Name=t.Name, Font=font,
			InitCommand=function(self)
				self:xy(t.X or 0, t.Y or 0)
					:horizalign(t.Align or center):vertalign(t.VAlign or middle)
					:shadowlength(0):zoom(zoomFor(t.Px)):diffuse(t.Tint or defaultTint)
				if t.Width then self:maxwidth(t.Width/zoomFor(t.Px)) end
				if t.Text then self:settext(t.Text) end
			end,
		}
	end
end

L.LabelText   = textActor(L.Label,   L.LabelZoom, L.Mute)
L.DisplayText = textActor(L.Display, L.Zoom,      L.Ink)

local function setText(actor, text, zoom, width)
	if not actor then return zoom end
	actor:settext(tostring(text or "")):zoom(zoom)
	if width then actor:maxwidth(width/zoom) end
	return zoom
end

function L.SetLabel(actor, text, px, width)
	return setText(actor, L.Upper(text), L.LabelZoom(px), width)
end

function L.SetDisplay(actor, text, px, width)
	return setText(actor, text, L.Zoom(px), width)
end

function L.Rule(t)
	return Def.Quad{
		Name=t.Name,
		InitCommand=function(self)
			self:align(t.AlignX or 0, t.AlignY or 0):xy(t.X or 0, t.Y or 0)
				:zoomto(t.Width or 1, t.Height or 1)
				:diffuse(t.Tint or L.Line):diffusealpha(t.Alpha or 1)
		end,
	}
end

function L.Fade(base, alpha)
	return {base[1], base[2], base[3], alpha}
end

-- A hairline box drawn as four quads, because the design asks for square
-- corners and an outline a Quad cannot give on its own.  The frame is built
-- around its own centre so a component can grow it without moving it.
function L.Frame(name, tint)
	local af = Def.ActorFrame{Name=name}
	local edges = {
		{"Top",    0, -0.5,  0, 0},
		{"Bottom", 0,  0.5,  0, 0},
		{"Left",  -0.5, 0,   0, 0},
		{"Right",  0.5, 0,   0, 0},
	}
	for _, edge in ipairs(edges) do
		af[#af+1] = Def.Quad{
			Name=edge[1],
			InitCommand=function(self)
				self:diffuse(tint or L.Line)
			end,
		}
	end
	return af
end

-- Resize a frame built by L.Frame.  Called every repaint, so it does the four
-- placements arithmetically rather than tweening anything.
function L.SizeFrame(af, width, height, thickness, tint)
	if not af then return end
	local half_w, half_h = width/2, height/2
	local t = thickness
	local edges = {
		{"Top",    0, -half_h + t/2, width, t},
		{"Bottom", 0,  half_h - t/2, width, t},
		{"Left",  -half_w + t/2, 0,  t, height},
		{"Right",  half_w - t/2, 0,  t, height},
	}
	for _, edge in ipairs(edges) do
		local quad = af:GetChild(edge[1])
		if quad then
			quad:xy(edge[2], edge[3]):zoomto(edge[4], edge[5])
			if tint then quad:diffuse(tint) end
		end
	end
end

------------------------------------------------------------
-- The dock.

L.BarPadX     = 26
L.BarPadY     = 26
L.BarBottom   = L.HalfH - 44          -- the bar's own bottom edge

L.TileSize    = 104
L.TileGap     = 26
L.IconSize    = 56
L.IconSource  = 192                   -- the icon PNGs are square at this size
L.LabelGap    = 14
L.LabelPx     = 15

L.DockH       = L.BarPadY*2 + L.TileSize + L.LabelGap + L.LabelPx + 4
L.DockTop     = L.BarBottom - L.DockH
L.TileBottom  = L.BarBottom - L.BarPadY - L.LabelPx - 4 - L.LabelGap
L.LabelY      = L.BarBottom - L.BarPadY - L.LabelPx/2 - 2

-- Magnification, the one motion in the menu: the tile under the cursor grows
-- and its neighbours follow it a little.  Tiles keep their places -- the gap is
-- wide enough to absorb the growth -- so nothing slides sideways as the cursor
-- travels, which is what makes a position learnable.
L.TileZoom    = {1.22, 1.08, 1.03}
L.MaxTiles    = 16

------------------------------------------------------------
-- The category strip, floating above the dock.

L.StripGap    = 18
L.PillH       = 64
L.PillPadX    = 26
L.PillGap     = 14
L.PillNamePx  = 22
L.PillMetaPx  = 13
L.PillTextGap = 14
L.PillZoom    = 1.10
L.MaxPills    = 24

L.StripH      = L.BarPadY*2 + L.PillH
L.StripBottom = L.DockTop - L.StripGap
L.StripTop    = L.StripBottom - L.StripH
L.StripMid    = L.StripBottom - L.StripH/2

-- The widest a bar may grow before its content starts sliding inside it.
L.MaxBarW     = 1832

L.Scale = math.min(_screen.w/1920, _screen.h/1080)

return L
