-- Top band: the screen title and play mode over the details column, and the
-- open pack with the song's place in it over the wheel.  The band is opaque
-- so wheel rows scrolling under it disappear cleanly.
local p = ...
local K, S = p.K, p.S
local G = VOLT26.MusicSelection.Wheel

local bandHeight = 96

local af = Def.ActorFrame{
	Name="Header",
	RefreshCommand=function(self)
		K.SetLabel(self:GetChild("Mode"), S.ModeText(), 12, 860)
		local pack = S.IsCourseMode() and K.String("Courses") or S.Pack()
		K.SetLabel(self:GetChild("Pack"), tostring(pack):upper(), 20, G.Width - 200)
		local index, total = S.Position()
		K.SetLabel(self:GetChild("Position"),
			index and string.format("%02d / %02d", index, total) or "", 13)
	end,
}

af[#af+1] = K.Rule{ Name="Band", X=-K.W, Width=K.W*3, Height=bandHeight, Tint=K.Bg, Alpha=0.94 }
af[#af+1] = K.Rule{ Name="Divider", Y=bandHeight-1, Width=K.W, Height=1 }
af[#af+1] = K.Rule{ Name="Mark", X=40, Y=26, Width=6, Height=44, Tint=K.Accent }
af[#af+1] = K.Text{ Name="Title", Px=30, Tint=K.Ink, X=62, Y=38,
	Text=K.String(GAMESTATE:IsCourseMode() and "CourseTitle" or "SongTitle") }
af[#af+1] = K.Text{ Name="Mode", Px=12, Tint=K.Dim, X=62, Y=72 }
af[#af+1] = K.Text{ Name="Pack", Px=20, Tint=K.Ink, X=G.X, Y=38 }
af[#af+1] = K.Text{ Name="Position", Px=13, Tint=K.Mute, X=G.X, Y=72 }

return af
