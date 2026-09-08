-- VOLT26 local best-score index.
--
-- The engine stores aggregate ITG judgment counts in its own HighScore records,
-- so the best ITG percentage and grade for a chart can always be read straight
-- from the player profile.  EX scoring is different: VOLT26 emulates the FA+
-- (W0) window from tap offsets during gameplay, and that split is never written
-- to an engine HighScore.  It only survives in the per-play JSON snapshots that
-- VOLT26.ScoreExport writes into the profile.
--
-- Reading every snapshot on every Song Select hover would be far too slow, so
-- this module keeps a compact per-profile index of the best values seen for
-- each chart.  The index is appended to when a snapshot is exported and rebuilt
-- from the existing snapshots the first time it is needed.

VOLT26.ScoreIndex = {
	Schema = "VOLT26.ScoreIndex",
	SchemaVersion = 1,
	FileName = "index.json",
	-- Safety valve for a profile that accumulated an unexpected number of
	-- snapshots: a rebuild must never stall Song Select indefinitely.
	MaxRebuildFiles = 4000,
}

-- Cached indexes keyed by profile directory.  A different profile in the same
-- slot resolves to a different directory, so the directory is a safe key.
local cache = {}

local function profileSlot(player)
	local index = PlayerNumber:Reverse()[player]
	return index ~= nil and ProfileSlot[index + 1] or nil
end

local function profileDirectory(player)
	if not player or not PROFILEMAN:IsPersistentProfile(player) then return nil end
	local slot = profileSlot(player)
	if not slot then return nil end
	local directory = PROFILEMAN:GetProfileDir(slot)
	if type(directory) ~= "string" or directory == "" then return nil end
	return directory
end

local function scoresDirectory(directory)
	return directory .. VOLT26.ScoreExport.DirectoryName
end

local function indexPath(directory)
	return scoresDirectory(directory) .. VOLT26.ScoreIndex.FileName
end

local function newIndex()
	return {
		Schema = VOLT26.ScoreIndex.Schema,
		SchemaVersion = VOLT26.ScoreIndex.SchemaVersion,
		Entries = {},
	}
end

-- Snapshots store short enum strings ("Tier04", "Failed"); actors expect the
-- full enum value.
local function normalizeGrade(grade)
	if type(grade) ~= "string" or grade == "" then return nil end
	if grade:match("^Grade_") then return grade end
	return "Grade_" .. grade
end

local function normalizeStepsType(value)
	if type(value) ~= "string" then return "unknown" end
	local normalized = value:lower():gsub("_", "-")
	return normalized
end

local function keyParts(kind, directory, stepsType, difficulty, description)
	if type(directory) ~= "string" or directory == "" then return nil end
	-- Only Edit charts need their description to stay distinguishable; every
	-- other difficulty is unique per steps type within a song.
	local edit = difficulty == "Edit" and (description or "") or ""
	return table.concat({kind, directory, stepsType or "unknown", difficulty or "unknown", edit}, "|")
end

-- Build the index key for the currently selected song/course and chart.
function VOLT26.ScoreIndex.BuildKey(songOrCourse, stepsOrTrail)
	if not (songOrCourse and stepsOrTrail) then return nil end

	local kind, directory
	if songOrCourse.GetSongDir then
		kind, directory = "Song", songOrCourse:GetSongDir()
	elseif songOrCourse.GetCourseDir then
		kind, directory = "Course", songOrCourse:GetCourseDir()
	else
		return nil
	end

	local ok, stepsType = pcall(function() return normalizeStepsType(ToEnumShortString(stepsOrTrail:GetStepsType())) end)
	if not ok then stepsType = "unknown" end

	local okDifficulty, difficulty = pcall(function() return ToEnumShortString(stepsOrTrail:GetDifficulty()) end)
	if not okDifficulty then difficulty = "unknown" end

	local description = ""
	if difficulty == "Edit" and stepsOrTrail.GetDescription then
		local okDescription, value = pcall(function() return stepsOrTrail:GetDescription() end)
		if okDescription and type(value) == "string" then description = value end
	end

	return keyParts(kind, directory, stepsType, difficulty, description)
end

-- Build the index key for a snapshot produced by VOLT26.ScoreExport.
function VOLT26.ScoreIndex.BuildKeyFromSnapshot(snapshot)
	local chart = type(snapshot) == "table" and snapshot.Chart or nil
	if type(chart) ~= "table" or type(chart.Chart) ~= "table" then return nil end

	local kind = chart.Kind == "Course" and "Course" or "Song"
	local directory
	if kind == "Course" then
		directory = type(chart.Course) == "table" and chart.Course.Path or nil
	else
		directory = type(chart.Song) == "table" and chart.Song.Dir or nil
	end

	return keyParts(kind, directory, normalizeStepsType(chart.Chart.StepsType),
		chart.Chart.Difficulty, chart.Chart.Description)
end

local function mergeEntry(entry, score)
	if type(score) ~= "table" then return entry end
	entry = entry or {}

	local percent = tonumber(score.PercentDP)
	if percent and (entry.PercentDP == nil or percent > entry.PercentDP) then
		entry.PercentDP = percent
		entry.Grade = score.Grade
		entry.DateTime = score.DateTime
	end

	local ex = tonumber(score.ExPercent)
	-- The best EX run is not necessarily the best ITG run, so it is tracked
	-- independently instead of being overwritten by the ITG comparison above.
	if ex and (entry.ExPercent == nil or ex > entry.ExPercent) then
		entry.ExPercent = ex
		entry.ExGrade = score.Grade
		entry.ExDateTime = score.DateTime
	end

	return entry
end

