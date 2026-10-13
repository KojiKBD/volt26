-- The end-of-song graph of one player, in the artwork's slanted frame at the
-- bottom left of the WANTED page.  It is Simply Love's evaluation graph --
-- the chart's density, the judgment scatter plot, the life line and the point
-- of failure (VOLT26.EvaluationPage.GetGraph) -- drawn in perspective: a point
-- at (u, v) of the graph, u along the song and v up from the bottom, is placed
-- by bilinear interpolation between the frame's four corners, so everything
-- follows the frame's angles.
local p = ...
local Art, quad, graph, colors = p.Art, p.quad, p.graph, p.colors

local function at(u, v)
	local tl, tr, br, bl = quad.topLeft, quad.topRight, quad.bottomRight, quad.bottomLeft
	local topX, topY = tl[1] + (tr[1] - tl[1]) * u, tl[2] + (tr[2] - tl[2]) * u
	local botX, botY = bl[1] + (br[1] - bl[1]) * u, bl[2] + (br[2] - bl[2]) * u
	local f = 1 - v
	return topX + (botX - topX) * f, topY + (botY - topY) * f
end

local function vertex(u, v, colour)
	local x, y = at(u, v)
	return { {x, y, 0}, colour }
end

-- Density: a profile dark at the bottom and bright at its peaks, red for
-- player 1's side and always blue for player 2's.
local PALETTES = {
	red  = { deep = color("#3a0000"), peak = color("#ff2a12"), edge = color("#ff7a5c") },
	blue = { deep = color("#00103a"), peak = color("#0a7dff"), edge = color("#66c6ff") },
}
local palette = PALETTES[p.palette or "red"] or PALETTES.red
local DEEP, PEAK, EDGE = palette.deep, palette.peak, palette.edge

local function lerpColour(a, b, t, alpha)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, alpha or 1 }
end

local af = Def.ActorFrame{ Name="Graph" }

if #graph.density > 1 then
	af[#af+1] = Def.ActorMultiVertex{
		Name="Density",
		InitCommand=function(self)
			local vertices = {}
			for _, point in ipairs(graph.density) do
				vertices[#vertices+1] = vertex(point[1], 0, lerpColour(DEEP, PEAK, 0, 0.92))
				vertices[#vertices+1] = vertex(point[1], point[2], lerpColour(DEEP, PEAK, point[2], 0.92))
			end
			self:SetDrawState{ Mode="DrawMode_QuadStrip" }:SetVertices(vertices)
		end,
	}
	af[#af+1] = Def.ActorMultiVertex{
		Name="DensityEdge",
		InitCommand=function(self)
			local vertices = {}
			for _, point in ipairs(graph.density) do vertices[#vertices+1] = vertex(point[1], point[2], EDGE) end
			self:SetDrawState{ Mode="DrawMode_LineStrip" }:SetLineWidth(1.5):SetVertices(vertices)
		end,
	}
end

-- A course: every other song a shade lighter.
for index, segment in ipairs(graph.segments) do
	if index % 2 == 0 then
		af[#af+1] = Def.ActorMultiVertex{
			InitCommand=function(self)
				local tint = { 1, 1, 1, 0.07 }
				self:SetDrawState{ Mode="DrawMode_Quads" }:SetVertices{
					vertex(segment[1], 1, tint), vertex(segment[2], 1, tint),
					vertex(segment[2], 0, tint), vertex(segment[1], 0, tint),
				}
			end,
		}
	end
end

-- The on-time line, where the artwork draws its white line.
af[#af+1] = Def.ActorMultiVertex{
	Name="ZeroLine",
	InitCommand=function(self)
		local tint = { 1, 1, 1, 0.75 }
		self:SetDrawState{ Mode="DrawMode_LineStrip" }:SetLineWidth(2.5)
			:SetVertices{ vertex(0, Art.zeroLine, tint), vertex(1, Art.zeroLine, tint) }
	end,
}

-- Judgment offsets: a small square per tap in its judgment's colour (early at
-- the top, late at the bottom); a miss is a faint red line across.
if #graph.offsets > 0 then
	af[#af+1] = Def.ActorMultiVertex{
		Name="Scatter",
		InitCommand=function(self)
			local vertices, size = {}, 1.6
			local missTint = { 1, 0, 0, 0.4 }
			for _, point in ipairs(graph.offsets) do
				local u, v, key = point[1], point[2], point[3]
				if key == "Miss" then
					local x0, y0 = at(u, 1)
					local x1, y1 = at(u, 0)
					vertices[#vertices+1] = { {x0, y0, 0}, missTint }
					vertices[#vertices+1] = { {x0 + 1.2, y0, 0}, missTint }
					vertices[#vertices+1] = { {x1 + 1.2, y1, 0}, missTint }
					vertices[#vertices+1] = { {x1, y1, 0}, missTint }
				else
					local c = colors[key] or colors.W1
					local tint = { c[1], c[2], c[3], 0.8 }
					local x, y = at(u, v)
					vertices[#vertices+1] = { {x - size, y - size, 0}, tint }
					vertices[#vertices+1] = { {x + size, y - size, 0}, tint }
					vertices[#vertices+1] = { {x + size, y + size, 0}, tint }
					vertices[#vertices+1] = { {x - size, y + size, 0}, tint }
				end
			end
			self:SetDrawState{ Mode="DrawMode_Quads" }:SetVertices(vertices)
		end,
	}
end

-- The life line, white, as Simply Love's GraphDisplay draws it.
if #graph.life > 1 then
	af[#af+1] = Def.ActorMultiVertex{
		Name="Life",
		InitCommand=function(self)
			local vertices, tint = {}, { 1, 1, 1, 1 }
			for _, point in ipairs(graph.life) do vertices[#vertices+1] = vertex(point[1], point[2], tint) end
			self:SetDrawState{ Mode="DrawMode_LineStrip" }:SetLineWidth(2):SetVertices(vertices)
		end,
	}
end

-- Where the player failed: a red line and the time that was left.
if graph.failedAt then
	local seconds = math.floor(graph.secondsLeft + 0.5)
	local text = ("-%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
	af[#af+1] = Def.ActorMultiVertex{
		Name="Failure",
		InitCommand=function(self)
			local tint = color("#ff0000")
			self:SetDrawState{ Mode="DrawMode_LineStrip" }:SetLineWidth(3)
				:SetVertices{ vertex(graph.failedAt, 1, tint), vertex(graph.failedAt, 0, tint) }
		end,
	}
	af[#af+1] = LoadFont(p.font)..{
		Name="TimeLeft",
		InitCommand=function(self)
			local x, y = at(graph.failedAt, 0.92)
			local tx, ty = at(math.min(1, graph.failedAt + 0.1), 0.92)
			self:halign(0):valign(0.5):xy(x + 6, y):zoom(p.fontZoom)
				:rotationz(math.deg(math.atan2(ty - y, tx - x)))
				:diffuse(color("#ff3b2f")):settext(text)
		end,
	}
end

return af
