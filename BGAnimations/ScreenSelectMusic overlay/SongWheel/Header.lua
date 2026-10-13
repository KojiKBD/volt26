-- The open pack's tile, under the song's jacket (Jacket.lua) in the jacket's
-- frame.  It is the pack step's own tile (ScreenVOLT26SelectPack overlay/
-- Tile.lua) zoomed down to K.Badge, so it is the same picture as the jacket
-- that shrank into this spot on the way in and grows out of it on the way
-- back, and it is what shows for a song that has no artwork of its own.
local p = ...
local K, S = p.K, p.S

local af = Def.ActorFrame{
	Name="Header",
	RefreshCommand=function(self)
		local course = S.IsCourseMode()
		local pack = course and "" or S.Pack()
		local badge = self:GetChild("Badge")
		badge:visible(not course and pack ~= "")
		if not course and pack ~= badge.group then
			badge:playcommand("SetPack", { Group = pack ~= "" and pack or nil })
			badge:playcommand("LoadPackArt")
		end
	end,
	SongWheelInCommand=function(self) end,
	SongWheelOutCommand=function(self) end,
}

af[#af+1] = LoadActor(THEME:GetPathB("ScreenVOLT26SelectPack", "overlay/Tile.lua"), { K=K, Name="Badge" })..{
	InitCommand=function(self)
		self.group, self.loadedGroup, self.artPending = nil, nil, false
		self:xy(K.Badge.X, K.Badge.Y):zoom(K.Badge.Size / K.TileSize)
	end,
}

return af
