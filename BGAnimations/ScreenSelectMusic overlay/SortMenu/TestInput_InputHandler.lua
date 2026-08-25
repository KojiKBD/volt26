-- this handles user input while in SelectMusic's TestInput overlay
local function input(event)
	if not VOLT26.InputDiagnostics.ShouldBroadcast(event) then
		return false
	end
	if not VOLT26.InputDiagnostics.IsEventFromActiveInput(event) then
		return false
	end

	SOUND:StopMusic()

	local screen   = SCREENMAN:GetTopScreen()
	local overlay  = screen:GetChild("Overlay")

	-- broadcast event data using MESSAGEMAN for the TestInput overlay to listen for
	MESSAGEMAN:Broadcast("TestInputEvent", event)

	-- pressing Start or Back (typically Esc on a keyboard) will queue "DirectInputToEngine"
	-- but only if the event.type is not a Release
	-- as soon as TestInput is activated via the SortMenu, the player is likely still holding Start
	-- and will soon release it to start testing their input, which would inadvertently close TestInput
	if VOLT26.InputDiagnostics.ShouldDismiss(event) then
		overlay:queuecommand("DirectInputToEngine")
	end

	return false
end

return input
