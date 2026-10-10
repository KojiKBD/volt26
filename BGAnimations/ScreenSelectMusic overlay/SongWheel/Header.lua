-- Song wheel header, over the wheel: the open pack as a jacket badge with its
-- name, and the song's place in the pack.  The bands, the screen title and the
-- play mode are the shared K.Chrome drawn by default.lua.
--
-- The badge is the pack step's own tile (ScreenVOLT26SelectPack overlay/
-- Tile.lua) zoomed down to K.Badge, so it is the same picture as the jacket
-- that shrank into this spot on the way in and grows out of it on the way back.
local p = ...
local K, S = p.K, p.S

local textX = K.Badge.X + K.Badge.Size/2 + 18
local textWidth = K.W - 40 - textX - 160   -- clear of the menu timer

local af = Def.ActorFrame{
	Name="Header",
	RefreshCommand=function(self)
		local course = S.IsCourseMode()
		local pack = course and K.String("Courses") or S.Pack()
		K.SetLabel(self:GetChild("Pack"), tostring(pack):upper(), 20, textWidth)
		local index, total = S.Position()
		K.SetLabel(self:GetChild("Position"),
			index and string.format("%02d / %02d", index, total) or "", 13)

		local badge = self:GetChild("Badge")
		badge:visible(not course and pack ~= "")
		if not course and pack ~= badge.group then
			badge:playcommand("SetPack", { Group = pack ~= "" and pack or nil })
			badge:playcommand("LoadPackArt")
		end
	end,
	SongWheelInCommand=function(self)
		for _, name in ipairs({ "Pack", "Position" }) do
			self:GetChild(name):stoptweening():diffusealpha(0):sleep(0.14):linear(0.2):diffusealpha(1)
		end
	end,
	SongWheelOutCommand=function(self)
		for _, name in ipairs({ "Pack", "Position" }) do
			self:GetChild(name):stoptweening():linear(0.12):diffusealpha(0)
		end
	end,
}

af[#af+1] = LoadActor(THEME:GetPathB("ScreenVOLT26SelectPack", "overlay/Tile.lua"), { K=K, Name="Badge" })..{
	InitCommand=function(self)
		self.group, self.loadedGroup, self.artPending = nil, nil, false
		self:xy(K.Badge.X, K.Badge.Y):zoom(K.Badge.Size / K.TileSize)
		-- As the focused jacket: no name plate, no frame.
		self:GetChild("Body"):GetChild("Plate"):diffusealpha(0)
	end,
}
af[#af+1] = K.Text{ Name="Pack", Px=20, Tint=K.Ink, X=textX, Y=38 }
af[#af+1] = K.Text{ Name="Position", Px=13, Tint=K.Mute, X=textX, Y=72 }

return af
