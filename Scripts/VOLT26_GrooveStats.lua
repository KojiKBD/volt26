-- VOLT26 CORE: GrooveStats service capabilities and identity, event payloads, and the event-download registry.
-- Loaded after SL_Init.lua, which creates the VOLT26 namespace and state.

local GrooveStatsCapabilities = {
	GetScores = "playerScores",
	Leaderboard = "playerLeaderboards",
	AutoSubmit = "scoreSubmit",
}

function VOLT26.GrooveStats.ResetCapabilities()
	VOLT26.GrooveStats.IsConnected = false
	for capability in pairs(GrooveStatsCapabilities) do
		VOLT26.GrooveStats[capability] = false
	end
end

function VOLT26.GrooveStats.DecodeResponse(response)
	if type(response) ~= "table" then return nil, "invalid-response" end
	if response.error then return nil, ToEnumShortString(response.error) end
	if response.statusCode ~= 200 then return nil, "http-" .. tostring(response.statusCode or "unknown") end
	if type(response.body) ~= "string" then return nil, "invalid-body" end
	if #response.body > 1024 * 1024 then return nil, "response-too-large" end
	local ok, data = pcall(JsonDecode, response.body)
	if not ok or type(data) ~= "table" then return nil, "invalid-json" end
	return data
end

function VOLT26.GrooveStats.ApplySessionResponse(response)
	VOLT26.GrooveStats.ResetCapabilities()
	local data, err = VOLT26.GrooveStats.DecodeResponse(response)
	if not data then return false, err end
	local services = data.servicesAllowed
	if type(services) ~= "table" then return false, "missing-capabilities" end
	local enabled = 0
	for capability, responseKey in pairs(GrooveStatsCapabilities) do
		local available = services[responseKey] == true
		VOLT26.GrooveStats[capability] = available
		if available then enabled = enabled + 1 end
	end
	VOLT26.GrooveStats.IsConnected = enabled > 0
	if enabled == 0 then return false, "no-capabilities" end
	return true, nil
end

function VOLT26.GrooveStats.NormalizeApiKey(value)
	if type(value) ~= "string" or #value ~= 64 or value:find("[%s%c]") then return "" end
	return value
end

function VOLT26.GrooveStats.NormalizeUsername(value)
	if type(value) ~= "string" then return "" end
	return value:gsub("[%c]", ""):sub(1, 64)
end

function VOLT26.GrooveStats.SetPlayerIdentity(player, apiKey, username, isPadPlayer)
	local state = VOLT26.Core.GetPlayerState(player)
	if not state then return false end
	state.ApiKey = VOLT26.GrooveStats.NormalizeApiKey(apiKey)
	state.GrooveStatsUsername = VOLT26.GrooveStats.NormalizeUsername(username)
	state.IsPadPlayer = isPadPlayer == true or isPadPlayer == 1 or isPadPlayer == "1"
	return true
end

function VOLT26.GrooveStats.GetProfilePath(player)
	local slot = player == PLAYER_1 and "ProfileSlot_Player1"
		or player == PLAYER_2 and "ProfileSlot_Player2" or nil
	if not slot then return nil end
	local directory = PROFILEMAN:GetProfileDir(slot)
	if type(directory) ~= "string" or directory == "" then return nil end
	return directory .. "GrooveStats.ini"
end

function VOLT26.GrooveStats.SavePlayerIdentity(player)
	local path = VOLT26.GrooveStats.GetProfilePath(player)
	local state = VOLT26.Core.GetPlayerState(player)
	if not path or not state then return false end
	VOLT26.GrooveStats.SetPlayerIdentity(player, state.ApiKey, state.GrooveStatsUsername, state.IsPadPlayer)
	IniFile.WriteFile(path, {GrooveStats={
		ApiKey=state.ApiKey,
		Username=state.GrooveStatsUsername,
		IsPadPlayer=state.IsPadPlayer and "1" or "0",
	}})
	return true
end

function VOLT26.GrooveStats.LoadPlayerIdentity(player)
	local path = VOLT26.GrooveStats.GetProfilePath(player)
	if not path then return false end
	local contents = FILEMAN:DoesFileExist(path) and (IniFile.ReadFile(path) or {}) or {}
	local section = type(contents.GrooveStats) == "table" and contents.GrooveStats or {}
	VOLT26.GrooveStats.SetPlayerIdentity(player, section.ApiKey, section.Username, section.IsPadPlayer)
	return VOLT26.GrooveStats.SavePlayerIdentity(player)
