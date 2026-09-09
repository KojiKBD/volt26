-- Reading note data straight out of a simfile.
--
-- The engine exposes a chart's counts and its timing, but not the individual
-- notes, so anything that has to draw the steps themselves reads the .sm/.ssc
-- and picks out the block belonging to the chart in hand.

VOLT26.Simfile = {}

local fileCache = {}
local rowCache = setmetatable({}, {__mode="k"})

local function readFile(path)
	if not path or path == "" then return nil end
	if fileCache[path] ~= nil then return fileCache[path] or nil end
	local file = RageFileUtil.CreateRageFile()
	local contents
	if file:Open(path, 1) then contents = file:Read() end
	file:destroy()
	fileCache[path] = contents or false
	return contents
end

-- Simfile tags are matched case-insensitively, which authors and editors both
-- rely on, so each literal becomes a character class before it is searched for.
local function mixedCase(value)
	local pattern = {}
	for character in value:gmatch(".") do
		pattern[#pattern+1] = "["..character:upper()..character:lower().."]"
	end
	return table.concat(pattern)
end

local function trim(value)
	return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizeDifficulty(value)
	value = trim(value):gsub("[^%a]", ""):lower()
	if value == "expert" or value == "oni" or value == "maniac" then return "challenge" end
	if value == "basic" then return "easy" end
	if value == "another" or value == "trick" then return "medium" end
	return value
end

-- NoteData(steps, player) -> the chart's raw measure text, or nil.
function VOLT26.Simfile.NoteData(steps, player)
	if not steps or not steps.GetFilename then return nil end
	local filename = steps:GetFilename()
	local contents = readFile(filename)
	if not contents then return nil end
	local extension = filename:match("%.([^%.]+)$")
	extension = extension and extension:lower() or ""
	local targetType = ToEnumShortString(steps:GetStepsType()):gsub("_", "-"):lower()
	local targetDifficulty = normalizeDifficulty(ToEnumShortString(steps:GetDifficulty()))
	local targetDescription = trim(steps:GetDescription())
	local noteData

	local NOTES = mixedCase("NOTES")
	if extension == "ssc" then
		local NOTEDATA = mixedCase("NOTEDATA")
		local STEPSTYPE = mixedCase("STEPSTYPE")
		local DIFFICULTY = mixedCase("DIFFICULTY")
		local DESCRIPTION = mixedCase("DESCRIPTION")
		for block in contents:gmatch("#"..NOTEDATA..".-#"..NOTES.."2?:[^;]*") do
			local stepsType = trim(block:match("#"..STEPSTYPE..":(.-);") or ""):lower()
			local difficulty = normalizeDifficulty(block:match("#"..DIFFICULTY..":(.-);") or "")
			local description = trim(block:match("#"..DESCRIPTION..":(.-);") or "")
			if stepsType == targetType and difficulty == targetDifficulty
				and (difficulty ~= "edit" or description == targetDescription) then
				noteData = block:match("#"..NOTES.."2?:%s*([^;]*)")
				break
			end
		end
	elseif extension == "sm" then
		for block in contents:gmatch("#"..NOTES.."2?[^;]*") do
			local parts = {}
			for part in (block..":"):gmatch("([^:]*):") do parts[#parts+1] = part end
			if #parts >= 7 then
				local stepsType = parts[2]:gsub("[^%w-]", ""):lower()
				local difficulty = normalizeDifficulty(parts[4])
				local description = trim(parts[3])
				if stepsType == targetType and difficulty == targetDifficulty
					and (difficulty ~= "edit" or description == targetDescription) then
					noteData = parts[7]
					break
				end
			end
		end
	end

	if not noteData then return nil end
	noteData = noteData:gsub("//[^\r\n]*", "")
	-- Routine charts hold both players' steps in one block, split by an
	-- ampersand.
	local split = noteData:find("&", 1, true)
	if split then
		noteData = player == PLAYER_2 and noteData:sub(split+1) or noteData:sub(1,split-1)
	end
	return noteData
end

-- The subdivision a row falls on, as its denominator: 4 for a quarter note, 8
-- for an eighth, and so on.  Anything the usual divisions do not explain is
-- reported as 0, which callers colour as "other".
local divisions = {4, 8, 12, 16, 24, 32, 48, 64}

local function quantization(rowIndex, rowCount)
	for _, division in ipairs(divisions) do
		if (rowIndex * division) % rowCount == 0 then return division end
	end
	return 0
end

-- Measures(steps, player, firstMeasure, lastMeasure)
--   -> { {Column, Position, Quantization, Kind}, ... }, measureCount
--
-- Notes are ordered by position and Position is counted in measures from the
-- start of the chart, so a caller only has to decide what a measure is worth in
-- pixels.  Only measures inside the requested range are turned into notes: a
-- caller that draws a window of a chart should not pay for the rest of it.  The
-- measure count covers the whole chart either way.
function VOLT26.Simfile.Measures(steps, player, firstMeasure, lastMeasure)
	firstMeasure = firstMeasure or 0
	lastMeasure = lastMeasure or math.huge

	local cached = rowCache[steps]
	local entry = cached and cached[player]
	if entry and entry.first == firstMeasure and entry.last == lastMeasure then
		return entry.notes, entry.measures
	end

	local notes, measureCount = {}, 0
	local raw = VOLT26.Simfile.NoteData(steps, player)
	if raw then
		for measure in (raw..","):gmatch("(.-),") do
			if measureCount >= firstMeasure and measureCount <= lastMeasure then
				local rows = {}
				for line in measure:gmatch("[^\r\n]+") do
					local row = trim(line)
					if row ~= "" and row ~= ";" then rows[#rows+1] = row:gsub(";", "") end
				end
				for rowIndex, row in ipairs(rows) do
					local position = measureCount + (rowIndex-1)/#rows
					for column = 1, #row do
						local value = row:sub(column, column):upper()
						local kind
						if value == "1" or value == "L" then kind = "tap"
						elseif value == "2" or value == "4" then kind = "hold"
						elseif value == "M" then kind = "mine" end
						if kind then
							notes[#notes+1] = {
								Column = column,
								Position = position,
								Quantization = quantization(rowIndex-1, #rows),
								Kind = kind,
							}
						end
					end
				end
			end
			measureCount = measureCount + 1
		end
	end

	cached = cached or {}
	cached[player] = {notes=notes, measures=measureCount, first=firstMeasure, last=lastMeasure}
	rowCache[steps] = cached
	return notes, measureCount
end
