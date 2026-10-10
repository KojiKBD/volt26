-- One pack tile of the carousel: a square jacket with a name plate.
--
-- The carousel (default.lua) owns every tile's slot, content and artwork; the
-- tile only declares its actors.  It is built at the focused size and the
-- carousel zooms the side tiles down, so every figure here is the focused
-- jacket's own.
local params = ...
local K = params.K
local size = params.Size
local plateHeight = 64

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
	body,
}
