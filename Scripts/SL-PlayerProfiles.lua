-- It's possible for players to edit their Simply Love UserPrefs.ini file
-- in various ways that might break the theme.  Also, sometimes theme-specific mods
-- are deprecated or change their internal name, leaving old values behind in player profiles
-- that might break the theme as well. Use this table to validate settings read in
-- from and written out to player profiles.
--
-- For now, this table is local to this file, but might be moved into the SL table (or something)
-- in the future to facilitate type checking in ./Scripts/SL-PlayerOptions.lua and elsewhere.

local permitted_profile_settings = {

	----------------------------------
	-- "Main Modifiers"
	-- OptionRows that appear in SL's first page of PlayerOptions

	SpeedModType     = "string",
	SpeedMod         = "number",
	Mini             = "string",
	NoteSkin         = "string",
	-- The chosen variant of a note skin that has them.  Its option row has no
	-- fixed choices, so it is checked against the installed note skins
	-- instead (NoteSkinVariantIsValid).
	NoteSkinVariant  = "string",
	JudgmentGraphic  = "string",
	ComboFont        = "string",
	HoldJudgment     = "string",
	BackgroundFilter = "string",
	NoteFieldOffsetX = "number",
	NoteFieldOffsetY = "number",
	VisualDelay      = "string",

	----------------------------------
	-- "Advanced Modifiers"
	-- OptionRows that appear in SL's second page of PlayerOptions

	HideTargets          = "boolean",
	HideSongBG           = "boolean",
	HideCombo            = "boolean",
	HideLifebar          = "boolean",
	HideScore            = "boolean",
	HideDanger           = "boolean",
	HideComboExplosions  = "boolean",

	LifeMeterType        = "string",
	DataVisualizations   = "string",
	TargetScore          = "number",
	ActionOnMissedTarget = "string",

	MeasureCounter       = "string",
	MeasureCounterLeft   = "boolean",
	MeasureCounterUp     = "boolean",
	HideLookahead        = "boolean",

	MeasureLines         = "string",

	FlashMiss            = "boolean",
	FlashWayOff          = "boolean",
	FlashDecent          = "boolean",
	FlashGreat           = "boolean",
	FlashExcellent       = "boolean",
	FlashFantastic       = "boolean",
	SubtractiveScoring   = "boolean",
	Pacemaker            = "boolean",
	NPSGraphAtTop        = "boolean",
	JudgmentTilt         = "boolean",
	TiltMultiplier       = "number",
	ColumnCues           = "boolean",
	DisplayScorebox      = "boolean",

	ErrorBar             = "string",
	ErrorBarUp           = "boolean",
	ErrorBarMultiTick    = "boolean",
	ErrorBarTrim         = "string",

	ShowFaPlusWindow     = "boolean",
	ShowExScore          = "boolean",
	ShowFaPlusPane       = "boolean",

	HideEarlyDecentWayOffJudgments = "boolean",
	HideEarlyDecentWayOffFlash     = "boolean",

	----------------------------------
	-- Profile Settings without OptionRows
	-- these settings are saved per-profile, but are transparently managed by the theme
	-- they have no player-facing OptionRows

	PlayerOptionsString = "string",
}

-- -----------------------------------------------------------------------

local function NoteSkinVariantIsValid(name)
	local ok, exists = pcall(function() return NOTESKIN:DoesNoteSkinExist(name) end)
	return ok and exists == true
end

local theme_name = THEME:GetThemeDisplayName()
local filename =  theme_name .. " UserPrefs.ini"

-- Importing a profile's settings from the theme it was used with before.
--
-- Simply Love keeps a profile's modifiers in "Simply Love UserPrefs.ini",
-- section [Simply Love]; VOLT26 keeps them in its own file and never read the
-- old one, so a cabinet moving from Simply Love to VOLT26 lost every player's
-- speed mod, note skin, judgment graphic and the rest.  The first time a
-- profile loads under VOLT26 (no LegacyImported flag in its VOLT26 file), the
-- old file's values are copied over -- they win over what VOLT26 may already
-- have saved, which before this import could only be the defaults -- and the
-- VOLT26 file is written at once with the flag set, so it happens once.  The
-- old file is only read, never changed.  Values go through the same checks as
-- VOLT26's own, so settings VOLT26 does not offer are dropped.
local legacy_profile_files = {
	{ file = "Simply Love UserPrefs.ini", section = "Simply Love" },
}
local LEGACY_FLAG = "LegacyImported"

