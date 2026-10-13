-- The timing page of one side, in the NOTES container: Simply Love's offset
-- pane redrawn.  A histogram of every tap's offset (early on the left, late
-- on the right, each bar in its judgment's colour, the on-time line in the
-- middle, the windows' edges marked under it), then the counts and the
-- statistics: early, late, misses, mean offset, standard deviation, mean
-- absolute error and the largest error.
--
-- Laid out about the container's centre, turned like its rows; player 2's
-- sits in the mirrored container but is not flipped (early stays left).
--
-- p = { Art, T, player, mirror, ROW = {key = {bright, dim}} }
local p = ...
local Art, T, mirror, ROW = p.Art, p.T, p.mirror, p.ROW
local data = VOLT26.EvaluationPage.GetTiming(p.player)
local inside = Art.notes.inside
local rot = Art.notes.rows.rot

local cx = (inside[1] + inside[3]) / 2
local cy = (inside[2] + inside[4]) / 2
-- The histogram's box, relative to the centre (the top band of the
-- container holds the page's title at the left).
local H = { left = -270, right = 262, top = -150, bottom = 60 }
local WHITE, GREY = color("#ffffff"), color("#8e8e8e")

local af = Def.ActorFrame{
	Name="Timing",
	InitCommand=function(self)
		self:xy(mirror and 1920 - cx or cx, cy):rotationz(mirror and -rot or rot)
	end,
}

local function xOf(seconds)
	return H.left + (seconds + data.worst) / (2 * data.worst) * (H.right - H.left)
end

-- Bars.
if data.peak > 0 then
	af[#af+1] = Def.ActorMultiVertex{
		Name="Bars",
		InitCommand=function(self)
			local vertices = {}
			local width = (H.right - H.left) / #data.bins
			for index, bin in ipairs(data.bins) do
				local c = ROW[bin.key] and ROW[bin.key][1] or WHITE
				local top = H.bottom - (H.bottom - H.top) * bin.count / data.peak
				local x0 = H.left + (index - 1) * width + 1
				local x1 = x0 + width - 2
				local hi, lo = { c[1], c[2], c[3], 1 }, { c[1] * 0.35, c[2] * 0.35, c[3] * 0.35, 1 }
				vertices[#vertices+1] = { { x0, top, 0 }, hi }
				vertices[#vertices+1] = { { x1, top, 0 }, hi }
				vertices[#vertices+1] = { { x1, H.bottom, 0 }, lo }
				vertices[#vertices+1] = { { x0, H.bottom, 0 }, lo }
			end
			self:SetDrawState{ Mode="DrawMode_Quads" }:SetVertices(vertices)
		end,
	}
end

-- Base line, on-time line and the windows' edges (both sides).
af[#af+1] = Def.ActorMultiVertex{
	Name="Scale",
	InitCommand=function(self)
		local vertices = {}
		-- Axis-aligned lines as thin quads (2 px).
		local function line(x0, y0, x1, y1, c)
			local hx, hy = (x0 == x1) and 1 or 0, (y0 == y1) and 1 or 0
			vertices[#vertices+1] = { { x0 - hx, y0 - hy, 0 }, c }
			vertices[#vertices+1] = { { x1 + hx, y0 - hy, 0 }, c }
			vertices[#vertices+1] = { { x1 + hx, y1 + hy, 0 }, c }
			vertices[#vertices+1] = { { x0 - hx, y1 + hy, 0 }, c }
		end
		line(H.left, H.bottom + 1, H.right, H.bottom + 1, { 1, 1, 1, 0.9 })
		line(xOf(0), H.top - 8, xOf(0), H.bottom + 10, { 1, 1, 1, 0.9 })
		for index, edge in ipairs(data.edges) do
			if index < #data.edges then
				local c = { 1, 1, 1, 0.35 }
				line(xOf(-edge), H.bottom + 2, xOf(-edge), H.bottom + 12, c)
				line(xOf(edge), H.bottom + 2, xOf(edge), H.bottom + 12, c)
			end
		end
		self:SetDrawState{ Mode="DrawMode_Quads" }:SetVertices(vertices)
	end,
}

local function text(font, size, tint, value, x, y, halign)
	return LoadFont(T.Font[font])..{
		InitCommand=function(self)
			self:halign(halign or 0):valign(1):xy(x, y):zoom(size / T.EM[font]):zoomx(size / T.EM[font] * 0.9)
				:diffuse(tint):settext(value)
		end,
	}
end

af[#af+1] = text("Bold", 24, WHITE, "EARLY", H.left, H.top - 10, 0)
af[#af+1] = text("Bold", 24, WHITE, "LATE", H.right, H.top - 10, 1)

-- Counts and statistics in two columns under the histogram.
local function signed(ms) return (ms >= 0 and "+" or "") .. ("%.1f ms"):format(ms) end
local left = {
	{ "early", tostring(data.early), ROW.W0[1] },
	{ "late", tostring(data.late), ROW.W2[1] },
	{ "miss", tostring(data.misses), ROW.Miss[1] },
}
local right = {
	{ "mean", signed(data.meanMs), WHITE },
	{ "std dev", ("%.1f ms"):format(data.sigmaMs), WHITE },
	{ "max", ("%.1f ms"):format(data.maxErrorMs), WHITE },
}
local lineGap, size = 44, 30
for index, entry in ipairs(left) do
	local y = H.bottom + 52 + (index - 1) * lineGap
	af[#af+1] = text("Label", size, WHITE, entry[1] .. " · ", H.left + 4, y, 0)..{
		OnCommand=function(self)
			self:GetParent():GetChild("LeftValue" .. index):x(self:GetX() + self:GetZoomedWidth())
		end,
	}
	af[#af+1] = text("Bold", size, entry[3], entry[2], H.left + 4, y, 0)..{ Name="LeftValue" .. index }
end
for index, entry in ipairs(right) do
	local y = H.bottom + 52 + (index - 1) * lineGap
	af[#af+1] = text("Label", size, GREY, entry[1], 20, y, 0)
	af[#af+1] = text("Bold", size, entry[3], entry[2], H.right, y, 1)
end

return af
