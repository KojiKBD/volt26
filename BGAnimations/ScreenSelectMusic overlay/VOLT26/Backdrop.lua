-- Song Select backdrop: the flat ground and the diamond lattice over it.
--
-- This lives with the rest of the Song Select composition but is loaded by the
-- screen's background layer, because the MusicWheel draws between the screen
-- background and the overlay and the lattice has to stay behind it.

local W, H = 1920, 1080
local scale = math.min(_screen.w/W, _screen.h/H)
local left = _screen.cx - W*scale/2
local top = _screen.cy - H*scale/2

local ground = color("#0a0a0c")
-- The artwork sits behind a veil of the ground colour.  The screen's panels are
-- near-black and its text is thin, so a full-strength illustration behind them
-- competes with the content; this is the one number to turn if the art should
-- read stronger or weaker.
local artVeil = 0.70
-- One pixel of white at three percent, repeating every 46 units along each
-- diagonal.  Any more and the lattice stops being texture and starts being
-- pattern.
local lattice = {1, 1, 1, 0.03}
local spacing = 46
local lineWidth = 1

-- Clip an infinite line against the design rectangle and return its two ends,
-- so the lattice never bleeds into the letterbox on non-16:9 screens.
local function clipToScreen(px, py, ux, uy)
	local low, high = -math.huge, math.huge
	local function clamp(p, u, limit)
		if math.abs(u) < 1e-6 then return p >= 0 and p <= limit end
		local a, b = -p/u, (limit-p)/u
		if a > b then a, b = b, a end
		low, high = math.max(low, a), math.min(high, b)
		return true
	end
	if not clamp(px, ux, W) then return nil end
	if not clamp(py, uy, H) then return nil end
	if high <= low then return nil end
	return low, high
end

local function appendLines(vertices, ux, uy)
	-- The normal is the direction rotated a quarter turn; lines are stepped
	-- along it so the gap between them is the design's 46 units measured
	-- perpendicular, not along an axis.
	local nx, ny = -uy, ux
	local reach = math.ceil((W + H)/spacing)
	for step = -reach, reach do
		local offset = step*spacing
		local px, py = W/2 + nx*offset, H/2 + ny*offset
		local low, high = clipToScreen(px, py, ux, uy)
		if low then
			local halfX, halfY = nx*lineWidth/2, ny*lineWidth/2
			local ax, ay = px + ux*low, py + uy*low
			local bx, by = px + ux*high, py + uy*high
			vertices[#vertices+1] = {{ax-halfX, ay-halfY, 0}, lattice}
			vertices[#vertices+1] = {{bx-halfX, by-halfY, 0}, lattice}
			vertices[#vertices+1] = {{bx+halfX, by+halfY, 0}, lattice}
			vertices[#vertices+1] = {{ax+halfX, ay+halfY, 0}, lattice}
		end
	end
end

local function latticeVertices()
	local vertices = {}
	local diagonal = math.sqrt(0.5)
	appendLines(vertices,  diagonal, diagonal)
	appendLines(vertices,  diagonal, -diagonal)
	return vertices
end

return Def.ActorFrame{
	Name="VOLT26SongSelectBackdrop",
	InitCommand=function(self) self:xy(left, top):zoom(scale) end,

	Def.Quad{
		Name="Ground",
		InitCommand=function(self)
			-- Sized past the design rectangle so a non-16:9 screen keeps the
			-- same ground colour out to its own edges.
			self:align(0,0):xy(-W, -H):zoomto(W*3, H*3):diffuse(ground)
		end,
	},
	Def.Sprite{
		Name="Art",
		Texture=THEME:GetPathG("", "VOLT26/SongSelection/backdrop.png"),
		InitCommand=function(self)
			-- Authored at the design's own size, so it maps onto the design
			-- rectangle one to one and needs no cropping.
			self:align(0,0):xy(0,0):zoomto(W, H)
		end,
	},
	Def.Quad{
		Name="ArtVeil",
		InitCommand=function(self)
			self:align(0,0):xy(-W, -H):zoomto(W*3, H*3)
				:diffuse(ground):diffusealpha(artVeil)
		end,
	},
	Def.ActorMultiVertex{
		Name="Lattice",
		InitCommand=function(self)
			local vertices = latticeVertices()
			self:SetDrawState({Mode="DrawMode_Quads"})
				:SetNumVertices(#vertices):SetVertices(vertices)
		end,
	},
}
