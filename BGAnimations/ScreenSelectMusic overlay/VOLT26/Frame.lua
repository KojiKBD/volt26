local H = ...
local showPaidTimer = VOLT26.MenuTimer.IsPaidMode()

local function updatePaidTimer(self, delta)
	self.updateElapsed = (self.updateElapsed or 0) + (delta or 0)
	if self.updateElapsed < 0.05 then return end
	self.updateElapsed = 0
	local screen = SCREENMAN:GetTopScreen()
	local timer = screen and screen:GetChild("Timer")
	local seconds = timer and timer:GetSeconds()
	if seconds then
		local display = math.max(0, math.ceil(seconds))
		if display ~= self.lastDisplay then
			self.lastDisplay = display
			self:settext(display)
		end
	end
end

return Def.ActorFrame{
	Name="Frame",
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
			local initial = tonumber(SL.Global.MenuTimer.ScreenSelectMusic) or 0
			self:xy(427,39):horizalign(center):vertalign(middle):zoom(0.72)
				:maxwidth(180/0.72):shadowlength(0):diffuse(H.Black):draworder(110)
				:settext(math.max(0,math.ceil(initial))):visible(showPaidTimer)
		end,
		OnCommand=function(self)
			if showPaidTimer then self:SetUpdateFunction(updatePaidTimer) end
		end,
	},
}
