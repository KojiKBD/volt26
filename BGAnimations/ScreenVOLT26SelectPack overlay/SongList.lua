-- The back of the focused jacket: the pack's song list.
--
-- Start on a pack turns its jacket over (default.lua) and this face shows the
-- songs in the order the song wheel lists them, ten at a time.  Up/Down scroll
-- the list, Start opens the song wheel and Back turns the jacket face up again.
--
-- Commands:
--   SetSongs {Group=<name>}   fill the list from the top for this pack
--   Scroll {Delta=<rows>}     move the list; sets .moved to whether it did
local p = ...
local K = p.K
local size = p.Size
local PackSelection = VOLT26.PackSelection

local ROWS = 10
local PITCH = 46
local PAD = 26
local HEADER = 64
local top = -size/2
local listTop = top + HEADER + 4
local left = -size/2 + PAD
local right = size/2 - PAD
local titleX = left + 50
local titleWidth = right - 70 - titleX

local function fill(self)
	local songs = self.songs or {}
	for i = 1, ROWS do
		local row = self:GetChild("Row" .. i)
		local index = self.offset + i
		local song = songs[index]
		row:visible(song ~= nil)
		if song then
			K.SetLabel(row:GetChild("Index"), string.format("%02d", index), 13)
			K.SetDisplay(row:GetChild("Title"), song:GetDisplayMainTitle(), 26, titleWidth)
			local meter = PackSelection.HardestMeter(song)
			K.SetLabel(row:GetChild("Meter"), meter and tostring(meter) or "", 15)
		end
	end
	local total = #songs
	local last = math.min(total, self.offset + ROWS)
	K.SetLabel(self:GetChild("Range"),
		total > 0 and string.format("%02d-%02d / %02d", self.offset + 1, last, total) or "", 13)
	self:GetChild("Empty"):visible(total == 0)
end

local af = Def.ActorFrame{
	Name="SongList",
	InitCommand=function(self)
		self.songs, self.offset, self.moved = {}, 0, false
	end,
	SetSongsCommand=function(self, params)
		self.songs = PackSelection.Songs(params and params.Group)
		self.offset = 0
		fill(self)
	end,
	ScrollCommand=function(self, params)
		local maxOffset = math.max(0, #self.songs - ROWS)
		local offset = math.max(0, math.min(maxOffset, self.offset + (params and params.Delta or 0)))
		self.moved = offset ~= self.offset
		if self.moved then
			self.offset = offset
			fill(self)
		end
	end,
}

af[#af+1] = K.Rule{ Name="Stroke", AlignX=0.5, AlignY=0.5, Width=size+4, Height=size+4, Tint=K.Line }
af[#af+1] = K.Rule{ Name="Ground", AlignX=0.5, AlignY=0.5, Width=size, Height=size, Tint=K.Panel }
af[#af+1] = K.Text{ Name="Heading", Px=13, Tint=K.Accent, X=left, Y=top + HEADER/2, Text=K.String("PackSongsHeading") }
af[#af+1] = K.Text{ Name="Range", Px=13, Tint=K.Mute, Align=right, X=right, Y=top + HEADER/2 }
af[#af+1] = K.Rule{ X=left, Y=top + HEADER, Width=size - PAD*2, Height=1 }
af[#af+1] = K.Text{ Name="Empty", Px=14, Tint=K.Dim, X=left, Y=listTop + PITCH/2, Text=K.String("PackListEmpty") }

for i = 1, ROWS do
	local row = Def.ActorFrame{
		Name="Row" .. i,
		InitCommand=function(self) self:y(listTop + (i - 0.5) * PITCH) end,
	}
	row[#row+1] = K.Rule{ X=left, Y=PITCH/2 - 1, Width=size - PAD*2, Height=1, Alpha=0.5 }
	row[#row+1] = K.Text{ Name="Index", Px=13, Tint=K.Dim, X=left }
	row[#row+1] = K.Text{ Name="Title", Role="Display", Px=26, Tint=K.Ink, X=titleX }
	row[#row+1] = K.Text{ Name="Meter", Px=15, Tint=K.Mute, Align=right, X=right }
	af[#af+1] = row
end

af[#af+1] = K.Text{ Name="Hint", Px=11, Tint=K.Dim, Align=center, Y=size/2 - 18, Text=K.String("PackListHint") }

local frame = K.Outline{ Name="Frame", Width=size+16, Height=size+16, Stroke=6, Tint=K.Accent }
af[#af+1] = frame

return af
