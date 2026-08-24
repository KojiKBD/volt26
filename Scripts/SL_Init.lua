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
	return tonumber(VOLT26.State.Global.ActiveModifiers.MusicRate) or 1
end

function VOLT26.MusicSelection.PrepareScreen()
	VOLT26.State.Global.GameplayReloadCheck = false
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
	CasualMode = false,
	Leaderboard = false,
	LoadNewSongs = false,
	OnlineLobbies = false,
	PracticeMode = false,
	TestInput = false,
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
			SM(message)
			SCREENMAN:GetTopScreen():SetNextScreenName(destination):StartTransitioningScreen("SM_GoToNextScreen")
		end
		return false
	end
end

function VOLT26.EvaluationInput.CreateScreenshotHandler(requestCapture)
	local held = {MenuLeft=false, MenuRight=false}
	local chordCaptured = false
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
		elseif event.GameButton == "Select" and event.type == "InputEventType_FirstPress" then
			requestCapture(event.PlayerNumber)
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
