-- Text helpers of the WANTED page.  Everything is in artboard pixels (the
-- page's root frame is zoomed to the screen).
--
-- The artwork's faces have bitmap stand-ins (tools/evaluation/build_fonts.py):
--   Title  Tinos Bold                 for Times New Roman Bold
--   Label  Archivo 500                for Helvetica Now Display Medium
--   Bold   Archivo 700                for Helvetica Now Display Bold
--   Score  Archivo Italic 900         for Helvetica Now Display Black Italic
-- EM is each font's em in texture pixels, so a size in artboard pixels is a
-- zoom of size / EM.  The ink of a face's capitals is CAP of its em.

local T = {}

T.Font = {
	Title = "VOLT26 Eval Title",
	Label = "VOLT26 Eval Label",
	Bold = "VOLT26 Eval Bold",
	Score = "VOLT26 Eval Score",
	-- Strings the faces above cannot draw (CJK titles and the like).
	Fallback = "Common Normal",
}
T.EM = { Title = 78, Label = 48, Bold = 48, Score = 96 }
T.CAP = { Title = 51 / 78, Label = 33 / 48, Bold = 33 / 48, Score = 68 / 96 }

-- True when every character of `text` is one the generated faces carry:
-- ASCII, Latin-1, Latin Extended-A and a few punctuation marks.
function T.Covered(text)
	local i, n = 1, #text
	while i <= n do
		local b = text:byte(i)
		if b < 0x80 then
			i = i + 1
		elseif b >= 0xC2 and b <= 0xC5 then
			i = i + 2
		elseif b == 0xE2 and text:byte(i + 1) == 0x80 then
			local c = text:byte(i + 2)
			if c ~= 0x93 and c ~= 0x94 and c ~= 0x98 and c ~= 0x99 and c ~= 0x9C and c ~= 0x9D and c ~= 0xA6 then
				return false
			end
			i = i + 3
		else
			return false
		end
	end
	return true
end

-- Upper case for the letters the faces carry (Lua's upper is ASCII-only).
function T.Upper(text)
	local map = VOLT26.CutoutMetrics and VOLT26.CutoutMetrics.upper or {}
	return (text:gsub("[%z\1-\127\194-\244][\128-\191]*", function(ch)
		return map[ch] or ch:upper()
	end))
end

-- A digit string padded with zeros to `digits`, and how many of its leading
-- characters are padding (drawn dim).  A zero count dims every digit but the
-- last, as Simply Love does.
function T.Padded(value, digits)
	local text = tostring(math.max(0, math.floor(value or 0)))
	if #text < digits then text = ("0"):rep(digits - #text) .. text end
	local lead = 0
	while lead < #text - 1 and text:sub(lead + 1, lead + 1) == "0" do lead = lead + 1 end
	return text, lead
end

-- One line of text in several segments, set side by side from a baseline:
--   anchor   {x, y, rot, sx, sy} in artboard pixels (baseline-left)
--   segments {font=, size=, color=, text=, dim={count, color}, pad=, width=}
--            pad: space before the segment; width: the segment is squeezed
--            horizontally to at most this width
--   mirror   true for player 2: placed at 1920 - x, turned the other way and
--            ending at the anchor instead of starting there.
--   maxWidth optional: the line is squeezed horizontally to fit.
function T.Run(anchor, segments, mirror, maxWidth)
	local frame = Def.ActorFrame{
		InitCommand=function(self)
			self:xy(mirror and 1920 - anchor.x or anchor.x, anchor.y)
				:rotationz(mirror and -anchor.rot or anchor.rot)
				:zoomx(anchor.sx or 1):zoomy(anchor.sy or 1)
		end,
		OnCommand=function(self)
			local widths, squeezes, total = {}, {}, 0
			for i, segment in ipairs(segments) do
				local child = self:GetChild("Segment" .. i)
				widths[i] = child:GetZoomedWidth()
				squeezes[i] = 1
				if segment.width and widths[i] > segment.width then
					squeezes[i] = segment.width / widths[i]
					widths[i] = segment.width
				end
				total = total + (segment.pad or 0) + widths[i]
			end
			local squeeze = 1
			if maxWidth and total > maxWidth then squeeze = maxWidth / total end
			local x = mirror and -total * squeeze or 0
			for i, segment in ipairs(segments) do
				local child = self:GetChild("Segment" .. i)
				x = x + (segment.pad or 0) * squeeze
				child:x(x):zoomx(child:GetZoomY() * squeezes[i] * squeeze)
				x = x + widths[i] * squeeze
			end
		end,
	}
	for i, segment in ipairs(segments) do
		frame[#frame+1] = LoadFont(T.Font[segment.font])..{
			Name="Segment" .. i,
			InitCommand=function(self)
				self:halign(0):valign(1):zoom(segment.size / T.EM[segment.font])
					:diffuse(segment.color):settext(segment.text)
				if segment.dim and segment.dim[1] > 0 then
					self:AddAttribute(0, { Length=segment.dim[1], Diffuse=segment.dim[2] })
				end
			end,
		}
	end
	return frame
end

return T
