-- The back of the focused jacket: the pack's song titles.
--
-- Start on a pack turns its jacket over (default.lua) and this face shows the
-- songs' titles in the order the song wheel lists them, on a red ground in the
-- pack step's Persona-style dress: each title on its own slanted slab, black
-- and white in turn, staggered left and right.  A pack with more titles than
-- the face holds scrolls by itself, round and round; Up/Down nudge it a row
-- (and hold the automatic scroll for a moment), Start opens the song wheel and
-- Back turns the jacket face up again.
--
-- The rows are a fixed pool that slides up through the face: when a row
-- leaves the top it comes back in at the bottom with the next title.  Rows
-- fade out near the edges of the face instead of being clipped.  Slabs are a
-- texture with anti-aliased edges (Graphics/VOLT26/PackSelect/slab.png), not
-- skewed quads, so their slanted sides stay clean.
--
-- Commands:
--   SetSongs {Group=<name>}   fill the list from the first title
--   Scroll {Delta=<rows>}     move the list; sets .moved to whether it can
--   Hide                      put it away (after the turn back)
-- Params: K, Size (the face is built at this size), X, Y, Zoom, Tilt.
local p = ...
local K = p.K
local size = p.Size
local PackSelection = VOLT26.PackSelection

local PITCH = 58               -- row spacing
local SLAB_H = 46
local TEXT_PX = 28
local PAD_X = 22               -- slab padding around the title
local INSET = 30               -- face edge to the slabs' left edge
local STAGGER = 18             -- alternate rows sit this much further right
local MAX_TEXT = size - INSET*2 - STAGGER - PAD_X*2
local FIT = math.floor((size - 40) / PITCH)   -- rows that fit without scrolling
local POOL = FIT + 2
local SPEED = 0.55             -- rows per second
local START_HOLD = 1.2         -- seconds before scrolling starts
local NUDGE_HOLD = 2.0         -- seconds a manual nudge holds the scroll
local FADE = PITCH * 0.9       -- rows fade over this distance from an edge
local RED = color("#e5001a")

local top = -size/2
local bottom = size/2

local function wrap(index, total)
	return ((index - 1) % total) + 1
end

local function slabLook(row, songIndex)
	local dark = songIndex % 2 == 1
	row:GetChild("Slab"):diffuse(dark and Color.Black or Color.White)
	row:GetChild("Title"):diffuse(dark and Color.White or Color.Black)
	row:x(dark and 0 or STAGGER)
end

-- Put a title on a row and size its slab to it.
local function setRow(row, song, songIndex)
	local title = row:GetChild("Title")
	K.SetDisplay(title, song:GetDisplayMainTitle(), TEXT_PX, MAX_TEXT)
	local width = math.min(title:GetWidth() * VOLT26.Type.DisplayZoom(TEXT_PX), MAX_TEXT)
	row:GetChild("Slab"):zoomto(width + PAD_X*2, SLAB_H)
	slabLook(row, songIndex)
	row.songIndex = songIndex
end

-- Lay the pool out for the current scroll position.
local function layout(self)
	local songs = self.songs
	local total = #songs
	local scrolling = total > FIT
	local base = math.floor(self.pos)
	local frac = self.pos - base
	-- A short list stands centred and still.
	local firstY = scrolling and (top + 20 + PITCH/2 - frac * PITCH)
		or (-(math.min(total, FIT) - 1) * PITCH / 2)
	for i = 1, POOL do
		local row = self:GetChild("Row" .. i)
		local n = base + i - 1
		local show = scrolling or (n < total)
		if total == 0 or not show then
			row:visible(false)
		else
			local songIndex = wrap(n + 1, total)
			if row.songIndex ~= songIndex then setRow(row, songs[songIndex], songIndex) end
			local y = firstY + (i - 1) * PITCH
			local edge = math.min(y - top, bottom - y)
			row:visible(true):y(y)
				:diffusealpha(scrolling and math.max(0, math.min(1, (edge - SLAB_H/2) / FADE)) or 1)
		end
	end
	self:GetChild("Empty"):visible(total == 0)
end

local af = Def.ActorFrame{
	Name="SongList",
	InitCommand=function(self)
		self.songs, self.pos, self.hold, self.moved = {}, 0, 0, false
		self:xy(p.X or 0, p.Y or 0):zoom(p.Zoom or 1):rotationz(p.Tilt or 0):visible(false)
		self:SetUpdateFunction(function(frame, delta)
			if not frame:GetVisible() or #frame.songs <= FIT then return end
			delta = delta or 0
			if frame.hold > 0 then
				frame.hold = frame.hold - delta
				return
			end
			frame.pos = (frame.pos + delta * SPEED) % #frame.songs
			layout(frame)
		end)
	end,
	HideCommand=function(self) self:visible(false):rotationy(0) end,
	SetSongsCommand=function(self, params)
		self.songs = PackSelection.Songs(params and params.Group)
		self.pos, self.hold = 0, START_HOLD
		for i = 1, POOL do self:GetChild("Row" .. i).songIndex = nil end
		layout(self)
	end,
	ScrollCommand=function(self, params)
		local total = #self.songs
		self.moved = total > FIT
		if not self.moved then return end
		-- To the next whole row in the asked direction, then hold there.
		local delta = params and params.Delta or 0
		local pos = delta > 0 and math.floor(self.pos + 1e-3) + delta or math.ceil(self.pos - 1e-3) + delta
		self.pos = pos % total
		self.hold = NUDGE_HOLD
		layout(self)
	end,
}

af[#af+1] = Def.Quad{
	Name="Ground",
	InitCommand=function(self) self:zoomto(size, size):diffuse(RED) end,
}
af[#af+1] = K.Text{ Name="Empty", Role="Display", Px=TEXT_PX, Tint=Color.White, Align=center, Text=K.String("PackListEmpty") }

for i = 1, POOL do
	af[#af+1] = Def.ActorFrame{
		Name="Row" .. i,
		Def.Sprite{
			Name="Slab", Texture=THEME:GetPathG("", "VOLT26/PackSelect/slab.png"),
			InitCommand=function(self) self:horizalign(left):x(top + INSET) end,
		},
		K.Text{ Name="Title", Role="Display", Px=TEXT_PX, X=top + INSET + PAD_X, Width=MAX_TEXT },
	}
end

return af
