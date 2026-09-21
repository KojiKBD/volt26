-- VOLT26 CORE: Input diagnostics.
-- Loaded after SL_Init.lua, which creates the VOLT26 namespace and state.

VOLT26.InputDiagnostics = {
	VisualGames = {dance=true, pump=true, techno=true},
}

local function InputDiagnosticEnumKey(value)
	if value == nil then return "" end
	local ok, key = pcall(ToEnumShortString, value)
	return ok and tostring(key) or tostring(value)
end

function VOLT26.InputDiagnostics.SupportsPadVisuals(gameName)
	if type(gameName) ~= "string" then
		local game = GAMESTATE:GetCurrentGame()
		gameName = game and game:GetName() or ""
	end
	return VOLT26.InputDiagnostics.VisualGames[gameName] == true
end

function VOLT26.InputDiagnostics.ShouldBroadcast(event)
	return type(event) == "table"
		and type(event.button) == "string"
		and event.type ~= "InputEventType_Repeat"
end

function VOLT26.InputDiagnostics.ShouldDismiss(event)
	return VOLT26.InputDiagnostics.ShouldBroadcast(event)
		and event.type == "InputEventType_FirstPress"
		and (event.GameButton == "Start" or event.GameButton == "Back")
end

function VOLT26.InputDiagnostics.UsesControllerRouting()
	local style = GAMESTATE:GetCurrentStyle()
	local styleType = style and style:GetStyleType() or nil
	return styleType == "StyleType_OnePlayerTwoSides"
		or styleType == "StyleType_TwoPlayersSharedSides"
end

function VOLT26.InputDiagnostics.IsEventForPlayer(event, player)
	if type(event) ~= "table" or player == nil then return false end
	if VOLT26.InputDiagnostics.UsesControllerRouting() then
		return GameController:Reverse()[event.controller] == PlayerNumber:Reverse()[player]
	end
	return event.PlayerNumber == player
end

function VOLT26.InputDiagnostics.IsEventFromActiveInput(event)
	if type(event) ~= "table" then return false end
	if VOLT26.InputDiagnostics.UsesControllerRouting() then
		return event.controller ~= nil
	end
	return event.PlayerNumber ~= nil and GAMESTATE:IsSideJoined(event.PlayerNumber)
end

function VOLT26.InputDiagnostics.GetSourceKey(event)
	if type(event) ~= "table" then return nil end
	local deviceInput = event.DeviceInput or {}
	local device = InputDiagnosticEnumKey(deviceInput.device)
	local button = InputDiagnosticEnumKey(deviceInput.button)
	if device ~= "" or button ~= "" then return device..":"..button end
	return table.concat({
		InputDiagnosticEnumKey(event.controller),
		InputDiagnosticEnumKey(event.PlayerNumber),
		tostring(event.button or ""),
	}, ":")
end

function VOLT26.InputDiagnostics.UpdateHeldSources(held, event)
	if type(held) ~= "table" or not VOLT26.InputDiagnostics.ShouldBroadcast(event) then
		return false
	end
	local source = VOLT26.InputDiagnostics.GetSourceKey(event)
	if not source then return next(held) ~= nil end
	if event.type == "InputEventType_FirstPress" then
		held[source] = true
	elseif event.type == "InputEventType_Release" then
		held[source] = nil
	end
	return next(held) ~= nil
end

function VOLT26.InputDiagnostics.GetHeldLabels(held)
	local labels = {}
	if type(held) ~= "table" then return labels end
	for key in pairs(held) do labels[#labels + 1] = key end
	table.sort(labels)
	return labels
end
