-- This script needs to be loaded before other scripts that use it.

local PlayerDefaults = {
	__index = {
		initialize = function(self)
			self.ActiveModifiers = {
				SpeedModType = "M",
				SpeedMod = 250,
				JudgmentGraphic = "Love 2x7 (doubleres).png",
				ComboFont = "Wendy",
				HoldJudgment = "Love 1x2 (doubleres).png",
				NoteSkin = nil,
				NoteSkinVariant = nil,
				Mini = "0%",
				BackgroundFilter = "Darker",
				VisualDelay = "0ms",

				HideTargets = false,
				HideSongBG = false,
				HideCombo = false,
				HideLifebar = false,
				HideScore = false,
				HideDanger = false,
				HideComboExplosions = false,

				FlashMiss = false,
				FlashWayOff = false,
				FlashDecent = false,
				FlashGreat = false,
				FlashExcellent = false,
				FlashFantastic = false,
				SubtractiveScoring = false,
				MeasureCounter = "None",
				MeasureCounterLeft = false,
				MeasureCounterUp = true,
				HideLookahead = false,
				MeasureLines = "Off",
				DataVisualizations = "Step Statistics",
				TargetScore = 11,
				ActionOnMissedTarget = "Nothing",
				Pacemaker = false,
				LifeMeterType = "Standard",
				NPSGraphAtTop = false,
				JudgmentTilt = false,
				TiltMultiplier = 1,
				ColumnCues = true,
				DisplayScorebox = true,

				ErrorBar = "None",
				ErrorBarUp = false,
				ErrorBarMultiTick = false,
				ErrorBarTrim = "Off",

				HideEarlyDecentWayOffJudgments = false,
				HideEarlyDecentWayOffFlash = false,

				-- The enabled windows are still recorded for GrooveStats and ITL
				-- validation, although ITG mode never disables one.
				TimingWindows = {true, true, true, true, true},
				ShowFaPlusWindow = false,
				ShowExScore = false,
				ShowFaPlusPane = true,

				NoteFieldOffsetX = 0,
				NoteFieldOffsetY = 0,
			}
			-- TODO(teejusb): Rename "Streams" as the data contains more information than that.
			self.Streams = {
				-- Chart identifiers used to cache the GrooveStats hash so we only
				-- parse a given chart once.
				Filename = "",
				StepsType = "",
				Difficulty = "",
				Description = "",

				-- Information parsed out from the chart.
				NotesPerMeasure = {},
				EquallySpacedPerMeasure = {},
				PeakNPS = 0,
				NPSperMeasure = {},
				ColumnCues = {},
				Hash = '',

				Crossovers = 0,
				Footswitches = 0,
				Sideswitches = 0,
				Jacks = 0,
				Brackets = 0,

				-- Data for measure counter. Populated in ./ScreenGameplay in/MeasureCounterAndMods.lua.
				-- Uses the notesThreshold option.
				Measures = {},
			}
			self.HighScores = {
				EnteringName = false,
				Name = ""
			}
			self.Stages = {
				Stats = {}
			}
			self.GameplayStats = {
				MeasureSegments = {},
			}
			self.PlayerOptionsString = nil
			self.ITLData = {
				["pathMap"] = {},
				["hashMap"] = {},
				["unlockFolders"] = {},
			}

			-- default panes to intialize ScreenEvaluation to
			-- when only a single player is joined (single, double)
			-- in versus (2 players joined) only EvalPanePrimary will be used
			self.EvalPanePrimary   = 1 -- large score and judgment counts
			self.EvalPaneSecondary = 5 -- offset histogram

			-- The GrooveStats API key loaded for this player
			self.ApiKey = ""
			self.GrooveStatsUsername = ""
			-- Whether or not the player is playing on pad.
			self.IsPadPlayer = false
			self.Favorites = {}
			self.FavoritePaths = {}
		end
	}
}