local function ReadLegacyProfile(dir)
	for _, legacy in ipairs(legacy_profile_files) do
		local legacyPath = dir .. legacy.file
		if FILEMAN:DoesFileExist(legacyPath) then
			local ok, ini = pcall(IniFile.ReadFile, legacyPath)
			local contents = ok and type(ini) == "table" and ini[legacy.section] or nil
			if type(contents) == "table" and next(contents) ~= nil then
				return contents, legacyPath
			end
		end
	end
	return nil
end

-- The VOLT26 settings to load for a profile, importing the legacy ones the
-- first time.  Answers a table (possibly empty).
local function ReadProfileSettings(dir)
	local path = dir .. filename
	local current = {}
	if FILEMAN:DoesFileExist(path) then
		current = (IniFile.ReadFile(path) or {})[theme_name] or {}
	end
	if current[LEGACY_FLAG] then return current end

	local legacy, legacyPath = ReadLegacyProfile(dir)
	if not legacy then return current end

	local merged = {}
	for k, v in pairs(current) do merged[k] = v end
	local imported = 0
	for k, v in pairs(legacy) do
		if permitted_profile_settings[k] and type(v) == permitted_profile_settings[k] then
			merged[k] = v
			imported = imported + 1
		end
	end
	merged[LEGACY_FLAG] = true
	IniFile.WriteFile(path, {[theme_name] = merged})
	Trace(("VOLT26: imported %d profile setting(s) from %s"):format(imported, legacyPath))
	return merged
end


-- Function called when a [GUEST] joins during SSM, either by late joining or via the fast
-- profile switcher. It does two things:
-- 1) properly reset profile state (e.g. modifiers), and
-- 2) persist any state that should survive a profile switch (e.g., session history
--    in SL[pn].Stages with songs played for displaying on ScreenEvaluationSummary).
-- LoadProfileCustom takes care of this for persistent profiles.
LoadGuest = function(player)
	GAMESTATE:ResetPlayerOptions(player)
	local pn = ToEnumShortString(player)
	local stages = SL[pn].Stages
	SL[pn]:initialize()
	SL[pn].Stages = stages
end


-- function assigned to "CustomLoadFunction" under [Profile] in metrics.ini
LoadProfileCustom = function(profile, dir)
	local path =  dir .. filename
	local player, pn, filecontents

	-- we've been passed a profile object as the variable "profile"
	-- see if it matches against anything returned by PROFILEMAN:GetProfile(player)
	for p in ivalues( GAMESTATE:GetHumanPlayers() ) do
		if profile == PROFILEMAN:GetProfile(p) then
			player = p
			pn = ToEnumShortString(p)
			break
		end
	end

	if pn then
		-- Remember and persist stats about songs played across profile switches
		local stages = SL[pn].Stages

		SL[pn]:initialize()
		ParseGrooveStatsIni(player)
		if VOLT26.Tournament.IsLocalItlEnabled() then ReadItlFile(player) end

		SL[pn].Stages = stages
	end

	if pn then
		filecontents = ReadProfileSettings(dir)

		-- for each key/value pair read in from the player's profile
		for k,v in pairs(filecontents) do
			-- ensure that the key has a corresponding key in permitted_profile_settings
			if permitted_profile_settings[k]
			--  ensure that the datatype of the value matches the datatype specified in permitted_profile_settings
			and type(v)==permitted_profile_settings[k] then
				-- if the datatype is string and this key corresponds with an OptionRow in ScreenPlayerOptions
				-- ensure that the string read in from the player's profile
				-- is a valid value (or choice) for the corresponding OptionRow
				if k == "NoteSkinVariant" then
					if NoteSkinVariantIsValid(v) then SL[pn].ActiveModifiers[k] = v end
				elseif type(v) == "string" and CustomOptionRow(k) and FindInTable(v, CustomOptionRow(k).Values or CustomOptionRow(k).Choices)
				or type(v) ~= "string" then
					SL[pn].ActiveModifiers[k] = v
				end

				-- special-case PlayerOptionsString for now
				-- it is saved to and read from profile as a string, but doesn't have a corresponding
				-- OptionRow in ScreenPlayerOptions, so it will fail validation above
				-- we want engine-defined mods (e.g. dizzy) to be applied as well, not just SL-defined mods
				if k=="PlayerOptionsString" and type(v)=="string" then
					-- v here is the comma-delimited set of modifiers the engine's PlayerOptions interface understands

					-- use the engine's SetPlayerOptions() method to set a whole bunch of mods in the engine all at once
					GAMESTATE:GetPlayerState(player):SetPlayerOptions("ModsLevel_Preferred", v)
					-- Special case timing windows as they're not controllable in SL.
					GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred"):ResetDisabledTimingWindows()

					-- However! It's quite likely that a FailType mod could be in that^ string, meaning a player could
					-- have their own setting for FailType saved to their profile.  I think it makes more sense to let
					-- machine operators specify a default FailType at a global/machine level, so use this opportunity to
					-- use the PlayerOptions interface to set FailSetting() using the default FailType setting from
					-- the operator menu's Advanced Options
					GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred"):FailSetting( GetDefaultFailType() )
					
					-- Finally extract out the PlayerOptionsString by the fetching it from the engine
					-- Update the SL table so that this PlayerOptionsString value is easily accessible throughout the theme
					SL[pn].PlayerOptionsString = GAMESTATE:GetPlayerState(player):GetPlayerOptionsString("ModsLevel_Preferred")
				end
			end
		end
	end

	return true
