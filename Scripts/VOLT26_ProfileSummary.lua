-- VOLT26 profile summaries.
--
-- ScreenSelectProfile lists local profiles that the engine has not loaded into
-- a player slot yet, so the per-player helpers in VOLT26.ScoreIndex do not
-- apply: they resolve a profile through PROFILEMAN's slots.  What a picker
-- needs is the opposite -- a read of one profile *directory* that is cheap
-- enough to run while a cursor moves over it.
--
-- The numbers therefore come from two places with different costs.  The counts
-- the engine already holds in memory (songs played) are free and are read by
-- the caller straight off the Profile object.  Everything that would otherwise
-- mean walking a score history -- best grade, top combo, when the profile last
-- played -- is derived here from the compact index VOLT26.ScoreIndex writes
-- into each profile, read at most once per directory per screen.
--
-- This module never rebuilds an index.  A rebuild reads every exported
-- snapshot in a profile, which is appropriate when a player has committed to a
-- profile and is waiting on Song Select, and is not appropriate while someone
-- is scrolling a list.  A profile with no usable index simply reports nothing,
-- and the screen shows a placeholder until the index exists.

VOLT26.ProfileSummary = {
	-- Returned in place of a value the index cannot supply.
	Unknown = "--",
}

-- Keyed by profile directory: a different profile is a different directory, and
-- a screen never outlives a profile being rewritten underneath it.
local cache = {}

local function indexPath(directory)
	if type(directory) ~= "string" or directory == "" then return nil end
	if not (VOLT26.ScoreExport and VOLT26.ScoreExport.DirectoryName) then return nil end
	if not (VOLT26.ScoreIndex and VOLT26.ScoreIndex.FileName) then return nil end
	return directory .. VOLT26.ScoreExport.DirectoryName .. VOLT26.ScoreIndex.FileName
end

local function readIndex(directory)
	local path = indexPath(directory)
	if not path or not FILEMAN:DoesFileExist(path) then return nil end

	local ok, contents = pcall(lua.ReadFile, path)
	if not ok or type(contents) ~= "string" or contents == "" then return nil end

	local decoded, data = pcall(JsonDecode, contents)
	if not decoded or type(data) ~= "table" or type(data.Entries) ~= "table" then return nil end
	return data
end

-- Grade enums sort best-first in the engine's own enum order, so the ordinal is
-- the comparison.  Grade_Failed and Grade_NoData are ranked last by the enum
-- already, but neither is worth presenting as a "best", so both are skipped.
local function gradeRank(grade)
	if type(grade) ~= "string" then return nil end
	if grade == "Grade_Failed" or grade == "Grade_NoData" then return nil end
	local rank = Grade:Reverse()[grade]
	return rank
end

local function normalizeGrade(grade)
	if type(grade) ~= "string" or grade == "" then return nil end
	if grade:match("^Grade_") then return grade end
	return "Grade_" .. grade
end

-- Snapshot timestamps are written by the engine as "YYYY-MM-DD HH:MM:SS", which
-- compares correctly as a string, so the newest one needs no date parsing.
local function newer(a, b)
	if type(b) ~= "string" or b == "" then return a end
	if type(a) ~= "string" or a == "" then return b end
	return b > a and b or a
end

local function summarize(directory)
	local summary = { Available = false }

	local index = readIndex(directory)
	if not index then return summary end

	local bestRank, bestGrade, combo, played, charts = nil, nil, nil, nil, 0

	for _, entry in pairs(index.Entries) do
		if type(entry) == "table" then
			charts = charts + 1

			local grade = normalizeGrade(entry.Grade)
			local rank = gradeRank(grade)
			if rank and (bestRank == nil or rank < bestRank) then
				bestRank, bestGrade = rank, grade
			end

			local entryCombo = tonumber(entry.MaxCombo)
			if entryCombo and (combo == nil or entryCombo > combo) then combo = entryCombo end

			played = newer(played, entry.DateTime)
			played = newer(played, entry.ExDateTime)
		end
	end

	summary.Available = charts > 0
	summary.Charts = charts
	summary.BestGrade = bestGrade
	summary.MaxCombo = combo
	summary.LastPlayed = played
	return summary
end

-- Everything the picker's detail panel shows for one profile directory.
-- Any field may be nil; the screen is responsible for its own placeholders.
function VOLT26.ProfileSummary.Read(directory)
	if type(directory) ~= "string" or directory == "" then return { Available = false } end

	local cached = cache[directory]
	if cached then return cached end

	local ok, summary = pcall(summarize, directory)
	if not ok or type(summary) ~= "table" then summary = { Available = false } end

	cache[directory] = summary
	return summary
end

function VOLT26.ProfileSummary.Invalidate(directory)
	if type(directory) == "string" then cache[directory] = nil end
end

function VOLT26.ProfileSummary.InvalidateAll()
	cache = {}
end

-- ----------------------------------------------------------------------------
-- Presentation helpers.  These return display strings, never nil, so a screen
-- can bind them straight to a BitmapText.

function VOLT26.ProfileSummary.GradeText(grade)
	if type(grade) ~= "string" then return VOLT26.ProfileSummary.Unknown end
	local tier = grade:gsub("^Grade_", "")
	if THEME:HasString("Grade", tier) then return THEME:GetString("Grade", tier) end
	return VOLT26.ProfileSummary.Unknown
end

function VOLT26.ProfileSummary.ComboText(combo)
	local value = tonumber(combo)
	if not value or value <= 0 then return VOLT26.ProfileSummary.Unknown end
	return tostring(math.floor(value))
end

-- "2026-09-09 18:14:02" -> "2 DAYS AGO".  Falls back to the calendar date when
-- the timestamp is further back than a relative phrase is useful for, and to
-- the raw date when it cannot be parsed at all.
function VOLT26.ProfileSummary.LastPlayedText(datetime)
	if type(datetime) ~= "string" or datetime == "" then return VOLT26.ProfileSummary.Unknown end

	local year, month, day = datetime:match("^(%d%d%d%d)-(%d%d)-(%d%d)")
	if not year then return datetime end

	local ok, days = pcall(function()
		local then_ = os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 12 })
		local now = os.time({ year = Year(), month = MonthOfYear(), day = DayOfMonth(), hour = 12 })
		return math.floor((now - then_) / 86400 + 0.5)
	end)

	if not ok or type(days) ~= "number" then return ("%s-%s-%s"):format(year, month, day) end

	if days <= 0 then return THEME:GetString("VOLT26ProfileSummary", "Today") end
	if days == 1 then return THEME:GetString("VOLT26ProfileSummary", "Yesterday") end
	if days < 30 then return THEME:GetString("VOLT26ProfileSummary", "DaysAgo"):format(days) end
	return ("%s-%s-%s"):format(year, month, day)
end
