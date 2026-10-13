-- One pack jacket: a square filled edge to edge with the pack's artwork.
--
-- Used by the pack carousel (one tile per pool slot) and by the song wheel
-- header, where the chosen pack sits as a small badge.  Both build it at the
-- full carousel size and zoom it, so the jacket that shrinks into the header
-- and the badge it becomes are the same picture.
--
-- Commands:
--   SetPack {Group=<name or nil>}  show a pack, or a section of the current sort
--                                  (VOLT26.PackSelection keys); artwork is reset
--                                  if it changed
--   LoadPackArt                    load the shown pack's artwork now
-- The tile keeps .group, .loadedGroup and .artPending on itself so the
-- carousel can decide when artwork is worth loading.
local params = ...
local K = params.K
local size = params.Size or K.TileSize
local PackSelection = VOLT26.PackSelection

local body = Def.ActorFrame{ Name="Body" }

body[#body+1] = K.Rule{ Name="Stroke", AlignX=0.5, AlignY=0.5, Width=size+4, Height=size+4, Tint=K.Line }
body[#body+1] = K.Rule{ Name="Ground", AlignX=0.5, AlignY=0.5, Width=size, Height=size, Tint=K.Panel2 }

-- Stands in for packs without artwork, and for any pack until its artwork has
-- been loaded.
body[#body+1] = K.Text{ Name="Initials", Role="Display", Px=150, Tint=K.Dim, Align=center, Width=size-60 }

-- A section of another sort (a letter, a BPM range, a meter...) has no
-- artwork: its tile names it in cutout lettering (project rule: sort titles
-- are always cutout).  The slot stands in theme units, so its frame undoes
-- the design scale the tile is drawn in.
local labelStyle = VOLT26.Cutout.Style("PackTile")
local labelZoom = size / K.TileSize
body[#body+1] = Def.ActorFrame{
	Name="Label",
	InitCommand=function(self) self:zoom(1 / K.Scale):visible(false) end,
	VOLT26.Cutout.CreateSlot{
		maxW = labelStyle.maxW * labelZoom, maxH = labelStyle.maxH * labelZoom,
		halign = 0.5, valign = 0.5, maxChars = labelStyle.maxChars,
		opts = labelStyle.opts,
		fallbackZoom = VOLT26.Type.DisplayZoom(100 * K.Scale),
	}..{ Name="Slot" },
}

-- The artwork always fills the whole square: a jacket is cropped to it, and a
-- banner-only pack has its banner cropped to the square as well.
body[#body+1] = Def.Sprite{ Name="Art", InitCommand=function(self) self:visible(false) end }

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
		-- A section has no artwork: its tile shows what it stands for (a
		-- letter, a BPM range, a meter...); a pack shows its initials until
		-- its artwork loads.
		local section = group and PackSelection.ShortName(group) or nil
		b:GetChild("Initials"):settext(section and "" or (group and K.Initials(group) or ""))
		local label = b:GetChild("Label")
		label:visible(section ~= nil)
		if section then label:GetChild("Slot"):playcommand("CutoutSet", { text = section }) end
		if self.loadedGroup ~= group then
			b:GetChild("Art"):visible(false)
			self.loadedGroup = nil
			self.artPending = group ~= nil
		end
	end,
	LoadPackArtCommand=function(self)
		self.artPending = false
		self.loadedGroup = self.group
		local b = self:GetChild("Body")
		local art = b:GetChild("Art")
		art:visible(false)
		if not self.group then return end

		local info = PackSelection.Artwork(self.group)
		if not info then return end
		-- Loaded whole, not from the small banner cache: a banner cropped to the
		-- square is enlarged far past the cached copy's resolution.
		if K.LoadStill(art, info.Path) then
			K.Cover(art, size, size)
			art:visible(true)
		end
	end,
	body,
}