end

-- function assigned to "CustomSaveFunction" under [Profile] in metrics.ini
SaveProfileCustom = function(profile, dir)

	local path =  dir .. filename

	for player in ivalues( GAMESTATE:GetHumanPlayers() ) do
		if profile == PROFILEMAN:GetProfile(player) then
			VOLT26.Tournament.RestorePlayer(player)
			local pn = ToEnumShortString(player)
			local output = {}
			for k,v in pairs(SL[pn].ActiveModifiers) do
				if permitted_profile_settings[k] and type(v)==permitted_profile_settings[k] then
					output[k] = v
				end
			end

			-- these values are saved outside the SL[pn].ActiveModifiers tables
			-- and thus won't be handled in the loop above
			output.PlayerOptionsString = SL[pn].PlayerOptionsString
			-- This profile has been through the legacy import (see
			-- ReadProfileSettings); a later save must not undo that.
			output[LEGACY_FLAG] = true

			IniFile.WriteFile( path, {[theme_name]=output} )

			WriteGrooveStatsIni(player)
			-- Write to the ITL file if we need to.
			-- This is relevant for memory cards.
			if VOLT26.Tournament.IsLocalItlEnabled() then WriteItlFile(player) end
			break
		end
	end

	return true
end

-- -----------------------------------------------------------------------
-- returns a path to a profile avatar, or nil if none is found

GetAvatarPath = function(profileDirectory, displayName)

	if type(profileDirectory) ~= "string" then return end

	local path = nil

	-- sequence matters here
	-- prefer png first, then jpg, then jpeg, etc.
	-- (note that SM5 does not support animated gifs at this time, so SL doesn't either)
	-- TODO: investigate effects (memory footprint, fps) of allowing movie files as avatars in SL
	local extensions = { "png", "jpg", "jpeg", "bmp", "gif" }

	-- prefer an avatar named:
	--    "avatar" in the player's profile directory (preferred by Simply Love)
	--    then "profile picture" in the player's profile directory (used by Digital Dance)
	--    then (whatever the profile's DisplayName is) in /Appearance/Avatars/ (used in OutFox?)
	local paths = {
		("%savatar"):format(profileDirectory),
		("%sprofile picture"):format(profileDirectory),
		("/Appearance/Avatars/%s"):format(displayName)
	}

	for _, path in ipairs(paths) do
		for _, extension in ipairs(extensions) do
			local avatar_path = ("%s.%s"):format(path, extension)

			if FILEMAN:DoesFileExist(avatar_path)
			and ActorUtil.GetFileType(avatar_path) == "FileType_Bitmap"
			then
				-- return the first valid avatar path that is found
				return avatar_path
			end
		end
	end

	-- or, return nil if no avatars were found in any of the permitted paths
	return nil
end

-- -----------------------------------------------------------------------
-- returns a path to a player's profile avatar, or nil if none is found

GetPlayerAvatarPath = function(player)
	if not player then return end

	local profile_slot = {
		[PLAYER_1] = "ProfileSlot_Player1",
		[PLAYER_2] = "ProfileSlot_Player2"
	}

	if not profile_slot[player] then return end

	local dir  = PROFILEMAN:GetProfileDir(profile_slot[player])
	local name = PROFILEMAN:GetProfile(player):GetDisplayName()

	return GetAvatarPath(dir, name)
end