local GlobalDefaults = {
	__index = {

		-- since the initialize() function is called every game cycle, the idea
		-- is to define variables we want to reset every game cycle inside
		initialize = function(self)
			self.ActiveModifiers = {
				MusicRate = 1.0,
			}
			self.Stages = {
				PlayedThisGame = 0,
				Remaining = PREFSMAN:GetPreference("SongsPerPlay"),
				Stats = {}
			}
			self.GameplayStats = {
				PeakNPS = {},
			}
			self.ScreenAfter = {
				PlayAgain = "ScreenEvaluationSummary",
				PlayerOptions  = Branch.GameplayScreen(),
				PlayerOptions2 = Branch.GameplayScreen(),
				PlayerOptions3 = Branch.GameplayScreen(),
			}
			self.ContinuesRemaining = ThemePrefs.Get("NumberOfContinuesAllowed") or 0
			self.GameMode = "ITG"
			self.ScreenshotTexture = nil
			self.MenuTimer = {
				ScreenGrooveStatsLogin  = ThemePrefs.Get("ScreenGrooveStatsLoginMenuTimer"),
				ScreenSelectMusic       = ThemePrefs.Get("ScreenSelectMusicMenuTimer"),
				ScreenPlayerOptions     = ThemePrefs.Get("ScreenPlayerOptionsMenuTimer"),
				ScreenEvaluation        = ThemePrefs.Get("ScreenEvaluationMenuTimer"),
				ScreenEvaluationNonstop = ThemePrefs.Get("ScreenEvaluationNonstopMenuTimer"),
				ScreenEvaluationSummary = ThemePrefs.Get("ScreenEvaluationSummaryMenuTimer"),
				ScreenNameEntry         = ThemePrefs.Get("ScreenNameEntryMenuTimer"),
			}
			self.TimeAtSessionStart = nil
			self.SampleMusicLoops = ThemePrefs.Get("SampleMusicLoops")
			self.SampleMusicStartsImmediately = ThemePrefs.Get("SampleMusicStartsImmediately")

			-- Is the music wheel locked? Useful when loading overlay screens
			self.MusicWheelLocked = false
			
			self.GameplayReloadCheck = false
			-- How long to wait before displaying a "cue"
			self.ColumnCueMinTime = 1.5

			-- TODO(teejusb): We should only initialize this once to save on compute.
			self.GrooveStatsPlayerOptionKeys = type(CreateGrooveStatsPlayerOptionKeys) == "function"
				and CreateGrooveStatsPlayerOptionKeys() or {}

			-- used to track active OptionRow index when navigating the Operator Menu's many screens and sub-screens
			-- shaped like: { ScreenOptionsService=3, ScreenVisualOptions=1 }
			self.PrevScreenOptionsServiceRow = {}
		end,

		-- These values outside initialize() won't be reset each game cycle,
		-- but are rather manipulated as needed by the theme.
		-- The theme accent is fixed (see VOLT26.Brand.AccentColorIndex).
		-- ScreenSelectColor and the persisted colour preference were removed.
		ActiveColorIndex = 1,
	}
}