local function decodeIndex(contents)
	if type(contents) ~= "string" or contents == "" then return nil end
	local ok, data = pcall(JsonDecode, contents)
	if not ok or type(data) ~= "table" then return nil end
	if data.SchemaVersion ~= VOLT26.ScoreIndex.SchemaVersion then return nil end
	if type(data.Entries) ~= "table" then return nil end
	return data
end

local function readIndex(directory)
	local path = indexPath(directory)
	if not FILEMAN:DoesFileExist(path) then return nil end
	local ok, contents = pcall(lua.ReadFile, path)
	if not ok then return nil end
	return decodeIndex(contents)
end

local function writeIndex(directory, index)
	local path = indexPath(directory)
	local encodedOk, encoded = pcall(JsonEncode, index)
	if not encodedOk or type(encoded) ~= "string" then
		Warn("VOLT26 score index: could not encode '" .. path .. "'.")
		return false
	end

	local file = RageFileUtil.CreateRageFile()
	if not file:Open(path, 2) then
		local errorMessage = file:GetError()
		file:destroy()
		Warn("VOLT26 score index: could not open '" .. path .. "': " .. tostring(errorMessage))
		return false
	end
	file:Write(encoded)
	file:Flush()
	local errorMessage = file:GetError()
	file:Close()
	file:destroy()
	if errorMessage and errorMessage ~= "" then
		Warn("VOLT26 score index: could not write '" .. path .. "': " .. tostring(errorMessage))
		return false
	end
	return true
end

-- Rebuild the index by reading every exported snapshot in the profile.  This
-- runs at most once per profile, when no usable index file is present.
function VOLT26.ScoreIndex.Rebuild(player)
	local directory = profileDirectory(player)
	if not directory then return nil end

	local index = newIndex()
	local listed, files = pcall(function()
		return FILEMAN:GetDirListing(scoresDirectory(directory), false, false)
	end)
	if not listed or type(files) ~= "table" then
		index.RebuiltAt = "unavailable"
		return index
	end

	local read = 0
	for name in ivalues(files) do
		if read >= VOLT26.ScoreIndex.MaxRebuildFiles then break end
		if type(name) == "string" and name:match("%.json$") and name ~= VOLT26.ScoreIndex.FileName then
			read = read + 1
			local ok, contents = pcall(lua.ReadFile, scoresDirectory(directory) .. name)
			if ok and type(contents) == "string" and contents ~= "" then
				local decodedOk, snapshot = pcall(JsonDecode, contents)
				if decodedOk and type(snapshot) == "table" and snapshot.Schema == VOLT26.ScoreExport.Schema then
					local key = VOLT26.ScoreIndex.BuildKeyFromSnapshot(snapshot)
					if key then index.Entries[key] = mergeEntry(index.Entries[key], snapshot.Score) end
				end
			end
		end
	end

	index.RebuiltFrom = read
	writeIndex(directory, index)
	return index
end

-- Return the cached index for a player, rebuilding it once if necessary.
function VOLT26.ScoreIndex.Load(player)
	local directory = profileDirectory(player)
	if not directory then return nil end

	local cached = cache[directory]
	if cached then return cached end

	local index = readIndex(directory) or VOLT26.ScoreIndex.Rebuild(player) or newIndex()
	cache[directory] = index
	return index
end

function VOLT26.ScoreIndex.Invalidate(player)
	local directory = profileDirectory(player)
	if directory then cache[directory] = nil end
end

function VOLT26.ScoreIndex.InvalidateAll()
	cache = {}
end

-- Merge an exported snapshot into the player's index and persist it.
function VOLT26.ScoreIndex.RecordSnapshot(player, snapshot)
	local directory = profileDirectory(player)
	if not directory or type(snapshot) ~= "table" then return false end

	local key = VOLT26.ScoreIndex.BuildKeyFromSnapshot(snapshot)
	if not key then return false end

	local index = VOLT26.ScoreIndex.Load(player) or newIndex()
	index.Entries[key] = mergeEntry(index.Entries[key], snapshot.Score)
	cache[directory] = index
	return writeIndex(directory, index)
end

-- Best local result for a player on a chart.
--
-- Returns nil when the player has no persistent profile.  Otherwise returns a
-- table where any field may be missing:
-- {
--     PercentDP  -- best ITG percentage as a 0..1 fraction
--     Grade      -- full grade enum for the best ITG result
--     DateTime   -- when the best ITG result was set
--     ExPercent  -- best EX percentage as a 0..100 value
--     ExDateTime -- when the best EX result was set
-- }
function VOLT26.ScoreIndex.GetBest(player, songOrCourse, stepsOrTrail)
	if not (player and songOrCourse and stepsOrTrail) then return nil end
	if not PROFILEMAN:IsPersistentProfile(player) then return nil end

	local profile = PROFILEMAN:GetProfile(player)
	if not profile then return nil end

	local best = nil
	local ok, top = pcall(function()
		return profile:GetHighScoreList(songOrCourse, stepsOrTrail):GetHighScores()[1]
	end)
	if ok and top then
		best = {
			PercentDP = top:GetPercentDP(),
			Grade = top:GetGrade(),
			DateTime = top:GetDate(),
		}
	end

	local index = VOLT26.ScoreIndex.Load(player)
	local key = index and VOLT26.ScoreIndex.BuildKey(songOrCourse, stepsOrTrail) or nil
	local entry = key and index.Entries[key] or nil
	if entry then
		best = best or {}
		best.ExPercent = tonumber(entry.ExPercent)
		best.ExDateTime = entry.ExDateTime
		-- Engine high scores can be missing while a VOLT26 snapshot exists, for
		-- example after the profile's score list was trimmed.
		if best.PercentDP == nil and tonumber(entry.PercentDP) then
			best.PercentDP = tonumber(entry.PercentDP)
			best.Grade = normalizeGrade(entry.Grade)
			best.DateTime = entry.DateTime
		end
	end

	return best
end
