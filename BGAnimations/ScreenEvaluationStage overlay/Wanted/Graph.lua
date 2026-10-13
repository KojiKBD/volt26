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
			Name="Segment" .. index,
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

-- Intro (p.introDelay given): the graph waits hidden for the overlay's
-- VOLT26EvaluationWantedIntro, then draws itself in along the song -- the
-- density, its edge, the taps and the life line grow left to right over
-- SWEEP seconds while the frame's lines fade in; the point of failure lands
-- last.  Each strip is drawn in time order, so drawing its first n vertices
-- is drawing the song up to a point.
local SWEEP = 0.7
local SWEPT = {   -- vertices per step, fewest that draw anything
	{ "Density", 2, 4 }, { "DensityEdge", 1, 2 }, { "Scatter", 4, 4 }, { "Life", 1, 2 },
}
local FADED = { "ZeroLine" }
for index = 2, #graph.segments, 2 do FADED[#FADED+1] = "Segment" .. index end
local LAST = { "Failure", "TimeLeft" }

local function each(self, names, f)
	for _, name in ipairs(names) do
		local child = self:GetChild(name)
		if child then f(child) end
	end
end

if p.introDelay then
	-- The sweep is driven by an update function installed with the screen,
	-- not by a command queued on this frame's tweens: anything that stopped
	-- those tweens used to leave the graph hidden for good.  If the intro
	-- never arrives, the whole graph is shown after SAFETY seconds.
	local SAFETY = 8
	local intro, wait, started, done, elapsed, life = false, 0, false, false, 0, 0

	local function sweepTo(frame, progress, final)
		for _, entry in ipairs(SWEPT) do
			local child = frame:GetChild(entry[1])
			if child then
				if final then
					child:visible(true):SetDrawState{ Num = -1 }
				else
					local step, least = entry[2], entry[3]
					local n = math.floor(progress * child:GetNumVertices() / step) * step
					child:visible(n >= least)
					if n >= least then child:SetDrawState{ Num = n } end
				end
			end
		end
	end

	local function finish(frame, blink)
		done = true
		sweepTo(frame, 1, true)
		each(frame, FADED, function(child) child:finishtweening():diffusealpha(1) end)
		each(frame, LAST, function(child)
			child:visible(true):finishtweening()
			if blink then
				-- A quick blink: these actors are placed in the frame's own
				-- units, so they are not zoomed.
				child:diffusealpha(0):linear(0.05):diffusealpha(1):linear(0.05):diffusealpha(0.25)
					:linear(0.05):diffusealpha(1)
			else
				child:diffusealpha(1)
			end
		end)
	end

	af.OnCommand = function(self)
		-- Hidden until the sweep (the intro may already have been announced;
		-- its wait then runs from here).
		for _, entry in ipairs(SWEPT) do
			local child = self:GetChild(entry[1])
			if child then child:visible(false) end
		end
		each(self, FADED, function(child) child:diffusealpha(0) end)
		each(self, LAST, function(child) child:visible(false) end)
		self:SetUpdateFunction(function(frame, delta)
			if done then return end
			delta = tonumber(delta) or 0
			life = life + delta
			if not intro then
				if life >= SAFETY then finish(frame, false) end
				return
			end
			if not started then
				wait = wait - delta
				if wait > 0 then return end
				started, elapsed = true, 0
				each(frame, FADED, function(child) child:finishtweening():diffusealpha(0):linear(0.25):diffusealpha(1) end)
			end
			elapsed = elapsed + delta
			local t = math.min(1, elapsed / SWEEP)
			if t >= 1 then finish(frame, true) return end
			sweepTo(frame, 1 - (1 - t) * (1 - t), false)
		end)
	end
	af.VOLT26EvaluationWantedIntroMessageCommand = function(self)
		if intro then return end
		intro, wait = true, p.introDelay
	end
end

return af