-- VOLT26 owns all shared runtime state.  The temporary SL alias declared
-- below exists only while legacy screens are migrated to the public CORE API.
VOLT26 = {
	P1 = setmetatable( {}, PlayerDefaults),
	P2 = setmetatable( {}, PlayerDefaults),
	Global = setmetatable( {}, GlobalDefaults),

	-- Colors that Simply Love's background can be
	-- These colors are used for text on dark backgrounds and backgrounds containing dark text:
	Colors = {
		"#FF5D47",
		"#FF577E",
		"#FF47B3",
		"#DD57FF",
		"#8885ff",
		"#3D94FF",
		"#00B8CC",
		"#5CE087",
		"#AEFA44",
		"#FFFF00",
		"#FFBE00",
		"#FF7D00",
	},
	-- These are the original SL colors. They're used for decorative (non-text) elements, like the background hearts:
	DecorativeColors = {
		"#FF3C23",
		"#FF003C",
		"#C1006F",
		"#8200A1",
		"#413AD0",
		"#0073FF",
		"#00ADC0",
		"#5CE087",
		"#AEFA44",
		"#FFFF00",
		"#FFBE00",
		"#FF7D00"
	},
	-- These judgment colors are used for text & numbers on dark backgrounds:
	JudgmentColors = {
		ITG = {
			color("#21CCE8"),	-- blue
			color("#e29c18"),	-- gold
			color("#66c955"),	-- green
			color("#b45cff"),	-- purple (greatly lightened)
			color("#c9855e"),	-- peach?
			color("#ff3030")	-- red (slightly lightened)
		},
		["FA+"] = {
			color("#21CCE8"),	-- blue
			color("#ffffff"),	-- white
			color("#e29c18"),	-- gold
			color("#66c955"),	-- green
			color("#b45cff"),	-- purple (greatly lightened)
			color("#ff3030")	-- red (slightly lightened)
		},
	},
	Preferences = {
		ITG = {
			TimingWindowAdd=0.0015,
			RegenComboAfterMiss=5,
			MaxRegenComboAfterMiss=10,
			MinTNSToHideNotes="TapNoteScore_W3",
			MinTNSToScoreNotes=ThemePrefs.Get("RescoreEarlyHits") and "TapNoteScore_W3" or "TapNoteScore_None",
			HarshHotLifePenalty=true,

			PercentageScoring=true,
			AllowW1="AllowW1_Everywhere",
			SubSortByNumSteps=true,

			TimingWindowSecondsW1=0.021500,
			TimingWindowSecondsW2=0.043000,
			TimingWindowSecondsW3=0.102000,
			TimingWindowSecondsW4=0.135000,
			TimingWindowSecondsW5=0.180000,
			TimingWindowSecondsHold=0.320000,
			TimingWindowSecondsMine=0.070000,
			TimingWindowSecondsRoll=0.350000,
		},
		["FA+"] = {
			TimingWindowAdd=0.0015,
			RegenComboAfterMiss=5,
			MaxRegenComboAfterMiss=10,
			MinTNSToHideNotes="TapNoteScore_W4",
			MinTNSToScoreNotes=ThemePrefs.Get("RescoreEarlyHits") and "TapNoteScore_W4" or "TapNoteScore_None",
			HarshHotLifePenalty=true,

			PercentageScoring=true,
			AllowW1="AllowW1_Everywhere",
			SubSortByNumSteps=true,

			TimingWindowSecondsW1=0.013500,
			TimingWindowSecondsW2=0.021500,
			TimingWindowSecondsW3=0.043000,
			TimingWindowSecondsW4=0.102000,
			TimingWindowSecondsW5=0.135000,
			TimingWindowSecondsHold=0.320000,
			-- NOTE(teejusb): FA+ mode previously had mines set to
			-- 65ms instead of the actual window size of 70ms. This
			-- was to account for "SM5 Mines" but now with the patch here:
			-- https://gist.github.com/DinsFire64/4a3f763cd3033afd55a176980b32a3b5
			-- and the development in the thread here:
			-- https://github.com/stepmania/stepmania/issues/1896
			-- it's as good as "fixed" for the very very large majority of
			-- cases so we can set this back to 70ms now.
			TimingWindowSecondsMine=0.070000,
			TimingWindowSecondsRoll=0.350000,
		},
	},
	Metrics = {
		-- The PercentScoreWeightCheckpointHit and
		-- GradeWeightCheckpointHit metrics are only used in pump game
		-- mode. We have to set them to 0 for two reasons:
		-- 1. Due to an inconsistency in the game engine the score for
		--    perfect play adds up to less than 100% when
		--    PercentScoreWeightCheckpointHit is > 0.
		-- 2. It brings the scoring in pump mode closer to PIU scoring,
		--    which does not award points for held checkpoints, but
		--    only penalizes missed checkpoints.

		ITG = {
			PercentScoreWeightW1=5,
			PercentScoreWeightW2=4,
			PercentScoreWeightW3=2,
			PercentScoreWeightW4=0,
			PercentScoreWeightW5=-6,
			PercentScoreWeightMiss=-12,
			PercentScoreWeightLetGo=0,
			PercentScoreWeightHeld=5,
			PercentScoreWeightHitMine=-6,
			PercentScoreWeightCheckpointHit=0,

			GradeWeightW1=5,
			GradeWeightW2=4,
			GradeWeightW3=2,
			GradeWeightW4=0,
			GradeWeightW5=-6,
			GradeWeightMiss=-12,
			GradeWeightLetGo=0,
			GradeWeightHeld=5,
			GradeWeightHitMine=-6,
			GradeWeightCheckpointHit=0,

			LifePercentChangeW1=0.008,
			LifePercentChangeW2=0.008,
			LifePercentChangeW3=0.004,
			LifePercentChangeW4=0.000,
			LifePercentChangeW5=-0.050,
			LifePercentChangeMiss=-0.100,
			LifePercentChangeLetGo=-0.080,
			LifePercentChangeHeld=0.008,
			LifePercentChangeHitMine=-0.050,

			InitialValue=0.5,
		},
		["FA+"] = {
			PercentScoreWeightW1=5,
			PercentScoreWeightW2=5,
			PercentScoreWeightW3=4,
			PercentScoreWeightW4=2,
			PercentScoreWeightW5=0,
			PercentScoreWeightMiss=-12,
			PercentScoreWeightLetGo=0,
			PercentScoreWeightHeld=5,
			PercentScoreWeightHitMine=-6,
			PercentScoreWeightCheckpointHit=0,

			GradeWeightW1=5,
			GradeWeightW2=5,
			GradeWeightW3=4,
			GradeWeightW4=2,
			GradeWeightW5=0,
			GradeWeightMiss=-12,
			GradeWeightLetGo=0,
			GradeWeightHeld=5,
			GradeWeightHitMine=-6,
			GradeWeightCheckpointHit=0,

			LifePercentChangeW1=0.008,
			LifePercentChangeW2=0.008,
			LifePercentChangeW3=0.008,
			LifePercentChangeW4=0.004,
			LifePercentChangeW5=0,
			LifePercentChangeMiss=-0.1,
			LifePercentChangeLetGo=-0.080,
			LifePercentChangeHeld=0.008,
			LifePercentChangeHitMine=-0.05,

			InitialValue=0.5,
		},
	},
	ExWeights = {
		-- W0 is not necessarily a "real" window.
		-- In ITG mode it is emulated based off the value of TimingWindowW1 defined
		-- for FA+ mode.
		W0=3.5,
		W1=3,
		W2=2,
		W3=1,
		W4=0,
		W5=0,
		Miss=0,
		LetGo=0,
		Held=1,
		HitMine=-1
	},
	-- Fields used to determine whether or not we can connect to the
	-- GrooveStats services.
	GrooveStats = {
		-- Whether we're connected to the internet or not.
		-- Determined once on boot in ScreenSystemLayer.
		IsConnected = false,

		-- Available GrooveStats services. Subject to change while
		-- StepMania is running.
		GetScores = false,
		Leaderboard = false,
		AutoSubmit = false,

		-- ************* CURRENT QR VERSION *************
		-- * Update whenever we change relevant QR code *
		-- *  and when GrooveStats backend is also      *
		-- *   updated to properly consume this value.  *
		-- **********************************************
		ChartHashVersion = 3,

		-- We want to cache the some of the requests/responses to prevent making the
		-- same request multiple times in a small timeframe.
		-- Each entry is keyed with some string hash which maps to a table with the
		-- following keys:
		--   Response: string, the JSON-ified response to cache
		--   Timestamp: number, when the request was made
		RequestCache = {},

		-- Event unlock downloads are outside ONLINE-01's accepted security boundary.
		UnlocksCache = {},
	},
	-- Stores all active/failed downloads.
	-- Each entry is keyed on a string UUID which maps to a table with the
	-- following keys:
	--    Request: HttpRequestFuture, the closure returned by NETWORK:HttpRequest
	--    Name: string, an identifier for this download.
	--    Url: string, The URL of the download.
	--    Destination: string, where the download should be unpacked to.
	--    CurrentBytes: number, the bytes downloaded so far
	--    TotalBytes: number, the total bytes of the file
	--    Complete: bool, whether or not the download has completed
	--              (either success or failure).
	-- If a request fails, there will be another key:
	--    ErrorMessage: string, the reasoning for the failure.
	Downloads = {Registry={}},

	-- Latest versions available for ITGmania and Simply Love.
	ITGmaniaLatestVersion = nil,
	SimplyLoveLatestVersion = nil,
}

