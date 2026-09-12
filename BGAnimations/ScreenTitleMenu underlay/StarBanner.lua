-- Title banner artwork drawn straight onto a 3D banner surface: concentric red
-- stars expanding behind the entry's caption. Returns the canvas size and its
-- layers back to front; the caller places every layer on the surface. Canvas
-- coordinates are centered pixels of the 1408x512 banner movies this replaced.
local caption = ...

local Width, Height = 1408, 512
local StarPoints = 5
local InnerRadiusRatio = 0.381966
-- Distance from a regular star's center to its edge lines, per unit tip radius.
local EdgeDistanceRatio = 0.309017
local PairWidth = 84
local PairsPerSecond = 3
local CoreColor = color("#2D0000")
local RimColor = color("#6E0000")
local GradientColumns, GradientRows = 8, 4
local CaptionX, CaptionY, CaptionZoom = 713 - Width/2, 361 - Height/2, 1.45
-- Opaque bounds shared by every 1920x1080 caption PNG, so the quad carries no
-- transparent margin.
local CaptionCrop = {left = 680/1920, right = 1 - 1230/1920, top = 350/1080, bottom = 1 - 586/1080}

local halfWidth, halfHeight = Width/2, Height/2
local halfDiagonal = math.sqrt(halfWidth^2 + halfHeight^2)

local function Inside(point, axis, limit, keepBelow)
	if keepBelow then return point[axis] <= limit end
	return point[axis] >= limit
end

-- Sutherland-Hodgman against one canvas edge. Points are {x, y, u}; u is linear
-- across the source triangle, so interpolating it along cut edges stays exact.
local function ClipToEdge(polygon, axis, limit, keepBelow)
	local clipped = {}
	for i, current in ipairs(polygon) do
		local previous = polygon[(i - 2) % #polygon + 1]
		local currentInside = Inside(current, axis, limit, keepBelow)
		if currentInside ~= Inside(previous, axis, limit, keepBelow) then
			local t = (limit - previous[axis]) / (current[axis] - previous[axis])
			local cut = {}
			for k = 1, 3 do cut[k] = previous[k] + (current[k] - previous[k]) * t end
			clipped[#clipped+1] = cut
		end
		if currentInside then clipped[#clipped+1] = current end
	end
	return clipped
end

local function ClipToCanvas(polygon)
	polygon = ClipToEdge(polygon, 1, -halfWidth, false)
	polygon = ClipToEdge(polygon, 1, halfWidth, true)
	polygon = ClipToEdge(polygon, 2, -halfHeight, false)
	return ClipToEdge(polygon, 2, halfHeight, true)
end

-- Inside each center/tip/inner-corner triangle the distance to the nearest edge
-- line grows linearly, so interpolated texture coordinates trace exact concentric
-- stars from a wrapping stripe texture.
local function StripeVertices()
	local tipRadius = halfDiagonal / InnerRadiusRatio * 1.05
	local rimU = tipRadius * EdgeDistanceRatio / PairWidth
	local corners = {}
	for i = 0, StarPoints * 2 do
		local radius = i % 2 == 0 and tipRadius or tipRadius * InnerRadiusRatio
		local angle = math.rad(-90 + i * 180 / StarPoints)
		corners[i] = {radius * math.cos(angle), radius * math.sin(angle), rimU}
	end

	local vertices = {}
	for i = 0, StarPoints * 2 - 1 do
		local polygon = ClipToCanvas({{0, 0, 0}, corners[i], corners[i+1]})
		for k = 2, #polygon - 1 do
			for _, point in ipairs({polygon[1], polygon[k], polygon[k+1]}) do
				vertices[#vertices+1] = {{point[1], point[2], 0}, Color.White, {point[3], 0.5}}
			end
		end
	end
	return vertices
end

local function GradientVertices()
	local function GridPoint(column, row)
		local x = -halfWidth + Width * column / GradientColumns
		local y = -halfHeight + Height * row / GradientRows
		local t = math.sqrt(x*x + y*y) / halfDiagonal
		local shade = {}
		for k = 1, 4 do shade[k] = CoreColor[k] + (RimColor[k] - CoreColor[k]) * t end
		return {{x, y, 0}, shade}
	end

	local vertices = {}
	for row = 0, GradientRows - 1 do
		for column = 0, GradientColumns - 1 do
			local topLeft, topRight = GridPoint(column, row), GridPoint(column + 1, row)
			local bottomLeft, bottomRight = GridPoint(column, row + 1), GridPoint(column + 1, row + 1)
			for _, point in ipairs({topLeft, topRight, bottomRight, topLeft, bottomRight, bottomLeft}) do
				vertices[#vertices+1] = point
			end
		end
	end
	return vertices
end

local function Mesh(vertices, name, texturePath)
	return Def.ActorMultiVertex{
		Name=name,
		InitCommand=function(self)
			if texturePath then
				self:LoadTexture(texturePath):texturewrapping(true)
			end
			self:zbuffer(true):SetDrawState({Mode="DrawMode_Triangles"})
				:SetNumVertices(#vertices):SetVertices(vertices)
		end,
	}
end

local phase = 0

return {
	Width = Width,
	Height = Height,
	Layers = {
		Mesh(GradientVertices(), "Gradient"),

		Def.ActorFrame{
			OnCommand=function(self)
				local stripes = self:GetChild("Stripes")
				self:SetUpdateFunction(function(_, delta)
					phase = (phase + delta * PairsPerSecond) % 1
					stripes:texturetranslate(-phase, 0)
				end)
			end,
			Mesh(StripeVertices(), "Stripes", THEME:GetPathG("", "VOLT26/TitleTravelCity/star_stripes.png")),
		},

		Def.Sprite{
			Texture=THEME:GetPathG("", "VOLT26/"..caption.."_text.png"),
			InitCommand=function(self)
				self:xy(CaptionX, CaptionY):zoom(CaptionZoom):zbuffer(true)
					:cropleft(CaptionCrop.left):cropright(CaptionCrop.right)
					:croptop(CaptionCrop.top):cropbottom(CaptionCrop.bottom)
			end,
		},
	},
}
