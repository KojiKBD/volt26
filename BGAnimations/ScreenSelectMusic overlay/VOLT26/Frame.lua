local H = ...
local showPaidTimer = VOLT26.MenuTimer.IsPaidMode()
local paidTimerActor

local function updatePaidTimer(frame, delta)
	frame.updateElapsed = (frame.updateElapsed or 0) + (delta or 0)
	if frame.updateElapsed < 0.05 or not paidTimerActor then return end
	frame.updateElapsed = 0
	local screen = SCREENMAN:GetTopScreen()
	local timer = screen and screen:GetChild("Timer")
	local seconds = timer and timer:GetSeconds()
	if seconds then
		local display = math.max(0, math.ceil(seconds))
		if display ~= frame.lastDisplay then
			frame.lastDisplay = display
			paidTimerActor:settext(display)
		end
	end
end

return Def.ActorFrame{
	Name="Frame",
	OnCommand=function(self)
		if showPaidTimer then self:SetUpdateFunction(updatePaidTimer) end
	end,
	Def.Sprite{
		Name="SelectTitle",
		Texture=THEME:GetPathG("", "VOLT26/Select_B.png"),
		InitCommand=function(self)
			self:align(0.5,0):xy(427,12):scaletoclipped(190,57):visible(not showPaidTimer)
		end,
	},
	LoadFont("_Combo Fonts/VOLT26/VOLT26")..{
		Name="PaidModeTimer",
		InitCommand=function(self)
			paidTimerActor = self
			local initial = tonumber(SL.Global.MenuTimer.ScreenSelectMusic) or 0
			self:xy(427,39):horizalign(center):vertalign(middle):zoom(0.72)
				:maxwidth(180/0.72):shadowlength(0):diffuse(H.Black):draworder(110)
				:settext(math.max(0,math.ceil(initial))):visible(showPaidTimer)
		end,
	},
}
