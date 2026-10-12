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
	-- Arriving: the tag drops from above the screen and settles.
	OnCommand=function(self)
		self:stoptweening():y(-220):rotationz(-6):sleep(0.22)
			:decelerate(0.22):y(10):rotationz(1):decelerate(0.08):y(0):rotationz(0)
	end,
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

	P.CutoutSlot{ Name="Name", Id="Pack", X=X, Y=Y, Scale=K.Scale },
	P.Text{ Name="Line", Cap=13, Condense=0.85, Align=0.5, X=X, Baseline=Y + MAX_H / 2 + 30, Width=MAX_W },
}
