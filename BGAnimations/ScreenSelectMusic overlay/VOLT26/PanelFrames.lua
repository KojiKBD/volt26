local args = ...
local H = args.H
-- "Tab" is the block that reaches up into the song header; "Frame" is the
-- border around the column.  They are the two halves of one image, drawn at
-- different depths: the tab stays behind the header's text, the frame goes over
-- the column panels so its edges overlap their borders as in the mockup.
local part = args.Part

-- The angular frames that wrap each player's column.  The artwork is one image
-- per side: left_ss is authored in P1's red, right_ss is authored white so it
-- can take P2's accent.
--
-- The rectangle below maps the artwork onto the design space so that, as in the
-- owner's mockup, the frame stands wholly outside the column (H.LeftX ..
-- H.LeftX+H.ColumnW, H.InnerTop .. H.ColumnBottom): its top line just above the
-- column, its slanted left edge never inside it (the edge is widest at the
-- top-left, source column 69), its right edge just outside the column's right
-- side (source column 585), and its sloping bottom line below the column's
-- outer corner (source row 770).  Only the small top-right chamfer cuts the
-- column's corner, as it does in the mockup.
-- The right frame is the exact mirror of the left one about the screen centre,
-- because the right column is the left one's mirror.
local frame = {
	X = H.LeftX - 81,
	Y = H.InnerTop - 152,
	Width = 690,
	Height = 1010,
}

-- The source row where the tab ends and the frame's top line begins, as a
-- fraction of the image height (row 108 of 849).
local split = 108/849

local function sprite(name, file, x, tint)
	return Def.Sprite{
		Name=name,
		Texture=THEME:GetPathG("", "VOLT26/"..file),
		InitCommand=function(self)
			self:align(0,0):xy(x, frame.Y):zoomto(frame.Width, frame.Height)
			if part == "Tab" then self:cropbottom(1 - split) else self:croptop(split) end
			if tint then self:diffuse(tint) end
		end,
	}
end

return Def.ActorFrame{
	Name="PanelFrames"..part,
	-- Hidden with the columns while a modal overlay owns the screen.
	VOLT26ModalOverlayOpenedMessageCommand=function(self) self:visible(false) end,
	VOLT26ModalOverlayClosedMessageCommand=function(self) self:visible(true) end,
	sprite("Left", "left_ss.png", frame.X),
	sprite("Right", "right_ss.png", H.W - frame.X - frame.Width, H.P2),
}
