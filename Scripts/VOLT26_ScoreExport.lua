VOLT26.ScoreExport = {
	Schema = "VOLT26.Score",
	SchemaVersion = 2,
	DirectoryName = "VOLT26-Scores/",
}

local radarCategories = {"Notes", "TapsAndHolds", "Jumps", "Holds", "Mines", "Hands", "Rolls"}
local tapJudgments = {"W1", "W2", "W3", "W4", "W5", "Miss", "HitMine", "AvoidMine", "CheckpointMiss", "CheckpointHit"}
local holdJudgments = {"LetGo", "Held", "MissedHold"}

local function nilIfEmpty(value)
	return value ~= "" and value or nil
end

local function readRadar(radar)
	if not radar then return nil end
	if radar:GetValue("RadarCategory_Notes") == -1 then return nil end
	local result = {}
	for _, category in ipairs(radarCategories) do
		result[category] = radar:GetValue("RadarCategory_"..category)
	end
	return result
end

local function readJudgments(highScore)
	local taps, holds = {}, {}
	for _, judgment in ipairs(tapJudgments) do
		taps[judgment] = highScore:GetTapNoteScore("TapNoteScore_"..judgment)
	end
	for _, judgment in ipairs(holdJudgments) do
		holds[judgment] = highScore:GetHoldNoteScore("HoldNoteScore_"..judgment)
	end
	return taps, holds
end

local function withNativeLanguage(callback)
	local original = PREFSMAN:GetPreference("ShowNativeLanguage")
	PREFSMAN:SetPreference("ShowNativeLanguage", true)
	local ok, value = pcall(callback)
	PREFSMAN:SetPreference("ShowNativeLanguage", original)
	if not ok then return nil, tostring(value) end
	return value
end

local function profileSlot(player)
	local index = PlayerNumber:Reverse()[player]
	return index ~= nil and ProfileSlot[index + 1] or nil
end

function VOLT26.ScoreExport.IsEligible(player)
	return PROFILEMAN:IsPersistentProfile(player)
		and GAMESTATE:IsSideJoined(player)
		and IsHumanPlayer(player)
end

function VOLT26.ScoreExport.BuildChart(player, possibleRadar)
	if GAMESTATE:IsCourseMode() then
		local course = GAMESTATE:GetCurrentCourse()
		local trail = GAMESTATE:GetCurrentTrail(player)
		if not course or not trail then return nil, "Missing current course or trail." end
		local fullTitle, titleError = withNativeLanguage(function() return course:GetDisplayFullTitle() end)
		if titleError then return nil, titleError end
		return {
			Kind = "Course",
			Course = {
				Path = nilIfEmpty(course:GetCourseDir()),
				FullTitle = fullTitle,
				TranslitFullTitle = course:GetTranslitFullTitle(),
				Scripter = nilIfEmpty(course:GetScripter()),
				Description = nilIfEmpty(course:GetDescription()),
			},
			Chart = {
				Difficulty = ToEnumShortString(trail:GetDifficulty()),
				Meter = trail:GetMeter(),
				StepsType = ToEnumShortString(trail:GetStepsType()):lower():gsub("_", "-"),
				LengthSeconds = trail:GetLengthSeconds(),
				Radar = readRadar(possibleRadar),
			},
		}
	end

	local song = GAMESTATE:GetCurrentSong()
	local steps = GAMESTATE:GetCurrentSteps(player)
	if not song or not steps then return nil, "Missing current song or steps." end
	local native, metadataError = withNativeLanguage(function()
		return {Artist=song:GetDisplayArtist(), SubTitle=song:GetDisplaySubTitle()}
	end)
	if metadataError then return nil, metadataError end
	return {
		Kind = "Song",
		Song = {
			Dir = song:GetSongDir(),
			Group = song:GetGroupName(),
			Title = song:GetMainTitle(),
			SubTitle = nilIfEmpty(native.SubTitle),
			Artist = nilIfEmpty(native.Artist),
			TranslitTitle = song:GetTranslitMainTitle(),
			TranslitSubTitle = nilIfEmpty(song:GetTranslitSubTitle()),
			TranslitArtist = nilIfEmpty(song:GetTranslitArtist()),
			Genre = nilIfEmpty(song:GetGenre()),
			DisplayBPM = {song:GetDisplayBpms()},
			RandomBPM = song:IsDisplayBpmRandom(),
			MusicLengthSeconds = song:MusicLengthSeconds(),
		},
		Chart = {
			Difficulty = ToEnumShortString(steps:GetDifficulty()),
			Meter = steps:GetMeter(),
			StepsType = ToEnumShortString(steps:GetStepsType()):lower():gsub("_", "-"),
			AuthorCredit = steps:GetAuthorCredit(),
			Description = steps:GetDescription(),
			Radar = readRadar(possibleRadar),
		},
	}
end

