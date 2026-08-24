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
			self.ScreenAfter = {
				PlayAgain = "ScreenEvaluationSummary",
				PlayerOptions  = Branch.GameplayScreen(),
				PlayerOptions2 = Branch.GameplayScreen(),
				PlayerOptions3 = Branch.GameplayScreen(),
			}
			self.ContinuesRemaining = ThemePrefs.Get("NumberOfContinuesAllowed") or 0
			self.GameMode = ThemePrefs.Get("DefaultGameMode") or "ITG"
			self.ScreenshotTexture = nil
			self.MenuTimer = {
				ScreenGrooveStatsLogin  = ThemePrefs.Get("ScreenGrooveStatsLoginMenuTimer"),
				ScreenSelectMusic       = ThemePrefs.Get("ScreenSelectMusicMenuTimer"),
				ScreenSelectMusicCasual = ThemePrefs.Get("ScreenSelectMusicCasualMenuTimer"),
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
			self.GrooveStatsPlayerOptionKeys = CreateGrooveStatsPlayerOptionKeys()

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

		-- Used to prevent redundant downloads for SRPG unlocks.
		-- Each entry is keyed on the URL of the download which maps to a table of
		-- PackNames the unlock has been unpacked to.
		-- To see if we have already downloaded an unlock, one can just key on
		-- SL.UnlocksCache[url][packName]
		-- LoadUnlocksCache() is defined in SL-Helpers-GrooveStats.lua so that must
		-- be loaded before this file.
		UnlocksCache = LoadUnlocksCache(),
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
	Downloads = {},

	-- Latest versions available for ITGmania and Simply Love.
	ITGmaniaLatestVersion = nil,
	SimplyLoveLatestVersion = nil,
}

VOLT26.Meta = {
	Name = "VOLT26",
	Version = "0.1.0-dev",
	UpstreamCompatibility = "Simply Love 5.9.0",
}

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

-- Keep VOLT26.Preferences reserved for the inherited game-mode scoring table
-- until all compatibility consumers have migrated away from SL.Preferences.
VOLT26.ThemePrefs = {
	Get = function(name) return ThemePrefs.Get(name) end,
	Set = function(name, value) ThemePrefs.Set(name, value) end,
	Save = function() ThemePrefs.Save() end,
}

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
	FinishFastSwitch = function()
		VOLT26.State.Global.FastProfileSwitchInProgress = false
	end,
}

VOLT26.MusicSelection = {}

function VOLT26.MusicSelection.GetMusicRate()
	return tonumber(VOLT26.State.Global.ActiveModifiers.MusicRate) or 1
end

function VOLT26.MusicSelection.PrepareScreen()
	VOLT26.State.Global.GameplayReloadCheck = false
	generateFavoritesForMusicWheel()
	GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred"):MusicRate(VOLT26.MusicSelection.GetMusicRate())
end

function VOLT26.MusicSelection.RefreshPlayer(player, rebuildFavorites)
	if not PROFILEMAN:IsPersistentProfile(player) then
		VOLT26.Profile.LoadGuest(player)
	end
	if rebuildFavorites then
		generateFavoritesForMusicWheel()
	end
	ApplyMods(player)
end

VOLT26.Gameplay = {}

function VOLT26.Gameplay.GetMode()
	return VOLT26.State.Global.GameMode
end

function VOLT26.Gameplay.IsCasual()
	return VOLT26.Gameplay.GetMode() == "Casual"
end

function VOLT26.Gameplay.GetCurrentStageIndex()
	return VOLT26.State.Global.Stages.PlayedThisGame + 1
end

function VOLT26.Gameplay.GetPlayerStageState(player)
	local state = VOLT26.Core.GetPlayerState(player)
	return state.Stages.Stats[VOLT26.Gameplay.GetCurrentStageIndex()]
end

