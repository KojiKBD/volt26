-- The open pack's name in cutout lettering on the red at the top, with the
-- song's place in the pack and the play mode under it (the old song wheel's
-- header line).
local p = ...
local K, S = p.K, p.S
local P = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/P5.lua"))

local X, Y = 1210, 66
local MAX_W, MAX_H = 340, 76

return Def.ActorFrame{
	Name="PackTag",
	RefreshCommand=function(self)
		local course = S.IsCourseMode()
		local pack = course and K.String("Courses") or S.Pack()
		if self.pack ~= pack then
			self.pack = pack
			P.SetCutout(self:GetChild("Name"), pack)
		end
		local index, total = S.Position()
		local line = K.ModeText()
		if index then line = ("%02d / %02d     %s"):format(index, total, line) end
		self:GetChild("Line"):settext(line)
	end,

	P.CutoutSlot{ Name="Name", X=X, Y=Y, MaxW=MAX_W, MaxH=MAX_H, Base=44, Tilt=-4,
		HAlign=0.5, VAlign=0.5, MaxChars=40, Scale=K.Scale },
	P.Text{ Name="Line", Cap=13, Condense=0.85, Align=0.5, X=X, Baseline=Y + MAX_H / 2 + 30, Width=MAX_W },
}