function VOLT26.ScoreExport.BuildSnapshot(player)
	local stats = VOLT26.Results.GetStageStats(player)
	if not stats then return nil, "Missing player stage statistics." end
	local highScore = stats:GetHighScore()
	if not highScore then return nil, "Missing current high score." end
	local taps, holds = readJudgments(highScore)
	local chart, chartError = VOLT26.ScoreExport.BuildChart(player, stats:GetRadarPossible())
	if not chart then return nil, chartError end
	local result = VOLT26.Results.GetCurrent(player)
	local profile = PROFILEMAN:GetProfile(player)
	local snapshot = {
		Schema = VOLT26.ScoreExport.Schema,
		SchemaVersion = VOLT26.ScoreExport.SchemaVersion,
		Theme = {
			Name = VOLT26.Meta.Name,
			Version = VOLT26.Meta.Version,
			UpstreamCompatibility = VOLT26.Meta.UpstreamCompatibility,
		},
		Engine = {
			ProductID = ProductID(),
			ProductVersion = ProductVersion(),
		},
		MachineGuid = PROFILEMAN:GetMachineProfile():GetGUID(),
		GameMode = VOLT26.Gameplay.GetMode(),
		Player = {
			Number = ToEnumShortString(player),
			Guid = profile and profile:GetGUID() or nil,
		},
		Score = {
			Guid = CRYPTMAN:GenerateRandomUUID(),
			Grade = ToEnumShortString(result.grade),
			EngineScore = highScore:GetScore(),
			PercentDP = highScore:GetPercentDP(),
			ExPercent = result.exPercent,
			SurviveSeconds = highScore:GetSurvivalSeconds(),
			MaxCombo = highScore:GetMaxCombo(),
			Modifiers = highScore:GetModifiers(),
			DateTime = highScore:GetDate(),
			Failed = result.failed,
			Disqualified = stats:IsDisqualified(),
			TapNoteScores = taps,
			HoldNoteScores = holds,
			ExJudgments = VOLT26.Scoring.GetExSnapshot(player),
			Radar = readRadar(stats:GetRadarActual()),
		},
		Chart = chart,
	}
	return snapshot
end

function VOLT26.ScoreExport.GetPath(player, snapshot)
	local slot = profileSlot(player)
	if not slot then return nil end
	local profileDir = PROFILEMAN:GetProfileDir(slot)
	local date = tostring(snapshot.Score.DateTime or "score"):gsub("[^%w%-_]", "")
	local guid = tostring(snapshot.Score.Guid or CRYPTMAN:GenerateRandomUUID()):gsub("[^%w%-_]", "")
	return profileDir .. VOLT26.ScoreExport.DirectoryName .. date .. "-" .. guid .. ".json"
end

function VOLT26.ScoreExport.Write(player, snapshot)
	local path = VOLT26.ScoreExport.GetPath(player, snapshot)
	if not path then return false, "Could not resolve the profile score directory." end
	local encodedOk, encoded = pcall(JsonEncode, snapshot, true)
	if not encodedOk or type(encoded) ~= "string" then
		return false, "Could not encode the score snapshot: " .. tostring(encoded)
	end

	local file = RageFileUtil.CreateRageFile()
	if not file:Open(path, 10) then
		local errorMessage = file:GetError()
		file:destroy()
		return false, "Could not open '" .. path .. "': " .. tostring(errorMessage)
	end
	local written = file:Write(encoded)
	file:Flush()
	local errorMessage = file:GetError()
	file:Close()
	file:destroy()
	if (type(written) == "number" and written < #encoded) or (errorMessage and errorMessage ~= "") then
		return false, "Could not complete '" .. path .. "': " .. tostring(errorMessage)
	end
	return true, path
end

function VOLT26.ScoreExport.WriteCurrent()
	local summary = {written={}, skipped={}, errors={}}
	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		local stage = VOLT26.Gameplay.GetPlayerStageState(player)
		if stage and stage.score_export_path then
			summary.skipped[#summary.skipped + 1] = ToEnumShortString(player)
		elseif not VOLT26.ScoreExport.IsEligible(player) then
			summary.skipped[#summary.skipped + 1] = ToEnumShortString(player)
		else
			local buildOk, snapshot, buildError = pcall(VOLT26.ScoreExport.BuildSnapshot, player)
			if not buildOk then
				summary.errors[#summary.errors + 1] = "Could not build the score snapshot: " .. tostring(snapshot)
			elseif not snapshot then
				summary.errors[#summary.errors + 1] = tostring(buildError)
			else
				local writeOk, written, pathOrError = pcall(VOLT26.ScoreExport.Write, player, snapshot)
				if not writeOk then
					summary.errors[#summary.errors + 1] = "Could not write the score snapshot: " .. tostring(written)
				elseif written then
					summary.written[#summary.written + 1] = pathOrError
					if stage then stage.score_export_path = pathOrError end
				else
					summary.errors[#summary.errors + 1] = pathOrError
				end
			end
		end
	end
	if #summary.errors > 0 then
		for _, errorMessage in ipairs(summary.errors) do Warn("VOLT26 score export: "..errorMessage) end
		SM(THEME:GetString("VOLT26ScoreExport", "WriteFailed"):format(#summary.errors))
	end
	return summary
end
