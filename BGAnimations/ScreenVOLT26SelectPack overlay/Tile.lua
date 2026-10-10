-- One pack jacket: a square with the pack's artwork and a name plate.
--
-- Used by the pack carousel (one tile per pool slot) and by the song wheel
-- header, where the chosen pack sits as a small badge.  Both build it at the
-- full carousel size and zoom it, so the jacket that shrinks into the header
-- and the badge it becomes are the same picture.
--
-- Commands:
--   SetPack {Group=<name or nil>}  show a pack; artwork is reset if it changed
--   LoadPackArt                    load the shown pack's artwork now
-- The tile keeps .group, .loadedGroup and .artPending on itself so the
-- carousel can decide when artwork is worth loading.
local params = ...
local K = params.K
local size = params.Size or K.TileSize
local plateHeight = 64
local PackSelection = VOLT26.PackSelection

local body = Def.ActorFrame{ Name="Body" }

body[#body+1] = K.Rule{ Name="Stroke", AlignX=0.5, AlignY=0.5, Width=size+4, Height=size+4, Tint=K.Line }
body[#body+1] = K.Rule{ Name="Ground", AlignX=0.5, AlignY=0.5, Width=size, Height=size, Tint=K.Panel2 }

-- Stands in for packs without artwork, and for any pack until its artwork has
-- been loaded.
body[#body+1] = K.Text{ Name="Initials", Role="Display", Px=150, Tint=K.Dim, Align=center, Width=size-60 }

-- A banner-only pack shows its banner twice: cropped and dimmed to fill the
-- square, and whole across the middle of it.
body[#body+1] = Def.Sprite{ Name="Fill", InitCommand=function(self) self:visible(false) end }
body[#body+1] = Def.Sprite{ Name="Art", InitCommand=function(self) self:visible(false) end }

local plate = Def.ActorFrame{
	Name="Plate",
	InitCommand=function(self) self:y(size/2 - plateHeight/2) end,
}
plate[#plate+1] = K.Rule{ AlignX=0.5, AlignY=0.5, Width=size, Height=plateHeight, Tint=K.Bg, Alpha=0.85 }
plate[#plate+1] = K.Text{ Name="Name", Px=20, Tint=K.Ink, Align=center }
body[#body+1] = plate

-- The focused tile's frame.
local frame = K.Outline{ Name="Frame", Width=size+16, Height=size+16, Stroke=6, Tint=K.Accent }
frame.InitCommand = function(self) self:visible(false) end
body[#body+1] = frame

return Def.ActorFrame{
	Name=params.Name,
	InitCommand=function(self)
		self.group, self.loadedGroup, self.artPending = nil, nil, false
	end,
	SetPackCommand=function(self, p)
		local group = p and p.Group or nil
		self.group = group
		local b = self:GetChild("Body")
		K.SetLabel(b:GetChild("Plate"):GetChild("Name"), (group or ""):upper(), 20, size - 48)
		b:GetChild("Initials"):settext(group and K.Initials(group) or "")
		if self.loadedGroup ~= group then
			b:GetChild("Art"):visible(false)
			b:GetChild("Fill"):visible(false)
			self.loadedGroup = nil
			self.artPending = group ~= nil
		end
	end,
	LoadPackArtCommand=function(self)
		self.artPending = false
		self.loadedGroup = self.group
		local b = self:GetChild("Body")
		local art, fill = b:GetChild("Art"), b:GetChild("Fill")
		art:visible(false)
		fill:visible(false)
		if not self.group then return end

		local info = PackSelection.Artwork(self.group)
		if not info then return end
		if info.Kind == "Jacket" then
			if K.LoadStill(art, info.Path) then
				K.Cover(art, size, size)
				art:visible(true)
			end
		else
			if K.LoadStill(fill, info.Path, "Banner") then
				K.Cover(fill, size, size)
				fill:diffusealpha(0.28):visible(true)
			end
			if K.LoadStill(art, info.Path, "Banner") then
				K.Contain(art, size - 40, size - 40)
				art:visible(true)
			end
		end
	end,
	body,
}