function VOLT26.Gameplay.BeginPlayerStage(player)
	local state = VOLT26.Core.GetPlayerState(player)
	state.Stages.Stats[VOLT26.Gameplay.GetCurrentStageIndex()] = {}
	return VOLT26.Gameplay.GetPlayerStageState(player)
end

function VOLT26.Gameplay.StorePlayerOptions(player)
	VOLT26.Core.GetPlayerState(player).PlayerOptionsString =
		GAMESTATE:GetPlayerState(player):GetPlayerOptionsString("ModsLevel_Preferred")
end

function VOLT26.Gameplay.StoreDuration(player, seconds)
	local stage = VOLT26.Gameplay.GetPlayerStageState(player)
	if stage then stage.duration = seconds end
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
	local key

	if params.HoldNoteScore then
		key = ToEnumShortString(params.HoldNoteScore)
		if key == "MissedHold" then key = "LetGo" end
		if key ~= "Held" and key ~= "LetGo" then return nil end
	elseif params.TapNoteScore then
		key = ToEnumShortString(params.TapNoteScore)
		if VOLT26.Gameplay.GetMode() == "ITG" and key == "W1" and IsW0Judgment(params, player) then
			key = "W0"
			counts.W0_total = counts.W0_total + 1
		elseif VOLT26.Gameplay.GetMode() ~= "ITG" then
			local tier = string.match(key, "W(%d)")
			if tier then key = "W"..(tonumber(tier)-1) end
		end
		if counts[key] == nil then return nil end
	else
		return nil
	end

	if stats:GetFailed() then return nil end
	counts[key] = counts[key] + 1
	local ex_score, actual_points, actual_possible = CalculateExScore(player, counts)
	return {
		Player=player,
		ExCounts=counts,
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

function VOLT26.Telemetry.RecordOffset(player, params, require_step_on_hold_heads)
	if params.Player ~= player or params.HoldNoteScore or not params.TapNoteOffset then return end
	local telemetry = VOLT26.Telemetry.Ensure(player)
	if not telemetry then return end

	local score = params.TapNoteScore
	local offset = (score == "TapNoteScore_Miss" or score == "TapNoteScore_CheckpointMiss")
		and "Miss" or params.TapNoteOffset
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
	telemetry.offsets[#telemetry.offsets+1] = {
		position=position,
		offset=offset,
		is_autohit=is_autohit,
	}
	local stage = VOLT26.Telemetry.GetStage(player)
	stage.sequential_offsets[#stage.sequential_offsets+1] = { position, offset, is_autohit }
end

function VOLT26.Telemetry.RecordColumnJudgment(player, params)
	if params.Player ~= player or not params.Notes then return end
	if GAMESTATE:GetPlayerState(player):GetHealthState() == "HealthState_Dead" then return end
	local telemetry = VOLT26.Telemetry.Ensure(player)
	if not telemetry then return end
	local modifiers = VOLT26.Options.GetPlayerModifiers(player)

	for column, tapnote in pairs(params.Notes) do
		local note_type = ToEnumShortString(tapnote:GetTapNoteType())
		if note_type == "Tap" or note_type == "HoldHead" or note_type == "Lift" then
			local judgment = ToEnumShortString(params.TapNoteScore)
			if params.EarlyTapNoteScore then
				local early = ToEnumShortString(params.EarlyTapNoteScore)
				if early ~= "None" then
					if IsW0Judgment(params, player) then
						telemetry.column_judgments[column].Early.W0 = telemetry.column_judgments[column].Early.W0 + 1
					elseif judgment ~= "W4" and judgment ~= "W5" and judgment ~= "Miss" then
						telemetry.column_judgments[column].Early[judgment] = telemetry.column_judgments[column].Early[judgment] + 1
					end
					telemetry.column_judgments[column].Early[early] = telemetry.column_judgments[column].Early[early] + 1
				end
			end
			if modifiers.ShowFaPlusWindow and modifiers.ShowFaPlusPane and IsW0Judgment(params, player) then
				judgment = "W0"
			end
			telemetry.column_judgments[column][judgment] = telemetry.column_judgments[column][judgment] + 1
			if note_type ~= "Lift" and judgment == "Miss" and tapnote:GetTapNoteResult():GetHeld() then
				telemetry.column_judgments[column].MissBecauseHeld = telemetry.column_judgments[column].MissBecauseHeld + 1
			end
		end
	end
end

VOLT26.Scoring = {}

function VOLT26.Scoring.GetExCounts(player)
	local telemetry = VOLT26.Telemetry.GetSnapshot(player)
	return telemetry and telemetry.ex_counts or nil
end

function VOLT26.Scoring.CalculateExScore(player, ex_counts, use_actual_w0_weight)
	if VOLT26.Gameplay.IsCasual() then return 0 end
	local steps_or_trail = GAMESTATE:IsCourseMode()
		and GAMESTATE:GetCurrentTrail(player) or GAMESTATE:GetCurrentSteps(player)
	if not steps_or_trail then return 0 end

	local radar = steps_or_trail:GetRadarValues(player)
	local w0_weight = use_actual_w0_weight and 3.5 or VOLT26.ExWeights.W0
	local total_possible = radar:GetValue("RadarCategory_TapsAndHolds") * w0_weight
		+ (radar:GetValue("RadarCategory_Holds") + radar:GetValue("RadarCategory_Rolls")) * VOLT26.ExWeights.Held
	local total_points = 0
	local player_options = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
	if player_options:NoMines() then
		total_points = total_points
			+ radar:GetValue("RadarCategory_Mines") * VOLT26.ExWeights.HitMine
	end

	local counts = ex_counts or VOLT26.Scoring.GetExCounts(player)
	if not counts or total_possible <= 0 then return 0, total_points, total_possible end
	for key in ivalues(ex_count_keys) do
		if counts[key] then
			total_points = total_points + counts[key] * VOLT26.ExWeights[key]
		end
	end
	return math.max(0, math.floor(total_points / total_possible * 10000) / 100), total_points, total_possible
end

VOLT26.Failure = {}

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

	local failure = {
		total_seconds=total_seconds,
		death_second=death_second,
		graph_percentage=graph_denominator > 0 and death_second / graph_denominator or 0,
		graph_label=graph_label,
	}

	local current_measure = math.floor(player_state:GetSongPosition():GetSongBeatVisible() / 4)
	local streams = VOLT26.Core.GetPlayerState(player).Streams
	if streams and streams.NotesPerMeasure and (streams.NotesPerMeasure[current_measure+1] or 0) >= 16 then
		for _, stream in ipairs(streams.Measures or {}) do
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
	for player in ivalues(GAMESTATE:GetEnabledPlayers()) do
		if premature or guard.used_autoplay[player] then
			STATSMAN:GetCurStageStats():GetPlayerStageStats(player):FailPlayer()
		end
	end
end

VOLT26.Evaluation = {}

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
	VOLT26.State.Global.Stages.Stats[VOLT26.Gameplay.GetCurrentStageIndex()] = {
		song = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or GAMESTATE:GetCurrentSong(),
		MusicRate = VOLT26.MusicSelection.GetMusicRate(),
	}
end

function VOLT26.Evaluation.CompleteStage()
	VOLT26.State.Global.Stages.PlayedThisGame = VOLT26.State.Global.Stages.PlayedThisGame + 1
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

VOLT26.TitleMenu = {
	AFKTimeoutSeconds = 5 * 60,
}

function VOLT26.TitleMenu.GetAFKTimeoutSeconds()
	return VOLT26.TitleMenu.AFKTimeoutSeconds
end

VOLT26.Navigation = {
	SelectMusicOrCourse = function()
		return SelectMusicOrCourse()
	end,
}


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
InitializeSimplyLove = InitializeVOLT26

InitializeVOLT26()
