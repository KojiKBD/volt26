-- Restore the active operator row through the VOLT26 options service.
--
-- this applies to any screens that inherit from ScreenOptionsService, including ScreenOptionsServiceSub

local a = Def.Actor{}

a.InitCommand=function(self)
	self:queuecommand("SetActiveOptionRow")
end

-- check if an OptionRow index has been saved for the screen we're currently on.
-- if so, it tells us we've returned here from a sub-screen, and should set the
-- active OptionRow
a.SetActiveOptionRowCommand=function(self)
	local screen = SCREENMAN:GetTopScreen()
	local row_index = VOLT26.Options.GetOperatorRow(screen:GetName())
	screen:SetOptionRowIndex(GAMESTATE:GetMasterPlayerNumber(), row_index)
end

-- when leaving this screen, save the index of the active OptionRow
a.OffCommand=function(self)
	local screen = SCREENMAN:GetTopScreen()
	VOLT26.Options.RememberOperatorRow(
		screen:GetName(),
		screen:GetCurrentRowIndex(GAMESTATE:GetMasterPlayerNumber()),
		screen:GetNumRows()
	)
end

return a
