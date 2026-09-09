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
	OnCommand=function(self)
		self:GetChild("Brand"):settext("SELECT")
		if showPaidTimer then
			H.SetDisplay(self:GetChild("Clock"),
				math.max(0, math.ceil(tonumber(SL.Global.MenuTimer.ScreenSelectMusic) or 0)), clockSize)
		end
		-- The right-hand readout is driven from an update function rather than a
		-- sleep chain: this actor also receives queued Refresh commands, and a
		-- pending multi-second sleep would hold every one of them in the tween
		-- queue until it expired, which overflows it.
		self.tickElapsed = math.huge
		self:SetUpdateFunction(function(frame, delta)
			frame.tickElapsed = frame.tickElapsed + (delta or 0)
			if frame.tickElapsed < (showPaidTimer and 0.10 or 5) then return end
			frame.tickElapsed = 0
			local reading = showPaidTimer and menuTimerSeconds()
				or string.format("%02d:%02d", Hour(), Minute())
			if reading and reading ~= frame.reading then
				frame.reading = reading
				if showPaidTimer then
					H.SetDisplay(frame:GetChild("Clock"), reading, clockSize)
				else
					H.SetLabel(frame:GetChild("Clock"), reading, clockSize)
				end
				frame:playcommand("Refresh")
			end
		end)
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
