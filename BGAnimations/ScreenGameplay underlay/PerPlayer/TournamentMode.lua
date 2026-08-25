local player = ...
VOLT26.Tournament.ApplyPlayerModifiers(player)

return Def.ActorFrame{
	OnCommand=function(self)
		local speed = VOLT26.Tournament.GetForcedSpeed(player)
		if speed then self:GetChild("SpeedNotice"):playcommand("ShowSpeedNotice", {speed=speed}) end
	end,

	LoadFont("Common Normal")..{
		Name="SpeedNotice",
		InitCommand=function(self)
			self:xy(_screen.cx, 105):zoom(0.8):draworder(200):diffuse(Color.Yellow):strokecolor(Color.Black):diffusealpha(0)
		end,
		ShowSpeedNoticeCommand=function(self, params)
			self:settext(("Tournament Mode: C%g forced to M%g"):format(params.speed, params.speed))
				:stoptweening():diffusealpha(1):sleep(6):linear(0.25):diffusealpha(0)
		end,
	}
}
