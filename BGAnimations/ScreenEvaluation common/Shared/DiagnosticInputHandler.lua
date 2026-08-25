return function(event)
	if PREFSMAN:GetPreference("OnlyDedicatedMenuButtons")
		and VOLT26.InputDiagnostics.ShouldBroadcast(event) then
		MESSAGEMAN:Broadcast("TestInputEvent", event)
	end
	return false
end
