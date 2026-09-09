-- Reading note data straight out of a simfile.
--
-- The engine exposes a chart's counts and its timing, but not the individual
-- notes, so anything that has to draw the steps themselves reads the .sm/.ssc
-- and picks out the block belonging to the chart in hand.

VOLT26.Simfile = {}

local fileCache = {}
local noteCache = setmetatable({}, {__mode = "k"})

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

local function elapsedAt(timing, beat)
	local ok, seconds = pcall(function() return timing:GetElapsedTimeFromBeat(beat) end)
	return ok and tonumber(seconds) or nil
end

-- Notes(steps, player, untilSeconds) -> notes, holds
--
--   notes: { {Column, Beat, Time, Quantization, Kind}, ... } ordered by beat,
--          where Kind is "tap", "lift", "mine" or "fake"
--   holds: { {Column, Beat, Time, EndBeat, EndTime, Kind}, ... } ordered by
--          beat, where Kind is "hold" or "roll"
--
-- Both beat and elapsed time are carried because a caller's spacing depends on
-- which speed mod is in play: X and M space by beat, C spaces by time.  Reading
-- stops once the chart passes `untilSeconds`, so a caller that previews a
-- window does not pay for the whole chart.
function VOLT26.Simfile.Notes(steps, player, untilSeconds)
	untilSeconds = untilSeconds or math.huge

	local cached = noteCache[steps]
	local entry = cached and cached[player]
	if entry and entry.until_ == untilSeconds then return entry.notes, entry.holds end

	local notes, holds, openHolds = {}, {}, {}
	local lastBeat, lastTime = 0, 0
	local raw = VOLT26.Simfile.NoteData(steps, player)
	local timing = steps and steps.GetTimingData and steps:GetTimingData() or nil
	if raw and timing then
		local measureIndex = 0
		for measure in (raw..","):gmatch("(.-),") do
			local rows = {}
			for line in measure:gmatch("[^\r\n]+") do
				local row = trim(line)
				if row ~= "" and row ~= ";" then rows[#rows+1] = row:gsub(";", "") end
			end
			local past = false
			for rowIndex, row in ipairs(rows) do
				local beat = measureIndex*4 + (rowIndex-1)*4/#rows
				local seconds = elapsedAt(timing, beat)
				if not seconds then break end
				if seconds > untilSeconds then
					past = true
					lastBeat, lastTime = beat, seconds
					break
				end
				local quant = quantization(rowIndex-1, #rows)
				for column = 1, #row do
					local value = row:sub(column, column):upper()
					if value == "1" or value == "M" or value == "L" or value == "F" then
						local kind = value == "M" and "mine"
							or value == "L" and "lift"
							or value == "F" and "fake"
							or "tap"
						notes[#notes+1] = {
							Column = column, Beat = beat, Time = seconds,
							Quantization = quant, Kind = kind,
						}
					elseif value == "2" or value == "4" then
						openHolds[column] = {
							Column = column, Beat = beat, Time = seconds,
							Quantization = quant, Kind = value == "4" and "roll" or "hold",
						}
					elseif value == "3" and openHolds[column] then
						local hold = openHolds[column]
						hold.EndBeat, hold.EndTime = beat, seconds
						holds[#holds+1] = hold
						openHolds[column] = nil
					end
				end
				lastBeat, lastTime = beat, seconds
			end
			measureIndex = measureIndex + 1
			if past then break end
		end

		-- A hold that starts inside the window but is released past its end
		-- would otherwise vanish, so anything still open is closed at the edge.
		for _, hold in pairs(openHolds) do
			hold.EndBeat, hold.EndTime = lastBeat, lastTime
			if hold.EndBeat > hold.Beat then holds[#holds+1] = hold end
		end
	end

	-- Notes are appended in row order already.  Holds close out of start order,
	-- so only that much smaller collection needs sorting.
	table.sort(holds, function(a, b) return a.Beat < b.Beat end)

	cached = cached or {}
	cached[player] = {notes = notes, holds = holds, until_ = untilSeconds}
	noteCache[steps] = cached
	return notes, holds
end
