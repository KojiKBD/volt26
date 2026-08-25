-- This script needs to be loaded before other scripts that use it.

local PlayerDefaults = {
	__index = {
		initialize = function(self)
			self.ActiveModifiers = {
				SpeedModType = "M",
				SpeedMod = 250,
				JudgmentGraphic = "Love 2x6 (doubleres).png",
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

				-- While SL no longer supports disabling individual timing windows
				-- in ITG mode, Casual mode still does so we still track it here.
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
		ActiveColorIndex = ThemePrefs.Get("VOLT26Color") or ThemePrefs.Get("SimplyLoveColor") or 2,
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
		Casual = {
			color("#21CCE8"),	-- blue
			color("#e29c18"),	-- gold
			color("#66c955"),	-- green
			color("#b45cff"),	-- purple (greatly lightened)
			color("#c9855e"),	-- peach?
			color("#ff3030")	-- red (slightly lightened)
		},
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
		Casual = {
			TimingWindowAdd=0.0015,
			RegenComboAfterMiss=0,
			MaxRegenComboAfterMiss=0,
			MinTNSToHideNotes="TapNoteScore_W3",
			HarshHotLifePenalty=true,

			PercentageScoring=true,
			AllowW1="AllowW1_Everywhere",
			SubSortByNumSteps=true,

			TimingWindowSecondsW1=0.021500,
			TimingWindowSecondsW2=0.043000,
			TimingWindowSecondsW3=0.102000,
			TimingWindowSecondsW4=0.102000,
			TimingWindowSecondsW5=0.102000,
			TimingWindowSecondsHold=0.320000,
			TimingWindowSecondsMine=0.070000,
			TimingWindowSecondsRoll=0.350000,
		},
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

		Casual = {
			PercentScoreWeightW1=3,
			PercentScoreWeightW2=2,
			PercentScoreWeightW3=1,
			PercentScoreWeightW4=0,
			PercentScoreWeightW5=0,
			PercentScoreWeightMiss=0,
			PercentScoreWeightLetGo=0,
			PercentScoreWeightHeld=3,
			PercentScoreWeightHitMine=-1,
			PercentScoreWeightCheckpointHit=0,

			GradeWeightW1=3,
			GradeWeightW2=2,
			GradeWeightW3=1,
			GradeWeightW4=0,
			GradeWeightW5=0,
			GradeWeightMiss=0,
			GradeWeightLetGo=0,
			GradeWeightHeld=3,
			GradeWeightHitMine=-1,
			GradeWeightCheckpointHit=0,

			LifePercentChangeW1=0,
			LifePercentChangeW2=0,
			LifePercentChangeW3=0,
			LifePercentChangeW4=0,
			LifePercentChangeW5=0,
			LifePercentChangeMiss=0,
			LifePercentChangeLetGo=0,
			LifePercentChangeHeld=0,
			LifePercentChangeHitMine=0,

			InitialValue=0.5,
		},
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

VOLT26.ChartData = {}

local OriginalDifficultyColors = {
	Difficulty_Beginner = color("#AEFA44"),
	Difficulty_Easy = color("#FFFF00"),
	Difficulty_Medium = color("#FFBE00"),
	Difficulty_Hard = color("#FF7D00"),
	Difficulty_Challenge = color("#FF5D47"),
	Difficulty_Edit = color("#B4B7BA"),
}

function VOLT26.ChartData.GetDifficultyColor(difficulty)
	return DeepCopy(OriginalDifficultyColors[difficulty] or OriginalDifficultyColors.Difficulty_Edit)
end

local function ChartPlayerEnum(player)
	if player == "P1" or player == PLAYER_1 then return PLAYER_1 end
	if player == "P2" or player == PLAYER_2 then return PLAYER_2 end
	return nil
end

local function ChartPlayerKey(player)
	if player == "P1" or player == PLAYER_1 then return "P1" end
	if player == "P2" or player == PLAYER_2 then return "P2" end
	return nil
end

function VOLT26.ChartData.Refresh(steps, player)
	local playerEnum = ChartPlayerEnum(player)
	local playerKey = ChartPlayerKey(player)
	if not steps or not playerEnum or not playerKey then return nil end

	local techCounts = steps:GetTechCounts(playerEnum)
	local result = {
		NotesPerMeasure = steps:GetNotesPerMeasure(playerEnum),
		NPSperMeasure = steps:GetNpsPerMeasure(playerEnum),
		PeakNPS = steps:GetPeakNps(playerEnum),
		Crossovers = techCounts:GetValue("TechCountsCategory_Crossovers"),
		Footswitches = techCounts:GetValue("TechCountsCategory_Footswitches"),
		Sideswitches = techCounts:GetValue("TechCountsCategory_Sideswitches"),
		Jacks = techCounts:GetValue("TechCountsCategory_Jacks"),
		Brackets = techCounts:GetValue("TechCountsCategory_Brackets"),
	}

	local streams = VOLT26.State[playerKey].Streams
	for key, value in pairs(result) do streams[key] = value end
	return DeepCopy(result)
end

function VOLT26.ChartData.Get(player)
	local playerKey = ChartPlayerKey(player)
	if not playerKey then return nil end
	local streams = VOLT26.State[playerKey].Streams
	return DeepCopy({
		NotesPerMeasure = streams.NotesPerMeasure,
		NPSperMeasure = streams.NPSperMeasure,
		PeakNPS = streams.PeakNPS,
		Crossovers = streams.Crossovers,
		Footswitches = streams.Footswitches,
		Sideswitches = streams.Sideswitches,
		Jacks = streams.Jacks,
		Brackets = streams.Brackets,
	})
end

function VOLT26.ChartData.GetColumnCues(steps, player)
	local playerKey = ChartPlayerKey(player)
	if not steps or not playerKey then return {} end

	local cues = steps:GetColumnCues(VOLT26.State.Global.ColumnCueMinTime)
	for _, cue in ipairs(cues) do
		for _, column in ipairs(cue.columns) do
			column.isMine = column.noteType == 4
			column.noteType = nil
		end
	end
	VOLT26.State[playerKey].Streams.ColumnCues = cues
	return DeepCopy(cues)
end

VOLT26.ChartAnalysis = {}

function VOLT26.ChartAnalysis.GetStreamSequences(notesPerMeasure, notesThreshold)
	local streamMeasures = {}
	for index, noteCount in ipairs(notesPerMeasure or {}) do
		if noteCount >= notesThreshold then streamMeasures[#streamMeasures + 1] = index end
	end

	local sequences = {}
	local counter = 1
	local streamEnd = nil
	if #streamMeasures > 0 then
		local breakEnd = streamMeasures[1] - 1
		if breakEnd >= 2 then
			sequences[#sequences + 1] = {streamStart=0, streamEnd=breakEnd, isBreak=true}
		end
	end

	for index, current in ipairs(streamMeasures) do
		local nextMeasure = streamMeasures[index + 1] or -1
		if current + 1 == nextMeasure then
			counter = counter + 1
			streamEnd = current + 1
		else
			streamEnd = streamEnd or current
			sequences[#sequences + 1] = {
				streamStart=streamEnd - counter,
				streamEnd=streamEnd,
				isBreak=false,
			}
			local breakEnd = nextMeasure ~= -1 and nextMeasure - 1 or #(notesPerMeasure or {})
			if breakEnd - current >= 2 then
				sequences[#sequences + 1] = {streamStart=current, streamEnd=breakEnd, isBreak=true}
			end
			counter = 1
			streamEnd = nil
		end
	end
	return sequences
end

function VOLT26.ChartAnalysis.GetBreakdownText(notesPerMeasure, minimizationLevel)
	if #(notesPerMeasure or {}) == 0 then return "Not available!" end
	local segments = VOLT26.ChartAnalysis.GetStreamSequences(notesPerMeasure, 16)
	local textSegments = {}
	local segmentSum, totalSum = 0, 0
	local isBroken = false

	local function addNotation(notation, segmentSize)
		if minimizationLevel == 0 then
			textSegments[#textSegments + 1] = " (" .. tostring(segmentSize) .. ") "
		elseif segmentSum ~= 0 then
			if minimizationLevel == 2 then
				textSegments[#textSegments + 1] = tostring(segmentSum) .. (isBroken and "*" or "")
			elseif minimizationLevel == 3 then
				totalSum = totalSum + segmentSum
			end
		end
		if minimizationLevel ~= 3 then textSegments[#textSegments + 1] = notation end
		segmentSum, isBroken = 0, false
	end

	for index, segment in ipairs(segments) do
		local segmentSize = segment.streamEnd - segment.streamStart
		if segment.isBreak then
			if index ~= 1 and index ~= #segments then
				if segmentSize <= 4 then
					addNotation("-", segmentSize)
				elseif segmentSize < 32 then
					addNotation("/", segmentSize)
				else
					addNotation(" | ", segmentSize)
				end
			end
		elseif minimizationLevel == 2 or minimizationLevel == 3 then
			if index > 1 and not segments[index - 1].isBreak then
				isBroken = true
				if minimizationLevel == 2 then segmentSum = segmentSum + 1 end
			end
			segmentSum = segmentSum + segmentSize
		else
			if index > 1 and not segments[index - 1].isBreak then
				textSegments[#textSegments + 1] = "-"
			end
			textSegments[#textSegments + 1] = tostring(segmentSize)
		end
	end

	if segmentSum ~= 0 then
		if minimizationLevel == 2 then
			textSegments[#textSegments + 1] = tostring(segmentSum) .. (isBroken and "*" or "")
		elseif minimizationLevel == 3 then
			totalSum = totalSum + segmentSum
		end
	end

	if minimizationLevel == 3 then return string.format("%d Total", totalSum) end
	if #textSegments == 0 then return "No Streams!" end
	return table.concat(textSegments, "")
end

function VOLT26.ChartAnalysis.GetMeasureTotals(notesPerMeasure)
	local streamTotal, breakTotal = 0, 0
	for _, segment in ipairs(VOLT26.ChartAnalysis.GetStreamSequences(notesPerMeasure, 16)) do
		local size = segment.streamEnd - segment.streamStart
		if segment.isBreak then breakTotal = breakTotal + size else streamTotal = streamTotal + size end
	end
	return streamTotal, breakTotal
end

VOLT26.ChartHash = {}

function VOLT26.ChartHash.Compute(steps, player)
	return VOLT26ComputeChartHash(steps, ChartPlayerKey(player))
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

function VOLT26.ThemePrefs.ApplyGameMode(gameMode)
	local mode = gameMode or VOLT26.State.Global.GameMode
	if mode == "Casual" then mode = "ITG" end
	local preferences = VOLT26.Preferences[mode]
	if not preferences then return false end
	VOLT26.State.Global.GameMode = mode
	for key, value in pairs(preferences) do PREFSMAN:SetPreference(key, value) end

	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		local state = VOLT26.Core.GetPlayerState(player)
		if mode == "Casual" then state.ActiveModifiers.TimingWindows = {true, true, true, false, false} end
		local timingWindows = CustomOptionRow("TimingWindows")
		timingWindows:LoadSelections(timingWindows.Choices, player)
		local options = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
		options:MinTNSToHideNotes(preferences.MinTNSToHideNotes)
		options:FailSetting(GetDefaultFailType())
	end

	local statsPrefix = mode == "Casual" and "Casual-" or ""
	if PROFILEMAN:GetStatsPrefix() ~= statsPrefix then PROFILEMAN:SetStatsPrefix(statsPrefix) end
	return true
end

function VOLT26.ThemePrefs.ResetManagedEnginePreferences(gameMode)
	local preferences = VOLT26.Preferences[gameMode or VOLT26.State.Global.GameMode]
	if not preferences then return false end
	for key in pairs(preferences) do PREFSMAN:SetPreferenceToDefault(key) end
	PREFSMAN:SavePreferences()
	return true
end

VOLT26.Profile = {
	LoadGuest = LoadGuest,
	LoadCustom = LoadProfileCustom,
	SaveCustom = SaveProfileCustom,
	GetAvatarPath = GetAvatarPath,
	GetPlayerAvatarPath = GetPlayerAvatarPath,
	GetPreferredStyle = function()
		return VOLT26.ThemePrefs.Get("PreferredStyle")
	end,
	IsFastSwitchInProgress = function()
		return VOLT26.State.Global.FastProfileSwitchInProgress == true
	end,
	BeginFastSwitch = function()
		if VOLT26.State.Global.FastProfileSwitchInProgress then return false end
		VOLT26.State.Global.FastProfileSwitchInProgress = true
		return true
	end,
	FinishFastSwitch = function()
		VOLT26.State.Global.FastProfileSwitchInProgress = false
	end,
}

VOLT26.Favorites = {}

local function FavoriteProfileDir(player)
	local index = PlayerNumber:Reverse()[player]
	if index == nil then return nil end
	return PROFILEMAN:GetProfileDir(ProfileSlot[index + 1])
end

local function FavoriteDefaultSection(player)
	local profileName = PROFILEMAN:GetPlayerName(player)
	if not profileName or profileName == "" then profileName = ToEnumShortString(player) end
	return profileName .. "'s Favorites"
end

local function ReadTextFile(path)
	if not path or not FILEMAN:DoesFileExist(path) then return nil end
	return lua.ReadFile(path)
end

local function WriteTextFile(path, contents)
	local file = RageFileUtil.CreateRageFile()
	if not file:Open(path, 2) then
		file:destroy()
		Warn("Could not open '" .. tostring(path) .. "' to write favorites.")
		return false
	end
	file:Write(contents)
	file:Close()
	file:destroy()
	return true
end

function VOLT26.Favorites.GetPath(player)
	local profileDir = FavoriteProfileDir(player)
	return profileDir and (profileDir .. "VOLT26-favorites.txt") or nil
end

function VOLT26.Favorites.GetLegacyPath(player)
	local profileDir = FavoriteProfileDir(player)
	return profileDir and (profileDir .. "favorites.txt") or nil
end

function VOLT26.Favorites.NormalizePath(path)
	if type(path) ~= "string" then return nil end
	local normalized = path:gsub("\\", "/"):gsub("^%s+", ""):gsub("%s+$", "")
	normalized = normalized:gsub("^/+", ""):gsub("/+$", "")
	local parts = {}
	for part in normalized:gmatch("[^/]+") do parts[#parts+1] = part end
	if #parts < 2 then return nil end
	return parts[#parts-1] .. "/" .. parts[#parts]
end

function VOLT26.Favorites.Parse(contents, defaultSection)
	local sections = {}
	local current
	local seen = {}
	defaultSection = defaultSection or "Favorites"

	for rawLine in tostring(contents or ""):gmatch("[^\r\n]+") do
		local line = rawLine:gsub("^%s+", ""):gsub("%s+$", "")
		if line:sub(1, 3) == "---" then
			local name = line:sub(4):gsub("^%s+", ""):gsub("%s+$", "")
			if name == "" then name = defaultSection end
			current = { Name=name, Songs={} }
			sections[#sections+1] = current
		elseif line ~= "" then
			local path = VOLT26.Favorites.NormalizePath(line)
			local key = path and path:lower()
			if path and not seen[key] then
				if not current then
					current = { Name=defaultSection, Songs={} }
					sections[#sections+1] = current
				end
				current.Songs[#current.Songs+1] = path
				seen[key] = true
			end
		end
	end

	return sections
end

function VOLT26.Favorites.Serialize(sections)
	local output = {}
	for section in ivalues(sections or {}) do
		local songs = {}
		for path in ivalues(section.Songs or {}) do songs[#songs+1] = path end
		table.sort(songs, function(a, b)
			local songA = SONGMAN:FindSong(a)
			local songB = SONGMAN:FindSong(b)
			local titleA = songA and songA:GetDisplayMainTitle():lower() or a:lower()
			local titleB = songB and songB:GetDisplayMainTitle():lower() or b:lower()
			if titleA == titleB then return a:lower() < b:lower() end
			return titleA < titleB
		end)
		output[#output+1] = "---" .. tostring(section.Name or "Favorites")
		for path in ivalues(songs) do output[#output+1] = path end
	end
	return #output > 0 and (table.concat(output, "\n") .. "\n") or ""
end

local function ReadFavoriteSections(player)
	local path = VOLT26.Favorites.GetPath(player)
	local legacyPath = VOLT26.Favorites.GetLegacyPath(player)
	local contents = ReadTextFile(path)
	local importedLegacy = false
	if contents == nil then
		contents = ReadTextFile(legacyPath)
		importedLegacy = contents ~= nil
	end
	return VOLT26.Favorites.Parse(contents, FavoriteDefaultSection(player)), contents or "", importedLegacy
end

function VOLT26.Favorites.Load(player)
	local state = VOLT26.Core.GetPlayerState(player)
	state.Favorites = {}
	state.FavoritePaths = {}
	if not PROFILEMAN:IsPersistentProfile(player) then return false end

	local sections, original, importedLegacy = ReadFavoriteSections(player)
	local normalized = VOLT26.Favorites.Serialize(sections)
	if importedLegacy or normalized ~= original then
		WriteTextFile(VOLT26.Favorites.GetPath(player), normalized)
	end

	for section in ivalues(sections) do
		for path in ivalues(section.Songs) do
			local song = SONGMAN:FindSong(path)
			if song then
				state.Favorites[#state.Favorites+1] = song
				state.FavoritePaths[path:lower()] = true
			end
		end
	end
	return true
end

function VOLT26.Favorites.LoadAll()
	for player in ivalues(GAMESTATE:GetEnabledPlayers()) do
		VOLT26.Favorites.Load(player)
	end
end

function VOLT26.Favorites.HasAny(player)
	local state = VOLT26.Core.GetPlayerState(player)
	return state and #state.Favorites > 0
end

function VOLT26.Favorites.HasSong(player, song)
	if not song then return false end
	local path = VOLT26.Favorites.NormalizePath(song:GetSongDir())
	local state = VOLT26.Core.GetPlayerState(player)
	return path ~= nil and state.FavoritePaths[path:lower()] == true
end

function VOLT26.Favorites.Toggle(player, song)
	if not song or not PROFILEMAN:IsPersistentProfile(player) then
		SCREENMAN:SystemMessage(THEME:GetString("ScreenSelectMusic", "FavoriteRequiresProfile"))
		return false
	end

	local path = VOLT26.Favorites.NormalizePath(song:GetSongDir())
	if not path then return false end
	local sections = ReadFavoriteSections(player)
	local removed = false
	for section in ivalues(sections) do
		for index=#section.Songs, 1, -1 do
			if section.Songs[index]:lower() == path:lower() then
				table.remove(section.Songs, index)
				removed = true
			end
		end
	end

	if not removed then
		if #sections == 0 then sections[1] = { Name=FavoriteDefaultSection(player), Songs={} } end
		sections[#sections].Songs[#sections[#sections].Songs+1] = path
	end

	if not WriteTextFile(VOLT26.Favorites.GetPath(player), VOLT26.Favorites.Serialize(sections)) then
		SCREENMAN:SystemMessage(THEME:GetString("ScreenSelectMusic", "FavoriteSaveFailed"):format(ToEnumShortString(player)))
		return false
	end
	VOLT26.Favorites.Load(player)

	local profileName = PROFILEMAN:GetPlayerName(player)
	if not profileName or profileName == "" then profileName = ToEnumShortString(player) end
	local messageKey = removed and "FavoriteRemoved" or "FavoriteAdded"
	SCREENMAN:SystemMessage(THEME:GetString("ScreenSelectMusic", messageKey):format(song:GetDisplayFullTitle(), profileName))
	SOUND:PlayOnce(THEME:GetPathS("", removed and "Common invalid.ogg" or "_unlock.ogg"))
	return true
end

function VOLT26.Favorites.ToggleCurrent(player)
	return VOLT26.Favorites.Toggle(player, GAMESTATE:GetCurrentSong())
end

VOLT26.MusicSelection = {}

function VOLT26.MusicSelection.GetMusicRate()
	return VOLT26.MusicSelection.NormalizeMusicRate(VOLT26.State.Global.ActiveModifiers.MusicRate)
end

function VOLT26.MusicSelection.NormalizeMusicRate(value)
	local rate = tonumber(value)
	return rate and rate > 0 and rate or 1
end

function VOLT26.MusicSelection.PrepareScreen()
	VOLT26.State.Global.GameplayReloadCheck = false
	VOLT26.Tournament.RestoreAllPlayers()
	VOLT26.Favorites.LoadAll()
	GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred"):MusicRate(VOLT26.MusicSelection.GetMusicRate())
end

function VOLT26.MusicSelection.RefreshPlayer(player, rebuildFavorites)
	if not PROFILEMAN:IsPersistentProfile(player) then
		VOLT26.Profile.LoadGuest(player)
	end
	if rebuildFavorites then
		VOLT26.Favorites.LoadAll()
	end
	ApplyMods(player)
end

VOLT26.SongBrowsing = {}

local songBrowsingActions = {
	AddFavorite = true,
	ChangePlayMode = true,
	ChangeStyle = true,
	MachinePlaylist = true,
	PersonalPlaylist = true,
	Preferred = true,
	SetSummary = true,
	SongSearch = true,
	SortBy = true,
	SwitchProfile = true,

	-- These inherited integrations remain installed but are not exposed until
	-- their owning inventory capabilities are explicitly accepted.
	Leaderboard = true,
	LoadNewSongs = false,
	OnlineLobbies = false,
	PracticeMode = false,
	TestInput = true,
	ViewDownloads = false,
}

function VOLT26.SongBrowsing.IsActionEnabled(action)
	return songBrowsingActions[action] == true
end

function VOLT26.SongBrowsing.GetBpmTier(bpm)
	return math.floor((bpm + 0.5) / 10) * 10
end

function VOLT26.SongBrowsing.ParseSearch(input)
	if type(input) ~= "string" or #input == 0 then return nil end

	local normalized = input:lower()
	local difficulty
	local bpmTier

	for match in normalized:gmatch("%[(%d+)]") do
		local value = tonumber(match)
		if value <= 35 then
			difficulty = value
		else
			bpmTier = VOLT26.SongBrowsing.GetBpmTier(value)
		end
	end

	normalized = normalized:gsub("%[%d+]", ""):gsub("^%s*(.-)%s*$", "%1")
	local slash = normalized:find("/", 1, true)
	local packName
	local songName
	if slash then
		packName = normalized:sub(1, slash - 1)
		songName = normalized:sub(slash + 1)
	else
		songName = normalized
	end
	if packName == "" then packName = nil end
	if songName == "" then songName = nil end

	if not (packName or songName or difficulty or bpmTier) then return nil end
	return {
		bpmTier = bpmTier,
		difficulty = difficulty,
		packName = packName,
		songName = songName,
	}
end

function VOLT26.SongBrowsing.Search(input)
	local query = VOLT26.SongBrowsing.ParseSearch(input)
	if not query then return nil end

	local style = GAMESTATE:GetCurrentStyle()
	if not style then return { searchText=input, candidates={} } end
	local stepsType = style:GetStepsType()
	local candidates = {}

	for song in ivalues(SONGMAN:GetAllSongs()) do
		local matches = song:HasStepsType(stepsType)
		if matches and query.songName then
			local displayTitle = song:GetDisplayFullTitle():lower()
			local translitTitle = song:GetTranslitFullTitle():lower()
			matches = displayTitle:find(query.songName, 1, true) ~= nil
				or translitTitle:find(query.songName, 1, true) ~= nil
		end
		if matches and query.packName then
			matches = song:GetGroupName():lower():find(query.packName, 1, true) ~= nil
		end
		if matches and query.difficulty then
			matches = false
			for steps in ivalues(song:GetStepsByStepsType(stepsType)) do
				if steps:GetDifficulty() ~= "Difficulty_Edit" and steps:GetMeter() == query.difficulty then
					matches = true
					break
				end
			end
		end
		if matches and query.bpmTier then
			local bpms = song:GetDisplayBpms()
			local lowBpm = tonumber(bpms[1]) or 0
			local highBpm = tonumber(bpms[2]) or lowBpm
			if highBpm < lowBpm then lowBpm, highBpm = highBpm, lowBpm end
			local lowTier = VOLT26.SongBrowsing.GetBpmTier(lowBpm)
			local highTier = VOLT26.SongBrowsing.GetBpmTier(highBpm)
			matches = lowTier <= query.bpmTier and query.bpmTier <= highTier
		end
		if matches then candidates[#candidates+1] = song end
	end

	return { searchText=input, candidates=candidates }
end

function VOLT26.SongBrowsing.SelectSearchResult(song, screen)
	if not song or not screen then return false end
	GAMESTATE:SetPreferredSong(song)
	local sortOrder = GAMESTATE:GetSortOrder()
	if sortOrder == "SortOrder_Preferred"
		or sortOrder == "SortOrder_Popularity"
		or sortOrder == "SortOrder_Recent" then
		screen:GetMusicWheel():ChangeSort("SortOrder_Group")
	end
	screen:SetNextScreenName("ScreenReloadSSM")
	screen:StartTransitioningScreen("SM_GoToNextScreen")
	return true
end

function VOLT26.SongBrowsing.ChangeSort(order)
	if type(order) ~= "string" or order == "" then return false end
	MESSAGEMAN:Broadcast("Sort", { order=order })
	MESSAGEMAN:Broadcast("ResetHeaderText")
	return true
end

function VOLT26.SongBrowsing.UsePlaylist(path, screen)
	if type(path) ~= "string" or path == "" or not screen then return false end
	SONGMAN:SetPreferredSongs(path, true)
	if not SONGMAN:GetPreferredSortSongs() then return false end
	screen:GetMusicWheel():ChangeSort("SortOrder_Preferred")
	return true
end

VOLT26.Gameplay = {}

function VOLT26.Gameplay.GetMode()
	if VOLT26.State.Global.GameMode == "Casual" then VOLT26.State.Global.GameMode = "ITG" end
	return VOLT26.State.Global.GameMode
end

function VOLT26.Gameplay.IsCasual()
	return false
end

function VOLT26.Gameplay.GetCurrentStageIndex()
	return VOLT26.State.Global.Stages.PlayedThisGame + 1
end

function VOLT26.Gameplay.GetActiveStageIndex()
	return VOLT26.State.Global.Stages.ActiveIndex or VOLT26.Gameplay.GetCurrentStageIndex()
end

function VOLT26.Gameplay.GetPlayerStageState(player)
	local state = VOLT26.Core.GetPlayerState(player)
	return state.Stages.Stats[VOLT26.Gameplay.GetActiveStageIndex()]
end

function VOLT26.Gameplay.BeginPlayerStage(player)
	local state = VOLT26.Core.GetPlayerState(player)
	local stageIndex = VOLT26.Gameplay.GetCurrentStageIndex()
	VOLT26.State.Global.Stages.ActiveIndex = stageIndex
	state.Stages.Stats[stageIndex] = {}
	return VOLT26.Gameplay.GetPlayerStageState(player)
end

function VOLT26.Gameplay.StorePlayerOptions(player)
	VOLT26.Core.GetPlayerState(player).PlayerOptionsString =
		GAMESTATE:GetPlayerState(player):GetPlayerOptionsString("ModsLevel_Preferred")
end

function VOLT26.Gameplay.IsReload()
	return VOLT26.State.Global.GameplayReloadCheck == true
end

function VOLT26.Gameplay.MarkIntroComplete()
	VOLT26.State.Global.GameplayReloadCheck = true
end

function VOLT26.Gameplay.LeaveScreen()
	VOLT26.State.Global.GameplayReloadCheck = false
end

VOLT26.GameplayStats = {}

function VOLT26.GameplayStats.SetPeakNPS(player, value)
	local key = ToEnumShortString(player)
	local peak = math.max(0, tonumber(value) or 0)
	VOLT26.State.Global.GameplayStats.PeakNPS[key] = peak
	return peak
end

function VOLT26.GameplayStats.GetPeakNPS(player)
	return VOLT26.State.Global.GameplayStats.PeakNPS[ToEnumShortString(player)]
end

function VOLT26.GameplayStats.GetPeakScale(player, otherPlayer)
	local mine = VOLT26.GameplayStats.GetPeakNPS(player) or 0
	local theirs = VOLT26.GameplayStats.GetPeakNPS(otherPlayer) or 0
	if mine <= 0 or theirs <= 0 or mine >= theirs then return 1 end
	return mine / theirs
end

function VOLT26.GameplayStats.GetDigitCount(value, minimum)
	value = math.floor(math.max(0, tonumber(value) or 0))
	local digits = value > 0 and math.floor(math.log10(value)) + 1 or 1
	return math.max(math.max(1, tonumber(minimum) or 1), digits)
end

function VOLT26.GameplayStats.SetMeasureSegments(player, segments)
	local state = VOLT26.Core.GetPlayerState(player)
	state.GameplayStats.MeasureSegments = DeepCopy(segments or {})
	return VOLT26.GameplayStats.GetMeasureSegments(player)
end

function VOLT26.GameplayStats.GetMeasureSegments(player)
	local state = VOLT26.Core.GetPlayerState(player)
	return DeepCopy(state.GameplayStats.MeasureSegments or {})
end

function VOLT26.GameplayStats.IsEndOfSegment(currentMeasure, segments, segmentIndex)
	local segment = segments and segments[segmentIndex] or nil
	if not segment then return false end
	local length = segment.streamEnd - segment.streamStart
	local count = math.floor(currentMeasure - segment.streamStart) + 1
	return count > length
end

function VOLT26.GameplayStats.GetMeasureText(currentMeasure, segments, segmentIndex, isLookAhead)
	segments = segments or {}
	if currentMeasure < 0 then
		local first = segments[1]
		if not first then return "" end
		if not isLookAhead then
			local negativeSpace = math.floor(currentMeasure * -1) + 1
			if not first.isBreak then return "(" .. negativeSpace .. ")" end
			return "(" .. negativeSpace + first.streamEnd - first.streamStart .. ")"
		elseif not first.isBreak then
			segmentIndex = segmentIndex - 1
		end
	end
	local segment = segments[segmentIndex]
	if not segment then return "" end
	local length = segment.streamEnd - segment.streamStart
	local count = math.floor(currentMeasure - segment.streamStart) + 1
	if segment.isBreak then
		return "(" .. (isLookAhead and length or length - count + 1) .. ")"
	end
	if not isLookAhead and count ~= 0 then return count .. "/" .. length end
	return tostring(length)
end

function VOLT26.GameplayStats.BuildCumulativeSeconds(durations, musicRate)
	local rate = VOLT26.MusicSelection.NormalizeMusicRate(musicRate)
	local result, total = {}, 0
	for _, duration in ipairs(durations or {}) do
		total = total + math.max(0, tonumber(duration) or 0) / rate
		result[#result + 1] = total
	end
	return result
end

function VOLT26.GameplayStats.GetRemainingSeconds(totalSeconds, elapsedOffset, currentSeconds, musicRate)
	local total = math.max(0, tonumber(totalSeconds) or 0)
	local offset = math.max(0, tonumber(elapsedOffset) or 0)
	local current = math.max(0, tonumber(currentSeconds) or 0)
	local rate = VOLT26.MusicSelection.NormalizeMusicRate(musicRate)
	return clamp(total - offset - current / rate, 0, total)
end

function VOLT26.GameplayStats.InterpolateVertex(first, second, offset)
	local x1, x2 = first[1][1], second[1][1]
	if x1 == x2 then return {{offset, first[1][2], 0}, DeepCopy(first[2])} end
	local ratio = clamp((offset - x1) / (x2 - x1), 0, 1)
	return {
		{offset, first[1][2] * (1 - ratio) + second[1][2] * ratio, 0},
		lerp_color(ratio, first[2], second[2]),
	}
end

VOLT26.TargetScore = {}

function VOLT26.TargetScore.ResolveTarget(index, machineBest, personalBest, gradeThresholds, fallbackIndex)
	index = tonumber(index) or 11
	local target
	if index == 17 then target = tonumber(machineBest)
	elseif index == 18 then target = tonumber(personalBest)
	else target = gradeThresholds and tonumber(gradeThresholds[index]) end
	if not target or target <= 0 then
		target = gradeThresholds and tonumber(gradeThresholds[fallbackIndex or 11]) or 0
	end
	return clamp(target or 0, 0, 1)
end

function VOLT26.TargetScore.CalculateProgress(actual, currentPossible, totalPossible, target)
	actual = tonumber(actual) or 0
	currentPossible = math.max(0, tonumber(currentPossible) or 0)
	totalPossible = math.max(0, tonumber(totalPossible) or 0)
	target = clamp(tonumber(target) or 0, 0, 1)
	local difference = totalPossible > 0 and (actual - target * currentPossible) / totalPossible or 0
	difference = math.max(difference, -target)
	local places = 2
	while math.abs(difference) < 0.1995 / math.pow(10, places)
		and totalPossible >= 2 * math.pow(10, places + 2) and places < 4 do
		places = places + 1
	end
	return {
		difference=difference,
		places=places,
		missed=(currentPossible - actual) > totalPossible * (1 - target),
	}
end

function VOLT26.TargetScore.NewTracker()
	return {missed=false}
end

function VOLT26.TargetScore.UpdateTracker(tracker, actual, currentPossible, totalPossible, target)
	local progress = VOLT26.TargetScore.CalculateProgress(actual, currentPossible, totalPossible, target)
	local newlyMissed = progress.missed and tracker.missed ~= true
	tracker.missed = tracker.missed or progress.missed
	return progress, newlyMissed
end

function VOLT26.TargetScore.GetMissedAction(player, eventMode)
	if eventMode ~= true then return nil end
	local action = VOLT26.Options.GetPlayerModifiers(player).ActionOnMissedTarget
	if action == "Fail" or action == "Restart" then return action end
	return nil
end

VOLT26.CourseSpeed = {
	Increment = {XMod=0.25, MMod=10, CMod=10},
	UpperLimit = {XMod=10, MMod=2000, CMod=2000},
}

function VOLT26.CourseSpeed.Adjust(kind, value, direction)
	local increment = VOLT26.CourseSpeed.Increment[kind]
	local upper = VOLT26.CourseSpeed.UpperLimit[kind]
	value = tonumber(value)
	if not increment or not upper or not value or (direction ~= -1 and direction ~= 1) then return nil end
	local adjusted = value + increment * direction
	return adjusted > 0 and adjusted <= upper and adjusted or value
end

function VOLT26.CourseSpeed.Format(kind, value)
	if kind == "XMod" then return ("mod,%.2fx"):format(value) end
	if kind == "MMod" then return ("mod,m%d"):format(value) end
	if kind == "CMod" then return ("mod,c%d"):format(value) end
	return nil
end

function VOLT26.CourseSpeed.GetActive(playerOptions)
	if not playerOptions then return nil end
	local cmod, mmod, xmod = playerOptions:CMod(), playerOptions:MMod(), playerOptions:XMod()
	if cmod ~= nil then return "CMod", cmod end
	if mmod ~= nil then return "MMod", mmod end
	if xmod ~= nil then return "XMod", xmod end
	return nil
end

VOLT26.Versus = {}

function VOLT26.Versus.CanCompare(firstModifiers, secondModifiers)
	return firstModifiers and secondModifiers
		and firstModifiers.ShowExScore == secondModifiers.ShowExScore
end

function VOLT26.Versus.NewScoreState()
	return {[PLAYER_1]=0, [PLAYER_2]=0}
end

function VOLT26.Versus.CalculateDancePointRatio(actual, possible)
	possible = tonumber(possible) or 0
	return possible > 0 and (tonumber(actual) or 0) / possible or 0
end

function VOLT26.Versus.UpdateScore(state, player, score)
	if player ~= PLAYER_1 and player ~= PLAYER_2 then return "Tie" end
	state[player] = tonumber(score) or 0
	if state[PLAYER_1] == state[PLAYER_2] then return "Tie" end
	return state[PLAYER_1] > state[PLAYER_2] and PLAYER_1 or PLAYER_2
end

VOLT26.Session = {}

local sessionTapJudgments = { "W0", "W1", "W2", "W3", "W4", "W5" }

local function sessionTime(value)
	return math.max(0, tonumber(value) or 0)
end

function VOLT26.Session.NewTimer(now)
	now = sessionTime(now)
	return {
		schema_version=1,
		screen_started_at=now,
		active_started_at=now,
		active_seconds=0,
		paused=false,
		finished=false,
		completed=false,
	}
end

function VOLT26.Session.SetTimerPaused(timer, paused, now)
	if type(timer) ~= "table" or timer.finished then return false end
	paused = paused == true
	if timer.paused == paused then return false end
	now = sessionTime(now)
	if paused then
		timer.active_seconds = sessionTime(timer.active_seconds)
		if timer.active_started_at then
			timer.active_seconds = timer.active_seconds + math.max(0, now - sessionTime(timer.active_started_at))
		end
		timer.active_started_at = nil
	else
		timer.active_started_at = now
	end
	timer.paused = paused
	return true
end

function VOLT26.Session.FinishTimer(timer, now)
	if type(timer) ~= "table" then return nil end
	if timer.finished then return DeepCopy(timer) end
	now = sessionTime(now)
	timer.active_seconds = sessionTime(timer.active_seconds)
	if not timer.paused and timer.active_started_at then
		timer.active_seconds = timer.active_seconds + math.max(0, now - sessionTime(timer.active_started_at))
	end
	timer.active_started_at = nil
	timer.screen_seconds = math.max(0, now - sessionTime(timer.screen_started_at))
	timer.active_seconds = math.min(timer.screen_seconds, math.max(0, timer.active_seconds))
	timer.finished = true
	return DeepCopy(timer)
end

function VOLT26.Session.BeginGameplay(player, now)
	local stage = VOLT26.Gameplay.GetPlayerStageState(player)
	if not stage then return nil end
	stage.session = VOLT26.Session.NewTimer(now)
	return DeepCopy(stage.session)
end

function VOLT26.Session.SetGameplayPaused(player, paused, now)
	local stage = VOLT26.Gameplay.GetPlayerStageState(player)
	return stage and VOLT26.Session.SetTimerPaused(stage.session, paused, now) or false
end

function VOLT26.Session.FinishGameplay(player, now)
	local stage = VOLT26.Gameplay.GetPlayerStageState(player)
	if not stage then return nil end
	return VOLT26.Session.FinishTimer(stage.session, now)
end

function VOLT26.Session.MarkStageCompleted(player, now)
	local stage = VOLT26.Gameplay.GetPlayerStageState(player)
	if not stage or not stage.session then return false end
	if not stage.session.finished then VOLT26.Session.FinishTimer(stage.session, now) end
	stage.session.completed = true
	return true
end

function VOLT26.Session.CountTapHits(columnJudgments)
	local total = 0
	for _, judgments in pairs(type(columnJudgments) == "table" and columnJudgments or {}) do
		if type(judgments) == "table" then
			for _, judgment in ipairs(sessionTapJudgments) do
				total = total + math.max(0, tonumber(judgments[judgment]) or 0)
			end
		end
	end
	return total
end

function VOLT26.Session.SummarizeStages(stages)
	local summary = {songs_played=0, tap_hits=0, screen_seconds=0, active_seconds=0}
	for _, stage in pairs(type(stages) == "table" and stages or {}) do
		if type(stage) == "table" then
			local session = type(stage.session) == "table" and stage.session or nil
			local screenSeconds = session and session.screen_seconds or stage.duration
			local columnJudgments = stage.telemetry and stage.telemetry.column_judgments
				or stage.column_judgments
			local include = session and session.completed == true
				or (not session and (screenSeconds ~= nil or columnJudgments ~= nil))
			if include then
				summary.songs_played = summary.songs_played + 1
				summary.screen_seconds = summary.screen_seconds + sessionTime(screenSeconds)
				summary.active_seconds = summary.active_seconds
					+ sessionTime(session and session.active_seconds or screenSeconds)
				summary.tap_hits = summary.tap_hits + VOLT26.Session.CountTapHits(columnJudgments)
			end
		end
	end
	return summary
end

function VOLT26.Session.GetSummary(player)
	local state = VOLT26.Core.GetPlayerState(player)
	return VOLT26.Session.SummarizeStages(state and state.Stages.Stats or nil)
end

function VOLT26.Session.FormatDuration(seconds)
	local total = math.floor(sessionTime(seconds) + 0.5)
	local hours = math.floor(total / 3600)
	local minutes = math.floor(total % 3600 / 60)
	return {hours=hours, minutes=minutes, seconds=total % 60}
end

function VOLT26.Session.GetProfileSummary(player)
	if not PROFILEMAN:IsPersistentProfile(player) then return nil end
	local profile = PROFILEMAN:GetProfile(player)
	if not profile then return nil end
	return {
		display_name=profile:GetDisplayName(),
		calories=profile:GetIgnoreStepCountCalories() and nil or round(profile:GetCaloriesBurnedToday()),
		total_songs=profile:GetNumTotalSongsPlayed(),
	}
end

VOLT26.Telemetry = {}

local ex_count_keys = { "W0", "W1", "W2", "W3", "W4", "W5", "Miss", "HitMine", "Held", "LetGo" }

local function new_ex_counts()
	local counts = {}
	for key in ivalues(ex_count_keys) do counts[key] = 0 end
	counts.W0_total = 0
	return counts
end

function VOLT26.Telemetry.IsEnabled()
	return not VOLT26.Gameplay.IsCasual()
end

function VOLT26.Telemetry.GetStage(player)
	return VOLT26.Gameplay.GetPlayerStageState(player)
end

function VOLT26.Telemetry.GetSnapshot(player)
	local stage = VOLT26.Telemetry.GetStage(player)
	return stage and stage.telemetry or nil
end

function VOLT26.Telemetry.Begin(player)
	local stage = VOLT26.Telemetry.GetStage(player)
	if not stage then return nil end

	local columns = {}
	for index=1,GAMESTATE:GetCurrentStyle():ColumnsPerPlayer() do
		columns[index] = {
			W0=0, W1=0, W2=0, W3=0, W4=0, W5=0, Miss=0,
			MissBecauseHeld=0,
			Early={ W0=0, W1=0, W2=0, W3=0, W4=0, W5=0 },
		}
	end

	stage.telemetry = {
		ex_counts = new_ex_counts(),
		offsets = {},
		column_judgments = columns,
	}

	-- Compatibility fields for evaluation actors that have not migrated yet.
	stage.ex_counts = stage.telemetry.ex_counts
	stage.sequential_offsets = {}
	stage.column_judgments = stage.telemetry.column_judgments
	return stage.telemetry
end

function VOLT26.Telemetry.Ensure(player)
	return VOLT26.Telemetry.GetSnapshot(player) or VOLT26.Telemetry.Begin(player)
end

function VOLT26.Telemetry.RecordExJudgment(player, params)
	if params.Player ~= player or IsAutoplay(player) then return nil end
	local telemetry = VOLT26.Telemetry.Ensure(player)
	if not telemetry then return nil end

	local stats = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
	local counts = telemetry.ex_counts
	local key, is_w0 = VOLT26.Scoring.NormalizeJudgment(
		params.TapNoteScore,
		params.HoldNoteScore,
		VOLT26.Gameplay.GetMode(),
		params.TapNoteScore and VOLT26.Scoring.IsW0Judgment(params, player) or false)
	if not VOLT26.Scoring.ApplyJudgment(counts, key, stats:GetFailed(), is_w0) then return nil end
	local ex_score, actual_points, actual_possible = VOLT26.Scoring.CalculateExScore(player, counts)
	return {
		Player=player,
		ExCounts=DeepCopy(counts),
		ExScore=ex_score,
		ActualPoints=actual_points,
		ActualPossible=actual_possible,
	}
end

local function current_course_offset(player)
	if not GAMESTATE:IsCourseMode() then return 0 end
	local offset = 0
	local entries = GAMESTATE:GetCurrentTrail(player):GetTrailEntries()
	for index=1,GAMESTATE:GetCourseSongIndex() do
		offset = offset + entries[index]:GetSong():GetLastSecond()
	end
	return offset
end

function VOLT26.Telemetry.NormalizeOffsetSample(score, tapNoteOffset, position, isAutohit)
	local offset = (score == "TapNoteScore_Miss" or score == "TapNoteScore_CheckpointMiss")
		and "Miss" or tapNoteOffset
	if offset ~= "Miss" and type(offset) ~= "number" then return nil end
	return {
		position=tonumber(position) or 0,
		offset=offset,
		is_autohit=isAutohit == true,
	}
end

function VOLT26.Telemetry.RecordOffset(player, params, require_step_on_hold_heads)
	local isMiss = params.TapNoteScore == "TapNoteScore_Miss"
		or params.TapNoteScore == "TapNoteScore_CheckpointMiss"
	if params.Player ~= player or params.HoldNoteScore or (not params.TapNoteOffset and not isMiss) then return end
	local telemetry = VOLT26.Telemetry.Ensure(player)
	if not telemetry then return end

	local score = params.TapNoteScore
	local is_autohit = score == "TapNoteScore_CheckpointHit"
	if not is_autohit and not require_step_on_hold_heads and params.Notes then
		local only_hold_heads, found_note = true, false
		for _, tapnote in pairs(params.Notes) do
			found_note = true
			if tapnote:GetTapNoteType() ~= "TapNoteType_HoldHead" then
				only_hold_heads = false
				break
			end
		end
		is_autohit = found_note and only_hold_heads
	end

	local position = current_course_offset(player) + GAMESTATE:GetCurMusicSeconds()
	local sample = VOLT26.Telemetry.NormalizeOffsetSample(score, params.TapNoteOffset, position, is_autohit)
	if not sample then return end
	telemetry.offsets[#telemetry.offsets+1] = sample
	local stage = VOLT26.Telemetry.GetStage(player)
	stage.sequential_offsets[#stage.sequential_offsets+1] = { sample.position, sample.offset, sample.is_autohit }
end

function VOLT26.Telemetry.RecordColumnJudgment(player, params)
	if params.Player ~= player or not params.Notes or not params.TapNoteScore then return end
	if GAMESTATE:GetPlayerState(player):GetHealthState() == "HealthState_Dead" then return end
	local telemetry = VOLT26.Telemetry.Ensure(player)
	if not telemetry then return end
	local modifiers = VOLT26.Options.GetPlayerModifiers(player)

	for column, tapnote in pairs(params.Notes) do
		local columnData = telemetry.column_judgments[column]
		local note_type = ToEnumShortString(tapnote:GetTapNoteType())
		if columnData and (note_type == "Tap" or note_type == "HoldHead" or note_type == "Lift") then
			local judgment = ToEnumShortString(params.TapNoteScore)
			if params.EarlyTapNoteScore then
				local early = ToEnumShortString(params.EarlyTapNoteScore)
				if early ~= "None" then
					if VOLT26.Scoring.IsW0Judgment(params, player) then
						columnData.Early.W0 = columnData.Early.W0 + 1
					elseif judgment ~= "W4" and judgment ~= "W5" and judgment ~= "Miss" and columnData.Early[judgment] then
						columnData.Early[judgment] = columnData.Early[judgment] + 1
					end
					if columnData.Early[early] then columnData.Early[early] = columnData.Early[early] + 1 end
				end
			end
			if modifiers.ShowFaPlusWindow and modifiers.ShowFaPlusPane and VOLT26.Scoring.IsW0Judgment(params, player) then
				judgment = "W0"
			end
			if not columnData[judgment] then return end
			columnData[judgment] = columnData[judgment] + 1
			if note_type ~= "Lift" and judgment == "Miss" and tapnote:GetTapNoteResult():GetHeld() then
				columnData.MissBecauseHeld = columnData.MissBecauseHeld + 1
			end
		end
	end
end

VOLT26.Scoring = {}

VOLT26.Scoring.ExCountKeys = ex_count_keys

function VOLT26.Scoring.NewExCounts()
	return new_ex_counts()
end

function VOLT26.Scoring.IsW0Judgment(params, player)
	if params.Player ~= player or params.HoldNoteScore then return false end
	if params.TapNoteScore ~= "TapNoteScore_W1" or VOLT26.Gameplay.GetMode() ~= "ITG" then return false end
	if type(params.TapNoteOffset) ~= "number" then return false end
	local prefs = VOLT26.Preferences["FA+"]
	local scale = PREFSMAN:GetPreference("TimingWindowScale")
	local window = prefs.TimingWindowSecondsW1 * scale + prefs.TimingWindowAdd
	return math.abs(params.TapNoteOffset) <= window
end

function VOLT26.Scoring.NormalizeJudgment(tapNoteScore, holdNoteScore, gameMode, isW0)
	if holdNoteScore then
		local key = ToEnumShortString(holdNoteScore)
		if key == "MissedHold" then key = "LetGo" end
		if key == "Held" or key == "LetGo" then return key, false end
		return nil, false
	end
	if not tapNoteScore then return nil, false end

	local key = ToEnumShortString(tapNoteScore)
	if gameMode == "ITG" and key == "W1" and isW0 then return "W0", true end
	if gameMode ~= "ITG" then
		local tier = key:match("W(%d)")
		if tier then key = "W"..(tonumber(tier)-1) end
	end
	return key, false
end

function VOLT26.Scoring.ApplyJudgment(counts, key, failed, isW0)
	if type(counts) ~= "table" or counts[key] == nil then return false end
	if isW0 then counts.W0_total = (counts.W0_total or 0) + 1 end
	if failed then return false end
	counts[key] = counts[key] + 1
	return true
end

function VOLT26.Scoring.GetExCounts(player)
	local telemetry = VOLT26.Telemetry.GetSnapshot(player)
	return telemetry and telemetry.ex_counts or nil
end

function VOLT26.Scoring.GetExSnapshot(player)
	return DeepCopy(VOLT26.Scoring.GetExCounts(player) or VOLT26.Scoring.NewExCounts())
end

function VOLT26.Scoring.CalculateExFromRadar(counts, radar, weights, noMines)
	weights = weights or VOLT26.ExWeights
	radar = radar or {}
	local totalPossible = (radar.TapsAndHolds or 0) * (weights.W0 or 0)
		+ ((radar.Holds or 0) + (radar.Rolls or 0)) * (weights.Held or 0)
	local totalPoints = noMines and (radar.Mines or 0) * (weights.HitMine or 0) or 0
	for _, key in ipairs(ex_count_keys) do
		totalPoints = totalPoints + ((counts and counts[key]) or 0) * (weights[key] or 0)
	end
	if totalPossible <= 0 then return 0, totalPoints, totalPossible end
	local percent = math.max(0, math.floor(totalPoints / totalPossible * 10000) / 100)
	return percent, totalPoints, totalPossible
end

function VOLT26.Scoring.CalculateExScore(player, ex_counts, use_actual_w0_weight)
	if VOLT26.Gameplay.IsCasual() then return 0 end
	local steps_or_trail = GAMESTATE:IsCourseMode()
		and GAMESTATE:GetCurrentTrail(player) or GAMESTATE:GetCurrentSteps(player)
	if not steps_or_trail then return 0 end

	local sourceRadar = steps_or_trail:GetRadarValues(player)
	local radar = {
		TapsAndHolds = sourceRadar:GetValue("RadarCategory_TapsAndHolds"),
		Holds = sourceRadar:GetValue("RadarCategory_Holds"),
		Rolls = sourceRadar:GetValue("RadarCategory_Rolls"),
		Mines = sourceRadar:GetValue("RadarCategory_Mines"),
	}
	local weights = DeepCopy(VOLT26.ExWeights)
	if use_actual_w0_weight then weights.W0 = 3.5 end
	local player_options = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
	local counts = ex_counts or VOLT26.Scoring.GetExCounts(player)
	return VOLT26.Scoring.CalculateExFromRadar(counts, radar, weights, player_options:NoMines())
end

VOLT26.Results = {}

local ResultTapWindows = {"W1", "W2", "W3", "W4", "W5", "Miss"}
local ResultRadarCategories = {"Hands", "Holds", "Mines", "Rolls"}

function VOLT26.Results.GetStageStats(player)
	local stageStats = STATSMAN:GetCurStageStats()
	local style = GAMESTATE:GetCurrentStyle()
	if style and ToEnumShortString(style:GetStyleType()) == "TwoPlayersSharedSides" then
		return stageStats:GetRoutineStageStats()
	end
	return stageStats:GetPlayerStageStats(player)
end

function VOLT26.Results.GetCurrent(player)
	local stats = VOLT26.Results.GetStageStats(player)
	local modifiers = VOLT26.Options.GetPlayerModifiers(player)
	local telemetry = VOLT26.Telemetry.GetSnapshot(player) or {}
	local judgments = {}
	for _, window in ipairs(ResultTapWindows) do
		judgments[window] = stats:GetTapNoteScores("TapNoteScore_"..window)
	end

	local capturedExJudgments = VOLT26.Scoring.GetExCounts(player) or {}
	local exJudgments = DeepCopy(capturedExJudgments)
	local radar = {actual={}, possible={}}
	for _, category in ipairs(ResultRadarCategories) do
		radar.actual[category] = stats:GetRadarActual():GetValue("RadarCategory_"..category)
		radar.possible[category] = stats:GetRadarPossible():GetValue("RadarCategory_"..category)
	end
	if VOLT26.Gameplay.GetMode() == "ITG" then
		exJudgments.W0 = capturedExJudgments.W0_total or 0
		exJudgments.W1 = math.max(0, judgments.W1 - exJudgments.W0)
		for _, window in ipairs({"W2", "W3", "W4", "W5", "Miss"}) do
			exJudgments[window] = judgments[window]
		end
		if not modifiers.TimingWindows[4] then exJudgments.W4 = nil end
		if not modifiers.TimingWindows[5] then exJudgments.W5 = nil end
	end
	local stepsOrTrail = GAMESTATE:IsCourseMode()
		and GAMESTATE:GetCurrentTrail(player) or GAMESTATE:GetCurrentSteps(player)
	local chartRadar = stepsOrTrail and stepsOrTrail:GetRadarValues(player) or nil
	if chartRadar then
		exJudgments.totalSteps = chartRadar:GetValue("RadarCategory_TapsAndHolds")
		for _, category in ipairs({"Holds", "Mines", "Rolls"}) do
			local possible = chartRadar:GetValue("RadarCategory_"..category)
			exJudgments["total"..category] = possible
			exJudgments[category] = radar.actual[category]
		end
		local options = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
		if options:NoMines() then
			exJudgments.Mines, exJudgments.totalMines = 0, 0
		else
			exJudgments.Mines = exJudgments.totalMines - radar.actual.Mines
		end
	end

	local exPercent = VOLT26.Scoring.CalculateExScore(player)
	local grade = stats:GetGrade()
	local song = GAMESTATE:GetCurrentSong()
	if song and song:GetDisplayFullTitle() == "D" then grade = "Grade_Tier99" end
	if exPercent == 100 then grade = "Grade_Tier00" end

	return {
		failed = stats:GetFailed(),
		percentDP = stats:GetPercentDancePoints(),
		exPercent = exPercent,
		grade = grade,
		judgments = judgments,
		exJudgments = exJudgments,
		columnJudgments = DeepCopy(telemetry.column_judgments or {}),
		radar = radar,
		showEx = modifiers.ShowExScore == true,
		timingWindows = DeepCopy(modifiers.TimingWindows),
	}
end

function VOLT26.Scoring.GetDetailedJudgments(player)
	return DeepCopy(VOLT26.Results.GetCurrent(player).exJudgments)
end

local function EventMachineRecordIndex(player, stats, machineHighScores)
	local current = stats:GetHighScore()
	local profile = PROFILEMAN:GetProfile(player)
	local lastUsedName = profile and profile:GetLastUsedHighScoreName() or ""
	for index, highScore in ipairs(machineHighScores) do
		local nameMatches = current:GetName() == lastUsedName
		if #GAMESTATE:GetHumanPlayers() == 1 and current:GetName() == "EVNT" then nameMatches = true end
		if not nameMatches and #GAMESTATE:GetHumanPlayers() > 1 then
			local playedStage = STATSMAN:GetPlayedStageStats(1)
			local otherStats = playedStage and playedStage:GetPlayerStageStats(OtherPlayer[player]) or nil
			nameMatches = otherStats == nil or highScore:GetScore() ~= otherStats:GetHighScore():GetScore()
		end
		if not nameMatches and #GAMESTATE:GetHumanPlayers() > 1 then
			local playedStage = STATSMAN:GetPlayedStageStats(1)
			local otherStats = playedStage and playedStage:GetPlayerStageStats(OtherPlayer[player]) or nil
			nameMatches = otherStats == nil or highScore:GetScore() ~= otherStats:GetHighScore():GetScore()
		end
		if current:GetScore() == highScore:GetScore()
			and current:GetDate() == highScore:GetDate()
			and nameMatches then
			return index - 1
		end
	end
	return -1
end

function VOLT26.Results.GetRecordStatus(player)
	local stats = VOLT26.Results.GetStageStats(player)
	local songOrCourse = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or GAMESTATE:GetCurrentSong()
	local stepsOrTrail = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player) or GAMESTATE:GetCurrentSteps(player)
	local machineHighScores = PROFILEMAN:GetMachineProfile():GetHighScoreList(songOrCourse, stepsOrTrail):GetHighScores()
	local maxMachine = PREFSMAN:GetPreference("MaxHighScoresPerListForMachine")
	local machineIndex = stats:GetMachineHighScoreIndex()
	local personalIndex = stats:GetPersonalHighScoreIndex()
	local eligibleScore = stats:GetPercentDancePoints() >= 0.01

	if GAMESTATE:IsEventMode() then
		machineIndex = EventMachineRecordIndex(player, stats, machineHighScores)
	end

	local earnedMachine = eligibleScore and machineIndex >= 0
	if GAMESTATE:IsEventMode() and eligibleScore then
		if #machineHighScores == 0 then
			earnedMachine = true
		else
			local cutoff = machineHighScores[math.min(maxMachine, #machineHighScores)]
			earnedMachine = cutoff ~= nil and stats:GetHighScore():GetPercentDP() >= cutoff:GetPercentDP()
		end
	end

	local result = {
		machineIndex = machineIndex,
		personalIndex = personalIndex,
		earnedMachine = earnedMachine,
		earnedPersonal = eligibleScore and personalIndex >= 0,
		earnedTopTwoPersonal = personalIndex >= 0 and personalIndex < 2,
	}
	result.enteringName = result.earnedMachine or result.earnedPersonal
	return result
end

function VOLT26.Results.ApplyNameEntryEligibility(player)
	local status = VOLT26.Results.GetRecordStatus(player)
	VOLT26.Core.GetPlayerState(player).HighScores.EnteringName = status.enteringName
	return status
end

VOLT26.Analysis = {
	MaxScatterVerticesPerBatch = 16000,
}

function VOLT26.Analysis.GetTimingOffsets(player)
	local telemetry = VOLT26.Telemetry.GetSnapshot(player)
	return DeepCopy(telemetry and telemetry.offsets or {})
end

function VOLT26.Analysis.GetWorstJudgment(offsets)
	local worst = 1
	for _, sample in ipairs(offsets or {}) do
		if sample.offset ~= "Miss" then
			worst = math.max(worst, DetermineTimingWindow(sample.offset))
		end
	end
	return worst
end

function VOLT26.Analysis.AnalyzeTiming(offsets)
	local valid = {}
	local distribution = {}
	local signedSum, absoluteSum, maxError = 0, 0, 0
	for _, sample in ipairs(offsets or {}) do
		local value = sample.offset
		if value ~= "Miss" and not sample.is_autohit then
			valid[#valid + 1] = value
			signedSum = signedSum + value
			absoluteSum = absoluteSum + math.abs(value)
			maxError = math.max(maxError, math.abs(value))
			local bucket = round(value, 3)
			distribution[bucket] = (distribution[bucket] or 0) + 1
		end
	end

	local count = #valid
	local meanSeconds = count > 0 and signedSum / count or 0
	local sigmaSeconds = 0
	if count > 1 then
		local squaredDifferenceSum = 0
		for _, value in ipairs(valid) do
			squaredDifferenceSum = squaredDifferenceSum + math.pow(value - meanSeconds, 2)
		end
		sigmaSeconds = math.sqrt(squaredDifferenceSum / (count - 1))
	end

	return {
		count = count,
		meanAbsoluteMs = count > 0 and absoluteSum / count * 1000 or 0,
		meanOffsetMs = meanSeconds * 1000,
		sigmaMs = sigmaSeconds * 1000,
		threeSigmaMs = sigmaSeconds * 3000,
		maxErrorMs = maxError * 1000,
		worstOffsetSeconds = maxError,
		distribution = distribution,
	}
end

function VOLT26.Analysis.SmoothDistribution(distribution, worstWindow)
	local smoothed = {}
	local weights = {0.045, 0.090, 0.180, 0.370, 0.180, 0.090, 0.045}
	local highestCount = 0
	for _, count in pairs(distribution or {}) do highestCount = math.max(highestCount, count) end
	local millisecondLimit = math.floor(worstWindow * 1000 + 0.5)
	for millisecond=-millisecondLimit,millisecondLimit do
		local value = 0
		for offset=-3,3 do
			local source = round(clamp(millisecond + offset, -millisecondLimit, millisecondLimit) / 1000, 3)
			value = value + (distribution[source] or 0) * weights[offset + 4]
		end
		smoothed[round(millisecond / 1000, 3)] = value
	end
	return {values=smoothed, highestCount=highestCount}
end

function VOLT26.Analysis.GetTimeline(player)
	if GAMESTATE:IsCourseMode() then
		local segments, elapsed = {}, 0
		local trail = GAMESTATE:GetCurrentTrail(player)
		for _, entry in ipairs(trail and trail:GetTrailEntries() or {}) do
			local duration = entry:GetSong():GetLastSecond()
			segments[#segments + 1] = {startSecond=elapsed, endSecond=elapsed + duration}
			elapsed = elapsed + duration
		end
		return {firstSecond=0, lastSecond=elapsed, segments=segments}
	end

	local steps = GAMESTATE:GetCurrentSteps(player)
	local song = GAMESTATE:GetCurrentSong()
	local firstSecond = steps and math.min(steps:GetTimingData():GetElapsedTimeFromBeat(0), 0) or 0
	return {firstSecond=firstSecond, lastSecond=song and song:GetLastSecond() or 0, segments={}}
end

function VOLT26.Analysis.BuildScatterBatches(offsets, timeline, width, height, worstWindow)
	local batches = {{}}
	local maxPoints = math.floor(VOLT26.Analysis.MaxScatterVerticesPerBatch / 4)
	local lastSecond = math.max(timeline.lastSecond, timeline.firstSecond + 0.001)
	for _, sample in ipairs(offsets or {}) do
		local batch = batches[#batches]
		if #batch >= maxPoints then batch = {}; batches[#batches + 1] = batch end
		local isMiss = sample.offset == "Miss"
		local noteSecond = sample.position - (isMiss and worstWindow or sample.offset)
		batch[#batch + 1] = {
			x = clamp(scale(noteSecond, timeline.firstSecond, lastSecond + 0.05, 0, width), 0, width),
			y = isMiss and 0 or clamp(scale(sample.offset, worstWindow, -worstWindow, 0, height), 0, height),
			offset = sample.offset,
			isMiss = isMiss,
		}
	end
	return batches
end

VOLT26.Failure = {}

function VOLT26.Failure.GetSnapshot(player)
	local stage = VOLT26.Gameplay.GetPlayerStageState(player)
	local failure = stage and stage.failure or nil
	return failure and DeepCopy(failure) or nil
end

function VOLT26.Failure.GetCourseCumulativeLengths(player)
	if not GAMESTATE:IsCourseMode() then return nil end
	local result, seconds = {}, 0
	local trail = GAMESTATE:GetCurrentTrail(player)
	if not trail then return result end
	local rate = VOLT26.MusicSelection.GetMusicRate()
	for _, entry in ipairs(trail:GetTrailEntries()) do
		seconds = seconds + entry:GetSong():GetLastSecond() / rate
		result[#result+1] = seconds
	end
	return result
end

function VOLT26.Failure.GetCurrentPosition(player)
	local seconds = GAMESTATE:GetPlayerState(player):GetSongPosition():GetMusicSecondsVisible()
		/ VOLT26.MusicSelection.GetMusicRate()
	if GAMESTATE:IsCourseMode() then
		local cumulative = VOLT26.Failure.GetCourseCumulativeLengths(player)
		local course_index = GAMESTATE:GetCourseSongIndex()
		if course_index > 0 then seconds = seconds + (cumulative[course_index] or 0) end
	end
	return seconds
end

function VOLT26.Failure.GetTotalLength(player)
	local seconds = 0
	if GAMESTATE:IsCourseMode() then
		local trail = GAMESTATE:GetCurrentTrail(player)
		if trail then seconds = trail:GetLengthSeconds() end
	else
		local song = GAMESTATE:GetCurrentSong()
		if song then seconds = song:GetLastSecond() end
	end
	return math.max(0, seconds) / VOLT26.MusicSelection.GetMusicRate()
end

function VOLT26.Failure.Record(player)
	local stage = VOLT26.Gameplay.GetPlayerStageState(player)
	if not stage then return end
	local player_state = GAMESTATE:GetPlayerState(player)
	local death_second = VOLT26.Failure.GetCurrentPosition(player)
	local total_seconds = VOLT26.Failure.GetTotalLength(player)
	local graph_denominator = total_seconds
	local graph_label = total_seconds - death_second

	if GAMESTATE:IsCourseMode() then
		local cumulative = VOLT26.Failure.GetCourseCumulativeLengths(player)
		graph_denominator = cumulative[GAMESTATE:GetCourseSongIndex()+1] or total_seconds
		graph_label = total_seconds > 0 and death_second / total_seconds or 0
	end

	local failure = VOLT26.Failure.BuildSnapshot(death_second, total_seconds, graph_denominator, graph_label)

	local current_measure = math.floor(player_state:GetSongPosition():GetSongBeatVisible() / 4)
	local streams = VOLT26.Core.GetPlayerState(player).Streams
	if streams and streams.NotesPerMeasure and (streams.NotesPerMeasure[current_measure+1] or 0) >= 16 then
		for _, stream in ipairs(VOLT26.GameplayStats.GetMeasureSegments(player)) do
			if current_measure >= stream.streamStart and current_measure < stream.streamEnd then
				local run = current_measure - stream.streamStart + 1
				local total = stream.streamEnd - stream.streamStart
				failure.death_measures = string.format("%s/%s", run, total)
				break
			end
		end
	end

	stage.failure = failure
	-- Compatibility fields for the existing Evaluation graph.
	stage.TotalSeconds = failure.total_seconds
	stage.DeathSecond = failure.death_second
	stage.GraphPercentage = failure.graph_percentage
	stage.GraphLabel = failure.graph_label
	stage.DeathMeasures = failure.death_measures
	return DeepCopy(failure)
end

function VOLT26.Failure.BuildSnapshot(deathSecond, totalSeconds, graphDenominator, graphLabel)
	local total = math.max(0, tonumber(totalSeconds) or 0)
	local death = clamp(tonumber(deathSecond) or 0, 0, total)
	local denominator = math.max(0, tonumber(graphDenominator) or total)
	return {
		total_seconds=total,
		death_second=death,
		graph_percentage=denominator > 0 and clamp(death / denominator, 0, 1) or 0,
		graph_label=math.max(0, tonumber(graphLabel) or (total - death)),
	}
end

function VOLT26.Failure.NewExitGuard()
	return { used_autoplay = { [PLAYER_1]=false, [PLAYER_2]=false } }
end

function VOLT26.Failure.ObserveJudgment(guard, params)
	if params.Player and IsAutoplay(params.Player) then
		guard.used_autoplay[params.Player] = true
	end
end

function VOLT26.Failure.WasPrematureExit()
	local stage_stats = STATSMAN:GetCurStageStats()
	local premature
	if stage_stats.GaveUp then
		premature = stage_stats:GaveUp()
	else
		local song = GAMESTATE:GetCurrentSong()
		premature = song and GAMESTATE:GetCurMusicSeconds() < song:GetLastSecond() or false
	end

	if GAMESTATE:IsCourseMode() then
		local course = GAMESTATE:GetCurrentCourse()
		if course and GAMESTATE:GetCourseSongIndex() + 1 < course:GetNumCourseEntries() then
			premature = true
		end
	end
	return premature
end

function VOLT26.Failure.ReconcileExit(guard)
	local premature = VOLT26.Failure.WasPrematureExit()
	local reconciled = {}
	for player in ivalues(GAMESTATE:GetEnabledPlayers()) do
		local shouldFail = VOLT26.Failure.ShouldFailAttempt(premature, guard.used_autoplay[player])
		if shouldFail then
			STATSMAN:GetCurStageStats():GetPlayerStageStats(player):FailPlayer()
		end
		reconciled[player] = shouldFail
	end
	return reconciled
end

function VOLT26.Failure.ShouldFailAttempt(premature, usedAutoplay)
	return premature == true or usedAutoplay == true
end

VOLT26.Evaluation = {}

function VOLT26.Evaluation.GetStageCount()
	return math.max(0, tonumber(VOLT26.State.Global.Stages.PlayedThisGame) or 0)
end

function VOLT26.Evaluation.GetStageContext(stageIndex)
	local context = VOLT26.State.Global.Stages.Stats[stageIndex]
	return type(context) == "table" and DeepCopy(context) or nil
end

function VOLT26.Evaluation.GetPlayerStageSnapshot(player, stageIndex)
	local state = VOLT26.Core.GetPlayerState(player)
	local stage = state and state.Stages.Stats[stageIndex] or nil
	if type(stage) ~= "table" then return nil end
	return DeepCopy(stage.result_snapshot or stage)
end

function VOLT26.Evaluation.GetProfilesUsed(player)
	local profiles, seen = {}, {}
	for stageIndex=1,VOLT26.Evaluation.GetStageCount() do
		local snapshot = VOLT26.Evaluation.GetPlayerStageSnapshot(player, stageIndex)
		local profile = snapshot and snapshot.profile or nil
		if profile and not seen[profile] then
			profiles[#profiles + 1] = profile
			seen[profile] = true
		end
	end
	return profiles
end

function VOLT26.Evaluation.BuildPlayerSnapshot(player)
	local pn = ToEnumShortString(player)
	local modifiers = VOLT26.Options.GetPlayerModifiers(player)
	local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
	local result = VOLT26.Results.GetCurrent(player)
	local judgments = DeepCopy(result.judgments)
	local showEx = (modifiers.ShowFaPlusWindow and modifiers.ShowFaPlusPane) or modifiers.ShowExScore
	if showEx then
		judgments.W0 = result.exJudgments.W0 or 0
		judgments.W1 = result.exJudgments.W1 or 0
	end

	local steps, difficulty, meter, stepartist
	if GAMESTATE:IsCourseMode() then
		steps = GAMESTATE:GetCurrentTrail(player)
		if steps then
			difficulty = steps:GetDifficulty()
			meter = steps:GetMeter()
		end
		local course = GAMESTATE:GetCurrentCourse(player)
		stepartist = course and course:GetScripter() or nil
	else
		steps = GAMESTATE:GetCurrentSteps(player)
		local playedSteps = pss:GetPlayedSteps()[1] or steps
		if playedSteps then
			difficulty = playedSteps:GetDifficulty()
			meter = playedSteps:GetMeter()
			stepartist = playedSteps:GetAuthorCredit()
		end
	end

	return {
		schema_version=1,
		profile=PROFILEMAN:IsPersistentProfile(pn)
			and PROFILEMAN:GetProfile(player):GetDisplayName() or "[GUEST]",
		grade=result.grade,
		score=result.percentDP,
		exscore=result.exPercent,
		judgments=judgments,
		showex=modifiers.ShowExScore == true,
		steps=steps,
		difficulty=difficulty,
		meter=meter,
		stepartist=stepartist,
		timingwindows=DeepCopy(modifiers.TimingWindows),
	}
end

function VOLT26.Evaluation.StorePlayerSnapshot(player)
	local stage = VOLT26.Gameplay.GetPlayerStageState(player)
	if not stage then return nil end
	local snapshot = VOLT26.Evaluation.BuildPlayerSnapshot(player)
	stage.result_snapshot = DeepCopy(snapshot)
	-- Compatibility aliases for inherited actors that are outside EVAL-01.
	for key, value in pairs(snapshot) do stage[key] = DeepCopy(value) end
	return DeepCopy(snapshot)
end

function VOLT26.Evaluation.AllPlayersFailed()
	local players = GAMESTATE:GetHumanPlayers()
	if #players == 0 then return false end
	for player in ivalues(players) do
		if not STATSMAN:GetCurStageStats():GetPlayerStageStats(player):GetFailed() then
			return false
		end
	end
	return true
end

function VOLT26.Evaluation.StoreStageContext()
	local stageIndex = VOLT26.Gameplay.GetActiveStageIndex()
	local existing = VOLT26.State.Global.Stages.Stats[stageIndex] or {}
	local item = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or GAMESTATE:GetCurrentSong()
	local musicRate = VOLT26.MusicSelection.GetMusicRate()
	VOLT26.State.Global.Stages.Stats[stageIndex] = {
		schema_version=1,
		item=item,
		music_rate=musicRate,
		completed=existing.completed == true,
		-- Compatibility aliases for inherited actors that are outside EVAL-01.
		song=item,
		MusicRate=musicRate,
	}
	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		VOLT26.Session.MarkStageCompleted(player, GetTimeSinceStart())
	end
	return VOLT26.Evaluation.GetStageContext(stageIndex)
end

function VOLT26.Evaluation.CompleteStage()
	local stageIndex = VOLT26.Gameplay.GetActiveStageIndex()
	local context = VOLT26.State.Global.Stages.Stats[stageIndex]
	if type(context) ~= "table" or context.completed == true then return false end
	context.completed = true
	VOLT26.State.Global.Stages.PlayedThisGame = math.max(
		VOLT26.Evaluation.GetStageCount(), stageIndex
	)
	return true
end

VOLT26.EvaluationInput = {}

function VOLT26.EvaluationInput.GetPanePreferences(player)
	local state = VOLT26.Core.GetPlayerState(player)
	return state.EvalPanePrimary or 1, state.EvalPaneSecondary or 1
end

function VOLT26.EvaluationInput.FindPaneIndex(availablePaneNumbers, preferredPane)
	for index, paneNumber in ipairs(availablePaneNumbers or {}) do
		if paneNumber == preferredPane then return index end
	end
	return #availablePaneNumbers > 0 and 1 or nil
end

function VOLT26.EvaluationInput.NewCallbackController()
	local active = {}
	local controller = {}

	function controller:Activate(name, callback)
		if not callback or active[name] == callback then return end
		if active[name] then SCREENMAN:GetTopScreen():RemoveInputCallback(active[name]) end
		active[name] = callback
		SCREENMAN:GetTopScreen():AddInputCallback(callback)
	end

	function controller:Deactivate(name)
		if not active[name] then return end
		SCREENMAN:GetTopScreen():RemoveInputCallback(active[name])
		active[name] = nil
	end

	function controller:Clear()
		local names = {}
		for name in pairs(active) do names[#names + 1] = name end
		for _, name in ipairs(names) do self:Deactivate(name) end
	end

	return controller
end

function VOLT26.EvaluationInput.CanUseReplayPracticeShortcuts()
	return ThemePrefs.Get("KeyboardFeatures")
		and PREFSMAN:GetPreference("EventMode")
		and not GAMESTATE:IsCourseMode()
end

function VOLT26.EvaluationInput.CreateReplayPracticeHandler()
	local controlHeld = false
	return function(event)
		if not event or not event.DeviceInput then return false end
		local button = event.DeviceInput.button
		local isControl = button == "DeviceButton_left ctrl" or button == "DeviceButton_right ctrl"
		if isControl then
			if event.type == "InputEventType_FirstPress" then controlHeld = true end
			if event.type == "InputEventType_Release" then controlHeld = false end
			return false
		end
		if event.type ~= "InputEventType_FirstPress" or not controlHeld then return false end

		local destination, message
		if button == "DeviceButton_r" then
			destination, message = Branch.GameplayScreen(), "Replaying Song"
		elseif button == "DeviceButton_p" then
			destination, message = "ScreenPractice", "Entering Practice Mode"
		end
		if destination then
			-- The evaluated stage remains complete; replay/practice starts a new route.
			VOLT26.Util.SystemMessage(message)
			SCREENMAN:GetTopScreen():SetNextScreenName(destination):StartTransitioningScreen("SM_GoToNextScreen")
		end
		return false
	end
end

function VOLT26.EvaluationInput.CreateScreenshotHandler(requestCapture)
	local held = {MenuLeft=false, MenuRight=false}
	local chordCaptured = false
	local selectHeld = false
	return function(event)
		if not event or not event.PlayerNumber then return false end
		if PREFSMAN:GetPreference("ThreeKeyNavigation") then
			if held[event.GameButton] == nil then return false end
			held[event.GameButton] = event.type ~= "InputEventType_Release"
			if held.MenuLeft and held.MenuRight and not chordCaptured then
				chordCaptured = true
				requestCapture(event.PlayerNumber)
			elseif not held.MenuLeft or not held.MenuRight then
				chordCaptured = false
			end
		elseif event.GameButton == "Select" then
			if event.type == "InputEventType_Release" then
				selectHeld = false
			elseif event.type == "InputEventType_FirstPress" and not selectHeld then
				selectHeld = true
				requestCapture(event.PlayerNumber)
			end
		end
		return false
	end
end

function VOLT26.EvaluationInput.BuildScreenshotPrefix(title)
	local month = ("%02d-%s"):format(
		MonthOfYear() + 1,
		THEME:GetString("Months", "Month"..MonthOfYear() + 1)
	)
	local safeTitle = (title or "Evaluation"):utf8sub(1, 10):gsub("%W", "_")
	return "VOLT26/" .. Year() .. "/" .. month .. "/" .. safeTitle .. "_"
end

function VOLT26.EvaluationInput.CaptureScreenshot(player)
	local item = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or GAMESTATE:GetCurrentSong()
	local title = item and item:GetDisplayFullTitle() or "Evaluation"
	local prefix = VOLT26.EvaluationInput.BuildScreenshotPrefix(title)
	local ok, success, path = pcall(SaveScreenshot, player, false, false, prefix)
	if not ok then
		Trace("VOLT26 screenshot error: "..tostring(success))
		return false, tostring(success)
	end
	Trace(("VOLT26 screenshot %s: %s"):format(success and "saved" or "failed", tostring(path)))
	return success == true, path
end

function VOLT26.EvaluationInput.SetScreenshotTexture(texture)
	VOLT26.Core.GetGlobalState().ScreenshotTexture = texture
end

function VOLT26.EvaluationInput.GetScreenshotTexture()
	return VOLT26.Core.GetGlobalState().ScreenshotTexture
end

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

VOLT26.Downloads.States = {
	queued=true, downloading=true, verifying=true, extracting=true,
	completed=true, failed=true, cancelled=true,
}

function VOLT26.Downloads.IsTransportEnabled()
	return false
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

-- Annual ITL persistence remains disabled until a versioned provider and active dates are defined.
function VOLT26.Tournament.IsLocalItlEnabled()
	return false
end

VOLT26.CustomSongs = {}

function VOLT26.CustomSongs.IsSupported()
	return PREFSMAN:PreferenceExists("CustomSongsEnable")
end

VOLT26.Options = {}

function VOLT26.Options.GetPlayerModifiers(player)
	return VOLT26.Core.GetPlayerState(player).ActiveModifiers
end

function VOLT26.Options.GetGlobalModifiers()
	return VOLT26.State.Global.ActiveModifiers
end

function VOLT26.Options.CanReturnToMusic()
	return VOLT26.State.Global.MenuTimer.ScreenSelectMusic > 1
		and VOLT26.State.Global.MusicWheelLocked ~= true
end

function VOLT26.Options.GetMenuTimer()
	return VOLT26.State.Global.MenuTimer.ScreenPlayerOptions
end

function VOLT26.Options.GetNextScreen(page)
	return VOLT26.State.Global.ScreenAfter["PlayerOptions"..(page == 1 and "" or tostring(page))]
end

function VOLT26.Options.GetReturnChoices(page)
	local choices = {
		[1] = {"Gameplay", "Select Music", "Options2", "Options3"},
		[2] = {"Gameplay", "Select Music", "Options1", "Options3"},
		[3] = {"Gameplay", "Select Music", "Options1", "Options2"},
	}
	local result = DeepCopy(choices[page])
	if not VOLT26.Options.CanReturnToMusic() then table.remove(result, 2) end
	return result
end

function VOLT26.Options.SaveReturnChoice(page, selections)
	local destinations = {
		[1] = {Branch.GameplayScreen(), VOLT26.Navigation.SelectMusicOrCourse(), "ScreenPlayerOptions2", "ScreenPlayerOptions3"},
		[2] = {Branch.GameplayScreen(), VOLT26.Navigation.SelectMusicOrCourse(), "ScreenPlayerOptions", "ScreenPlayerOptions3"},
		[3] = {Branch.GameplayScreen(), VOLT26.Navigation.SelectMusicOrCourse(), "ScreenPlayerOptions", "ScreenPlayerOptions2"},
	}
	if not VOLT26.Options.CanReturnToMusic() then table.remove(destinations[page], 2) end
	for index, selected in ipairs(selections) do
		if selected then
			local key = "PlayerOptions"..(page == 1 and "" or tostring(page))
			VOLT26.State.Global.ScreenAfter[key] = destinations[page][index]
			return
		end
	end
end

function VOLT26.Options.GetOperatorRow(screenName)
	if type(screenName) ~= "string" then return 0 end
	local rows = VOLT26.State.Global.PrevScreenOptionsServiceRow
	return math.max(0, math.floor(tonumber(rows[screenName]) or 0))
end

function VOLT26.Options.RememberOperatorRow(screenName, rowIndex, rowCount)
	if type(screenName) ~= "string" then return 0 end
	local index = math.max(0, math.floor(tonumber(rowIndex) or 0))
	local count = math.max(0, math.floor(tonumber(rowCount) or 0))
	if count > 0 and index >= count - 1 then index = 0 end
	VOLT26.State.Global.PrevScreenOptionsServiceRow[screenName] = index
	return index
end

local OperatorMenuLines = {
	"SystemOptions", "MapControllers", "TestInput", "InputOptions",
	"GraphicsSoundOptions", "VisualOptions", "ArcadeOptions", "Bookkeeping",
	"AdvancedOptions", "MenuTimerOptions", "USBProfileOptions",
	"OptionsManageProfiles", "ThemeOptions", "GrooveStatsOptions", "TournamentModeOptions", "StepManiaCredits", "ClearCredits", "Reload",
}

local ThemeOptionLines = {
	"MusicWheelSpeed", "PreferredStyle", "AllowFailingOutOfSet", "NumberOfContinuesAllowed",
	"SelectProfile", "SelectColor", "SelectPlayMode", "SelectPlayMode2", "EvalSummary",
	"NameEntry", "GameOver", "HideStockNoteSksins", "DanceSolo", "WriteCustomScores",
	"KeyboardFeatures", "SampleMusicLoops", "SampleMusicStartsImmediately", "RescoreEarlyHits",
	"DefaultSort",
}

local MenuTimerLines = {
	"MenuTimer", "ScreenSelectMusicMenuTimer", "ScreenPlayerOptionsMenuTimer",
	"ScreenEvaluationMenuTimer", "ScreenEvaluationNonstopMenuTimer",
	"ScreenEvaluationSummaryMenuTimer", "ScreenNameEntryMenuTimer",
}

local function FilterOperatorLines(source, excluded)
	local result = {}
	for _, line in ipairs(source) do
		if not excluded[line] then result[#result + 1] = line end
	end
	return result
end

function VOLT26.Options.GetOperatorMenuLines(customSongsAvailable, coinMode)
	return FilterOperatorLines(OperatorMenuLines, {
		USBProfileOptions = not customSongsAvailable,
		ClearCredits = coinMode ~= "CoinMode_Pay",
	})
end

function VOLT26.Options.GetThemeOptionLines()
	return FilterOperatorLines(ThemeOptionLines, {})
end

function VOLT26.Options.GetMenuTimerLines()
	return FilterOperatorLines(MenuTimerLines, {})
end

function VOLT26.Options.GetOperatorMenuLineNames(customSongsAvailable, coinMode)
	return table.concat(VOLT26.Options.GetOperatorMenuLines(customSongsAvailable, coinMode), ",")
end

function VOLT26.Options.GetThemeOptionLineNames()
	return table.concat(VOLT26.Options.GetThemeOptionLines(), ",")
end

function VOLT26.Options.GetMenuTimerLineNames()
	return table.concat(VOLT26.Options.GetMenuTimerLines(), ",")
end

VOLT26.TitleMenu = {
	AFKTimeoutSeconds = 5 * 60,
}

function VOLT26.TitleMenu.GetAFKTimeoutSeconds()
	return VOLT26.TitleMenu.AFKTimeoutSeconds
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