VOLT26.Meta = {
	Name = "VOLT26",
	Version = "0.1.0-rc.1",
	UpstreamCompatibility = "Simply Love 5.9.0",
}

-- Utility primitives are bootstrapped before ThemePrefs and attached here once
-- the authoritative VOLT26 runtime namespace exists.
VOLT26.Util = VOLT26Utility

VOLT26.State = {
	P1 = VOLT26.P1,
	P2 = VOLT26.P2,
	Global = VOLT26.Global,
}

VOLT26.Core = {}

function VOLT26.Core.GetGlobalState()
	return VOLT26.State.Global
end

function VOLT26.Core.GetPlayerState(player)
	local key
	if player == PLAYER_1 or player == "PlayerNumber_P1" or player == "P1" then
		key = "P1"
	elseif player == PLAYER_2 or player == "PlayerNumber_P2" or player == "P2" then
		key = "P2"
	else
		key = ToEnumShortString(player)
	end
	return VOLT26.State[key]
end

VOLT26.Compatibility = {
	MinimumVersion = {1, 3, 0},
	SupportedGames = {dance=true, pump=true, techno=true, para=true, kb7=true},
}

function VOLT26.Compatibility.ParseVersion(version)
	local result = {}
	for part in tostring(version or ""):gsub("%-.*", ""):gmatch("[^%.]+") do
		result[#result + 1] = tonumber(part)
	end
	return result
end

function VOLT26.Compatibility.GetProductVersionParts()
	local version = type(ProductVersion) == "function" and ProductVersion() or ""
	return VOLT26.Compatibility.ParseVersion(version)
end

function VOLT26.Compatibility.GetThemeMetadata()
	local path = THEME:GetCurrentThemeDirectory() .. "ThemeInfo.ini"
	local contents = IniFile.ReadFile(path) or {}
	local metadata = contents.ThemeInfo or {}
	return {
		Name = THEME:GetCurThemeName(),
		Version = metadata.Version or false,
		Author = metadata.Author or false,
	}
end

function VOLT26.Compatibility.SupportsRenderToTexture()
	local architecture = HOOKS:GetArchName():lower()
	local renderers = PREFSMAN:GetPreference("VideoRenderers") or ""
	return not (architecture:match("windows") and renderers:sub(1, 3):lower() == "d3d")
end

function VOLT26.Compatibility.MinimumVersionString()
	return table.concat(VOLT26.Compatibility.MinimumVersion, ".")
end

function VOLT26.Compatibility.IsEngineSupported(family, version)
	if family ~= "ITGmania" then return false end
	local actual = VOLT26.Compatibility.ParseVersion(version)
	for index, required in ipairs(VOLT26.Compatibility.MinimumVersion) do
		if not actual[index] or actual[index] < required then return false end
		if actual[index] > required then return true end
	end
	return true
end

function VOLT26.Compatibility.IsGameSupported(gameName)
	return VOLT26.Compatibility.SupportedGames[gameName] == true
end

function VOLT26.Compatibility.CheckCurrent()
	local family = type(ProductFamily) == "function" and ProductFamily() or "Unknown"
	local version = type(ProductVersion) == "function" and ProductVersion() or "Unknown"
	if not VOLT26.Compatibility.IsEngineSupported(family, version) then
		return false, THEME:GetString("ScreenInit", "UnsupportedSMVersion"):format(
			family, version, VOLT26.Compatibility.MinimumVersionString())
	end
	local game = GAMESTATE:GetCurrentGame()
	local gameName = game and game:GetName() or "Unknown"
	if not VOLT26.Compatibility.IsGameSupported(gameName) then
		return false, THEME:GetString("ScreenInit", "UnsupportedGame"):format(gameName)
	end
	return true
end


-- Keep VOLT26.Preferences reserved for the inherited game-mode scoring table
-- until all compatibility consumers have migrated away from SL.Preferences.
VOLT26.ThemePrefs = {
	Get = function(name) return ThemePrefs.Get(name) end,
	Set = function(name, value) ThemePrefs.Set(name, value) end,
	Save = function() ThemePrefs.Save() end,
	GetDefinitions = function() return VOLT26_Prefs.Get() end,
	IsValid = function(name, value)
		return VOLT26_Prefs.IsValid(VOLT26_Prefs.Get()[name], value)
	end,
}


function VOLT26.ThemePrefs.ApplyGameMode(gameMode)
	local mode = gameMode or VOLT26.State.Global.GameMode
	local preferences = VOLT26.Preferences[mode]
	if not preferences then return false end
	VOLT26.State.Global.GameMode = mode
	for key, value in pairs(preferences) do PREFSMAN:SetPreference(key, value) end

	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		local state = VOLT26.Core.GetPlayerState(player)
		local timingWindows = CustomOptionRow("TimingWindows")
		timingWindows:LoadSelections(timingWindows.Choices, player)
		local options = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
		options:MinTNSToHideNotes(preferences.MinTNSToHideNotes)
		options:FailSetting(GetDefaultFailType())
	end

	-- Profiles written by a former Casual session used a separate stats prefix.
	if PROFILEMAN:GetStatsPrefix() ~= "" then PROFILEMAN:SetStatsPrefix("") end
	return true
end

function VOLT26.ThemePrefs.ResetManagedEnginePreferences(gameMode)
	local preferences = VOLT26.Preferences[gameMode or VOLT26.State.Global.GameMode]
	if not preferences then return false end
	for key in pairs(preferences) do PREFSMAN:SetPreferenceToDefault(key) end
	PREFSMAN:SavePreferences()
	return true
end


VOLT26.TitleMenu = {
	AFKTimeoutSeconds = 180,
	-- Measured from Sounds/intro.ogg (797905 samples at 44.1 kHz).
	IntroDurationSeconds = 18.093,
}

function VOLT26.TitleMenu.GetIntroDurationSeconds()
	return VOLT26.TitleMenu.IntroDurationSeconds
end

function VOLT26.TitleMenu.GetAFKTimeoutSeconds()
	return VOLT26.TitleMenu.AFKTimeoutSeconds
end

-- Performance mode keeps the lightweight classic title for low-powered
-- cabinets; Enhanced mode uses the 3D city title and its opening cinematic.
function VOLT26.TitleMenu.UsesClassicLayout()
	return VOLT26.Performance.IsEnabled()
end

function VOLT26.TitleMenu.ShouldUseAFK()
	return GAMESTATE:GetCoinMode() ~= "CoinMode_Pay"
end

VOLT26.MenuTimer = {}

-- Keep the engine preference authoritative while giving custom screens one
-- shared policy for timer behavior and presentation.
function VOLT26.MenuTimer.IsEnabled()
	return PREFSMAN:GetPreference("MenuTimer")
end

function VOLT26.MenuTimer.IsPaidMode()
	local runtimeMode = GAMESTATE:GetCoinMode()
	local configuredMode = PREFSMAN:GetPreference("CoinMode")
	return runtimeMode == "CoinMode_Pay" or runtimeMode == "Pay"
		or configuredMode == "CoinMode_Pay" or configuredMode == "Pay"
end

function VOLT26.MenuTimer.IsEnabledForSongSelect()
	return VOLT26.MenuTimer.IsEnabled() or VOLT26.MenuTimer.IsPaidMode()
end

VOLT26.Navigation = {}


-- Initialize preferences by calling this method.  We typically do
-- this from ./BGAnimations/ScreenTitleMenu underlay/default.lua
-- so that preferences reset between each game cycle.

function VOLT26.Core.ResetSession()
	VOLT26.State.P1:initialize()
	VOLT26.State.P2:initialize()
	VOLT26.State.Global:initialize()

end

function InitializeVOLT26()
	VOLT26.Core.ResetSession()
end

-- Compatibility bridge for screens that have not moved to the CORE API yet.
SL = VOLT26

InitializeVOLT26()
