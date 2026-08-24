return function(event)
	if PREFSMAN:GetPreference("OnlyDedicatedMenuButtons")
		and event and event.type ~= "InputEventType_Repeat" then
		MESSAGEMAN:Broadcast("TestInputEvent", event)
	end
	return false
end
