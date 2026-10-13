-- The song's background in a shape of the WANTED page, under a colour the
-- artwork lays over it.  The background layer uses it for the frame's spiky
-- window: the picture turned as in the artwork, under a #f11600 fill in hard
-- light at 70 % opacity.  Per channel that is a straight line in the
-- picture's value d (hard light: screen for a source above one half,
-- multiply below):
--     red   0.3 d + 0.7 (0.890 + 0.110 d) = 0.623 + 0.377 d
--     green 0.3 d + 0.7 (0.173 d)         =         0.421 d
--     blue  0.3 d + 0.7 (0)               =         0.300 d
--
-- So the picture is drawn with the vertex colour `multiply` and the constant
-- `add` is added over it.  Without a picture the shape shows `add` alone, as
-- the artwork does over black.
--
-- p = { shape = {points, triangles}, cover = points the picture must cover,
--       rot = the picture's turn, multiply = {r, g, b}, add = {r, g, b} }
local p = ...
local window = p.shape

local MULTIPLY = { p.multiply[1], p.multiply[2], p.multiply[3], 1 }
local ADD = { p.add[1], p.add[2], p.add[3], 1 }
local VIDEO = { avi = true, mp4 = true, mpg = true, mpeg = true, webm = true, m4v = true, mov = true, ogv = true, mkv = true, wmv = true, flv = true, f4v = true }

local function picturePath()
	local course = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or nil
	local song = GAMESTATE:GetCurrentSong()
	local candidates = {}
	local function add(path) if path and path ~= "" then candidates[#candidates+1] = path end end
	if song then
		add(song:GetBackgroundPath())
		if song:HasJacket() then add(song:GetJacketPath()) end
		if song:HasBanner() then add(song:GetBannerPath()) end
	elseif course then
		if course.GetBackgroundPath then add(course:GetBackgroundPath()) end
		if course:HasBanner() then add(course:GetBannerPath()) end
	end
	for _, path in ipairs(candidates) do
		local ext = path and path:match("%.([^.]+)$")
		-- A movie background would play behind the results: take a still.
		if not (ext and VIDEO[ext:lower()]) then return path end
	end
	return nil
end

-- The smallest box of the picture's aspect, turned by rot, that covers the
-- given points.
local function coverBox(aspect, rot)
	local c, s = math.cos(math.rad(rot)), math.sin(math.rad(rot))
	local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
	for _, pt in ipairs(p.cover) do
		local lx, ly = pt[1] * c + pt[2] * s, -pt[1] * s + pt[2] * c
		x0, x1 = math.min(x0, lx), math.max(x1, lx)
		y0, y1 = math.min(y0, ly), math.max(y1, ly)
	end
	local w, h = x1 - x0, y1 - y0
	if w / h > aspect then h = w / aspect else w = h * aspect end
	return (x0 + x1) / 2, (y0 + y1) / 2, w, h, c, s
end

local function triangles(colour, uv)
	local vertices = {}
	for _, tri in ipairs(window.triangles) do
		for _, index in ipairs(tri) do
			local p = window.points[index]
			vertices[#vertices+1] = uv and { {p[1], p[2], 0}, colour, uv(p) } or { {p[1], p[2], 0}, colour }
		end
	end
	return vertices
end

local path = picturePath()

local frame = Def.ActorFrame{ Name=p.name or "SongPicture" }

if path then
	frame[#frame+1] = Def.Sprite{
		Name="Source",
		Texture=path,
		InitCommand=function(self) self:visible(false) end,
	}
	frame[#frame+1] = Def.ActorMultiVertex{
		Name="Picture",
		OnCommand=function(self)
			local texture = self:GetParent():GetChild("Source"):GetTexture()
			if not texture then return end
			local iw, ih = texture:GetImageWidth(), texture:GetImageHeight()
			local tw, th = texture:GetTextureWidth(), texture:GetTextureHeight()
			local cx, cy, w, h, c, s = coverBox(iw / math.max(ih, 1), p.rot or 0)
			local function uv(p)
				local lx, ly = p[1] * c + p[2] * s - cx, -p[1] * s + p[2] * c - cy
				return { (0.5 + lx / w) * iw / tw, (0.5 + ly / h) * ih / th }
			end
			self:SetTexture(texture):SetDrawState{ Mode="DrawMode_Triangles" }
			self:SetVertices(triangles(MULTIPLY, uv))
		end,
	}
end

frame[#frame+1] = Def.ActorMultiVertex{
	Name="Overlay",
	InitCommand=function(self)
		self:blend(path and "BlendMode_Add" or "BlendMode_Normal")
			:SetDrawState{ Mode="DrawMode_Triangles" }
			:SetVertices(triangles(ADD))
	end,
}

return frame
