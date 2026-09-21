-- VOLT26 CORE: Tournament Mode, local ITL gate, and custom-song support.
-- Loaded after SL_Init.lua, which creates the VOLT26 namespace and state.

VOLT26.Tournament = {}
local TournamentForcedSpeed = {}

function VOLT26.Tournament.IsEnabled()
	return ThemePrefs.Get("EnableTournamentMode") == true
end

function VOLT26.Tournament.GetScoringSystem()
	return ThemePrefs.Get("ScoringSystem") == "ITG" and "ITG" or "EX"
end

function VOLT26.Tournament.ShouldShowStepStats(player)
	return VOLT26.Core.GetPlayerState(player).ActiveModifiers.DataVisualizations == "Step Statistics"
end

function VOLT26.Tournament.ApplyPlayerModifiers(player)
	local modifiers = VOLT26.Core.GetPlayerState(player).ActiveModifiers
	if VOLT26.Tournament.IsEnabled() then
		modifiers.ShowExScore = VOLT26.Tournament.GetScoringSystem() == "EX"
		modifiers.ShowFaPlusPane = true
		VOLT26.Core.GetPlayerState(player).EvalPanePrimary = 2
	end
	return modifiers
end

function VOLT26.Tournament.SongForbidsCMod(song)
	if not song then return false end
	local labels = {
		song:GetDisplayFullTitle(), song:GetTranslitFullTitle(),
		song:GetDisplaySubTitle(), song:GetTranslitSubTitle(),
	}
	for _, label in ipairs(labels) do
		if type(label) == "string" and label:lower():find("no cmod", 1, true) then return true end
	end
	return false
end

function VOLT26.Tournament.GetCModViolation(player)
	if not VOLT26.Tournament.IsEnabled() or ThemePrefs.Get("EnforceNoCmod") ~= true then return nil end
	local modifiers = VOLT26.Core.GetPlayerState(player).ActiveModifiers
	if modifiers.SpeedModType ~= "C" or not VOLT26.Tournament.SongForbidsCMod(GAMESTATE:GetCurrentSong()) then return nil end
	return modifiers.SpeedMod
end

function VOLT26.Tournament.PreparePlayer(player)
	local pn = ToEnumShortString(player)
	local speed = VOLT26.Tournament.GetCModViolation(player)
	if not pn or not speed then return nil end
	TournamentForcedSpeed[pn] = {type="C", speed=speed}
	local modifiers = VOLT26.Core.GetPlayerState(player).ActiveModifiers
	modifiers.SpeedModType = "M"
	for _, level in ipairs({"ModsLevel_Preferred", "ModsLevel_Stage", "ModsLevel_Song"}) do
		GAMESTATE:GetPlayerState(player):GetPlayerOptions(level):MMod(speed)
	end
	return speed
end

function VOLT26.Tournament.GetForcedSpeed(player)
	local forced = TournamentForcedSpeed[ToEnumShortString(player)]
	return forced and forced.speed or nil
end

function VOLT26.Tournament.RestorePlayer(player)
	local pn = ToEnumShortString(player)
	local forced = pn and TournamentForcedSpeed[pn] or nil
	if not forced then return false end
	local modifiers = VOLT26.Core.GetPlayerState(player).ActiveModifiers
	modifiers.SpeedModType = forced.type
	modifiers.SpeedMod = forced.speed
	GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred"):CMod(forced.speed)
	VOLT26.Core.GetPlayerState(player).PlayerOptionsString =
		GAMESTATE:GetPlayerState(player):GetPlayerOptionsString("ModsLevel_Preferred")
	TournamentForcedSpeed[pn] = nil
	return true
end

function VOLT26.Tournament.RestoreAllPlayers()
	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		VOLT26.Tournament.RestorePlayer(player)
	end
end

-- Local ITL records follow the inherited Simply Love implementation
-- (Scripts/SL_ITL.lua): per-profile ITL files, event points, and unlocks.
function VOLT26.Tournament.IsLocalItlEnabled()
	return true
end

VOLT26.CustomSongs = {}

function VOLT26.CustomSongs.IsSupported()
	return PREFSMAN:PreferenceExists("CustomSongsEnable")
end
