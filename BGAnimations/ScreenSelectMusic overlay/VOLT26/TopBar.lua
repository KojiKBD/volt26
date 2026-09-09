local H = ...

local middleY = H.TopBarH/2
-- In paid mode the band's right-hand slot belongs to the menu timer instead of
-- the clock: the number that is running out matters more than the time of day.
local showPaidTimer = VOLT26.MenuTimer.IsPaidMode()
local clockSize = showPaidTimer and 22 or 12

local function modeText()
	local style = GAMESTATE:GetCurrentStyle()
	local styleName = style and style:GetName() or ""
	local humans = #GAMESTATE:GetHumanPlayers()
	return string.format("%s / %s", styleName:upper(), humans > 1 and "VERSUS" or "SOLO")
end

local function positionText()
	local pack = H.Pack():upper()
	local index, total = H.PackPosition()
	if total == 0 then return pack end
	return string.format("%s - %02d / %02d", pack, index, total)
end

local function menuTimerSeconds()
	local screen = SCREENMAN:GetTopScreen()
	local timer = screen and screen:GetChild("Timer")
	local seconds = timer and timer:GetSeconds()
	if seconds then return math.max(0, math.ceil(seconds)) end
	return nil
end

local af = Def.ActorFrame{
	Name="TopBar",
	RefreshCommand=function(self)
		H.SetLabel(self:GetChild("Mode"), modeText(), 12, 420)
		-- The clock is the anchor on the right; the group readout is measured
		-- back from it so a long pack name can never push it off the band.
		local position = self:GetChild("Position")
		position:x(H.W - H.Pad - self:GetChild("Clock"):GetZoomedWidth() - 28)
		H.SetLabel(position, positionText(), 12, 560)
	end,
	ClockCommand=function(self)
		H.SetLabel(self:GetChild("Clock"), string.format("%02d:%02d", Hour(), Minute()), clockSize)
		self:queuecommand("Refresh")
		self:sleep(10):queuecommand("Clock")
	end,
	OnCommand=function(self)
		self:GetChild("Brand"):settext("SELECT")
		if showPaidTimer then
			H.SetDisplay(self:GetChild("Clock"),
				math.max(0, math.ceil(tonumber(SL.Global.MenuTimer.ScreenSelectMusic) or 0)), clockSize)
			self.timerElapsed = 0
			self:SetUpdateFunction(function(frame, delta)
				frame.timerElapsed = frame.timerElapsed + (delta or 0)
				if frame.timerElapsed < 0.10 then return end
				frame.timerElapsed = 0
				local remaining = menuTimerSeconds()
				if remaining and remaining ~= frame.remaining then
					frame.remaining = remaining
					H.SetDisplay(frame:GetChild("Clock"), remaining, clockSize)
					frame:playcommand("Refresh")
				end
			end)
		else
			self:queuecommand("Clock")
		end
		self:queuecommand("Refresh")
	end,
}

af[#af+1] = H.Rule{Name="Divider", Y=H.TopBarH-1, Width=H.W, Height=1}

af[#af+1] = H.LabelText{Name="Brand", Px=30, Tint=H.Ink, X=H.Pad, Y=middleY}
af[#af+1] = H.Rule{Name="BrandRule", AlignX=0.5, AlignY=0.5, X=H.Pad+152, Y=middleY, Width=1, Height=26}
af[#af+1] = H.LabelText{Name="Mode", Px=12, Tint=H.Mute, X=H.Pad+172, Y=middleY}

af[#af+1] = H.LabelText{Name="Position", Px=12, Tint=H.Mute, Align=right, Y=middleY}
af[#af+1] = H.LabelText{
	Name="Clock", Px=clockSize,
	Tint=showPaidTimer and H.Ink or H.Dim, Align=right, X=H.W-H.Pad, Y=middleY,
}

-- AddRefresh installs its own OnCommand, so the one above is chained behind it
-- rather than replaced.
local ownOn = af.OnCommand
H.AddRefresh(af)
local queueRefresh = af.OnCommand
af.OnCommand = function(self)
	queueRefresh(self)
	ownOn(self)
end
return af
