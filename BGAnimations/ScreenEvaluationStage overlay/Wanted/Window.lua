-- The song's background in the WANTED frame's spiky window, turned as in the
-- artwork, under the artwork's red overlay.
--
-- The overlay is a #f11600 fill in hard-light at 70 % opacity on exactly the
-- window's shape.  Per channel that is a straight line in the picture's value
-- d (hard light: screen for a source above one half, multiply below):
--     red   0.3 d + 0.7 (0.890 + 0.110 d) = 0.623 + 0.377 d
--     green 0.3 d + 0.7 (0.173 d)         =         0.421 d
--     blue  0.3 d + 0.7 (0)               =         0.300 d
-- so the picture is drawn with the vertex colour (0.377, 0.421, 0.300) and
-- the constant (0.623, 0, 0) is added over it.  Without a picture the window
-- shows the overlay on black, as the artwork does over its black frame.
local Art = ...
local window = Art.window

local MULTIPLY = { 0.377, 0.421, 0.300, 1 }
local ADD = { 0.623, 0, 0, 1 }
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
-- window.
local function coverBox(aspect, rot)
	local c, s = math.cos(math.rad(rot)), math.sin(math.rad(rot))
	local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
	for _, p in ipairs(window.points) do
		local lx, ly = p[1] * c + p[2] * s, -p[1] * s + p[2] * c
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

local frame = Def.ActorFrame{ Name="SongWindow" }

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
			local cx, cy, w, h, c, s = coverBox(iw / math.max(ih, 1), Art.song.rot)
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