end

function VOLT26.GrooveStats.HasAnyApiKey()
	return VOLT26.GrooveStats.NormalizeApiKey(VOLT26.State.P1.ApiKey) ~= ""
		or VOLT26.GrooveStats.NormalizeApiKey(VOLT26.State.P2.ApiKey) ~= ""
end

function VOLT26.GrooveStats.IsConditionAllowed(condition)
	if condition ~= true
		or VOLT26.ThemePrefs.Get("EnableGrooveStats") ~= true
		or not VOLT26.GrooveStats.IsConnected
		or not VOLT26.GrooveStats.HasAnyApiKey()
		or VOLT26.Gameplay.GetMode() ~= "ITG" then
		return false
	end
	local game = GAMESTATE:GetCurrentGame()
	local gameName = game and game:GetName() or ""
	return gameName == "dance" or gameName == "pump"
end

function VOLT26.GrooveStats.IsServiceAllowed(capability)
	local condition = type(capability) == "string" and VOLT26.GrooveStats[capability] or capability
	return VOLT26.GrooveStats.IsConditionAllowed(condition)
end

VOLT26.Events = {}

local function NormalizeEventPayload(payload)
	if type(payload) ~= "table" or type(payload.name) ~= "string" then return nil end
	local name = payload.name:gsub("[%c]", ""):sub(1, 96)
	if name == "" then return nil end
	local normalized = DeepCopy(payload)
	normalized.name = name
	if normalized.result ~= nil and type(normalized.result) ~= "string" then return nil end
	if type(normalized.result) == "string" then
		normalized.result = normalized.result:gsub("[%c]", ""):sub(1, 64)
	end
	return normalized
end

function VOLT26.Events.NormalizePlayerData(playerData)
	local events = {}
	if type(playerData) ~= "table" then return events end
	for _, eventType in ipairs({"rpg", "itl"}) do
		local payload = NormalizeEventPayload(playerData[eventType])
		if payload then events[eventType] = payload end
	end
	return events
end

VOLT26.Downloads.States = {
	queued=true, downloading=true, verifying=true, extracting=true,
	completed=true, failed=true, cancelled=true,
}

-- Event unlock downloads follow the operator's GrooveStats settings and only
-- run while the service session is connected.
function VOLT26.Downloads.IsTransportEnabled()
	return VOLT26.ThemePrefs.Get("EnableGrooveStats") == true
		and VOLT26.ThemePrefs.Get("AutoDownloadUnlocks") == true
		and VOLT26.GrooveStats.IsConnected == true
end

function VOLT26.Downloads.NormalizeJob(id, raw)
	if type(raw) ~= "table" then return nil end
	local total = math.max(0, tonumber(raw.TotalBytes) or 0)
	local current = math.max(0, tonumber(raw.CurrentBytes) or 0)
	if total > 0 then current = math.min(current, total) end
	local state = type(raw.State) == "string" and raw.State:lower() or nil
	if not VOLT26.Downloads.States[state] then
		if raw.Complete then state = raw.ErrorMessage and "failed" or "completed"
		else state = "downloading" end
	end
	return {
		Id=tostring(id or ""),
		Name=type(raw.Name) == "string" and raw.Name or "Download",
		CurrentBytes=current,
		TotalBytes=total,
		State=state,
		Complete=state == "completed" or state == "failed" or state == "cancelled",
		ErrorMessage=type(raw.ErrorMessage) == "string" and raw.ErrorMessage or nil,
	}
end

function VOLT26.Downloads.Snapshot()
	local snapshot = {}
	for id, raw in pairs(VOLT26.Downloads.Registry) do
		local job = VOLT26.Downloads.NormalizeJob(id, raw)
		if job then snapshot[#snapshot + 1] = job end
	end
	table.sort(snapshot, function(a, b) return a.Id < b.Id end)
	return snapshot
end

function VOLT26.Downloads.GetCounts(snapshot)
	local finished = 0
	for _, job in ipairs(snapshot or {}) do
		if job.Complete then finished = finished + 1 end
	end
	return finished, #(snapshot or {})
end
