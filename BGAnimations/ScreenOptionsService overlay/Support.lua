local function ValidateEnvironment()
	local supported, message = VOLT26.Compatibility.CheckCurrent()
	if supported then return true end
	VOLT26.Util.SystemMessage(message)
	return false
end

local function InputHandler(event)
	if not event or event.type ~= "InputEventType_FirstPress" or event.GameButton ~= "Back" then
		return false
	end
	if ValidateEnvironment() then SCREENMAN:GetTopScreen():Cancel() end
	return true
end

return Def.Actor{
	BeginCommand=function(self)
		VOLT26.ThemePrefs.Save()
		-- Rebuild localized rows after returning from engine language options.
		SL_CustomPrefs.Init()
		SCREENMAN:GetTopScreen():AddInputCallback(InputHandler)
		MESSAGEMAN:Broadcast("VOLT26OperatorOptionsChanged")
	end,
	OffCommand=function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen.RemoveInputCallback then screen:RemoveInputCallback(InputHandler) end
		if screen:AllAreOnLastRow() and not ValidateEnvironment() then
			SCREENMAN:SetNewScreen("ScreenSystemOptions")
		end
	end,
}
